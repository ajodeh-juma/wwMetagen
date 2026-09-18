// // Download genomes using NCBI datasets CLI given a tab-delimited file with taxonomic IDs in the first column
process NCBI_DOWNLOAD_BATCH {
    tag "${taxon_input}"
    label "process_single"

    conda "${moduleDir}/environment.yml"

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'oras://community.wave.seqera.io/library/ncbi-datasets-cli_unzip:942ac741917cec87' 
        : 'biocontainers/ncbi-datasets-cli:18.24.0'}"

    input:
    path(taxon_input)       // Path to tab-delimited file (TaxIDs in column 1)
    val(max_attempts)       // Max rehydration retries

    output:
    path("*.fasta")         , emit: genome
    path("metadata.tsv")    , emit: metadata
    path 'versions.yml'     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args     = task.ext.args ?: ''

    """
    # Extract unique TaxIDs from column 1
    cut -f1 "${taxon_input}" | grep -oE '^[0-9]+\$' | sort -u > taxon_ids.txt

    > accessions.txt

    # Loop through each TaxID and resolve accession
    while read -r taxid; do
        
        # 1. Direct Override for Salmonella Typhi (TaxID: 90370)
        if [ "\${taxid}" == "90370" ]; then
            echo "[INFO] TaxID 90370 (Salmonella Typhi) detected. Forcing reference accession GCF_000195995.1 (CT18)..."
            echo "GCF_000195995.1" >> accessions.txt
            continue
        fi

        # 2. Kingdom Check (Bacteria vs Virus/Eukaryote)
        datasets summary taxonomy taxon \${taxid} --as-json-lines > report.jsonl 2>/dev/null || true

        if grep -qE '"name":"Bacteria"' report.jsonl; then
            TOGGLE="--reference"
        else
            TOGGLE=""
        fi
        
        # 3. Fetch primary accession using --reference flag if applicable
        ACC=\$(datasets summary genome taxon \${taxid} \${TOGGLE} --report sequence --as-json-lines 2>/dev/null | \\
               dataformat tsv genome-seq --fields accession 2>/dev/null | \\
               tail -n +2 | uniq | head -n 1)

        # 4. Fallback: If --reference returned no accession, retry without --reference
        if [ -z "\${ACC}" ] && [ -n "\${TOGGLE}" ]; then
            echo "[WARN] No reference assembly for TaxID \${taxid} with --reference. Retrying without..."
            ACC=\$(datasets summary genome taxon \${taxid} --report sequence --as-json-lines 2>/dev/null | \\
                   dataformat tsv genome-seq --fields accession 2>/dev/null | \\
                   tail -n +2 | uniq | head -n 1)
        fi

        if [ -n "\${ACC}" ]; then
            echo "\${ACC}" >> accessions.txt
        else
            echo "[WARN] Could not retrieve any valid accessions for TaxID: \${taxid}"
        fi

    done < taxon_ids.txt

    # Validate that at least one accession was resolved
    if [ ! -s accessions.txt ]; then
        echo "[ERROR] No accessions could be retrieved for any of the TaxIDs in ${taxon_input}."
        exit 1
    fi

    # Download Dataset Package
    datasets download genome accession --inputfile accessions.txt \\
      --assembly-level complete \\
      --include genome \\
      --no-progressbar \\
      --dehydrated \\
      ${args} \\
      --filename download.zip

    unzip -o download.zip -d tmp_data/

    # Rehydration Retry Loop
    SUCCESS=false
    for attempt in \$(seq 1 ${max_attempts}); do
        if datasets rehydrate --directory tmp_data/ --max-workers ${task.cpus} --gzip; then
            SUCCESS=true; break
        fi
        echo "[WARN] Rehydration attempt \${attempt} failed. Retrying in 10s..."
        sleep 10
    done

    # Generate Outputs and Metadata
    if [ "\$SUCCESS" = true ]; then

        datasets summary genome accession --inputfile accessions.txt --report sequence --as-json-lines | \\
        dataformat tsv genome-seq --fields accession,genbank-seq-acc,refseq-seq-acc,chr-name > sequence_metadata.tsv

        datasets summary genome accession --inputfile accessions.txt --report genome --as-json-lines | \\
        dataformat tsv genome --fields accession,organism-tax-id,organism-name,source_database > assembly_metadata.tsv

        sort -k1,1 assembly_metadata.tsv > assembly_sorted.tsv
        sort -k1,1 sequence_metadata.tsv > sequence_sorted.tsv
        join -t\$'\t' -1 1 -2 1 assembly_sorted.tsv sequence_sorted.tsv > metadata.tsv

        find tmp_data/ncbi_dataset/data -name "*.fna.gz" -exec gunzip -c {} + > reference.fasta
    else
        echo "[ERROR] Rehydration failed for batch download."
        exit 1
    fi

    # Cleanup
    rm -rf tmp_data/ download.zip taxon_ids.txt accessions.txt report.jsonl

    touch reference.fasta
    touch metadata.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ncbi-datasets-cli: \$(datasets --version | sed 's/datasets version: //')
    END_VERSIONS
    """

    stub:
    """
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ncbi-datasets-cli: \$(datasets --version | sed 's/datasets version: //')
    END_VERSIONS

    touch reference.fasta
    touch metadata.tsv
    """
}
