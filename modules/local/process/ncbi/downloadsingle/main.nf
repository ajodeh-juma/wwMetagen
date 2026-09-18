process NCBI_DOWNLOAD_SINGLE {
    tag "TaxID: ${taxid}"
    label "process_medium"

    conda "${moduleDir}/environment.yml"

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'oras://community.wave.seqera.io/library/ncbi-datasets-cli_unzip:942ac741917cec87' 
        : 'biocontainers/ncbi-datasets-cli:18.24.0'}"

    input:
    val taxid
    val n_genomes
    val max_attempts

    output:
    tuple val(taxid), path("${taxid}.fasta") , emit: genome
    tuple val(taxid), path("${taxid}.tsv")   , emit: metadata
    path 'versions.yml'                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    """
    # --------------------------------------------------------------------------
    # 1. Accession Resolution Logic
    # --------------------------------------------------------------------------

    # Check for specific TaxIDs requiring fixed reference accessions (e.g., Salmonella Typhi = 90370)
    if [ "${taxid}" == "90370" ]; then
        echo "[INFO] TaxID 90370 (Salmonella Typhi) detected. Forcing reference accession GCF_000195995.1 (CT18)..."
        echo "GCF_000195995.1" > accessions.txt

    else
        # Check Kingdom
        datasets summary taxonomy taxon ${taxid} --as-json-lines > report.jsonl

        if grep -qE '"name":"Bacteria"' report.jsonl; then
            TOGGLE="--reference"
        else
            TOGGLE=""
        fi
            
        # Attempt 1: Fetch with --reference flag
        datasets summary genome taxon ${taxid} \$TOGGLE --report sequence --as-json-lines > genome_summary.jsonl 2>/dev/null || true
        dataformat tsv genome-seq --inputfile genome_summary.jsonl --fields accession > all_accessions.tsv 2>/dev/null || true
        tail -n +2 all_accessions.tsv | uniq > tmp_all.tsv

        # Fallback: If --reference returned 0 accessions, retry without --reference
        if [ ! -s tmp_all.tsv ] && [ -n "\$TOGGLE" ]; then
            echo "[WARN] No reference assemblies found for TaxID ${taxid} with --reference. Retrying without --reference..."
            datasets summary genome taxon ${taxid} --report sequence --as-json-lines > genome_summary.jsonl
            dataformat tsv genome-seq --inputfile genome_summary.jsonl --fields accession > all_accessions.tsv
            tail -n +2 all_accessions.tsv | uniq > tmp_all.tsv
        fi

        head -n ${n_genomes} tmp_all.tsv > accessions.txt
    fi

    if [ ! -s accessions.txt ]; then
      echo "[ERROR] No accessions found for TaxID: ${taxid}"
      exit 1
    fi
    
    # --------------------------------------------------------------------------
    # 2. Download & Rehydration
    # --------------------------------------------------------------------------

    datasets download genome accession --inputfile accessions.txt \\
      --assembly-level complete \\
      --include genome \\
      --no-progressbar \\
      --dehydrated \\
      ${args} \\
      --filename download.zip

    unzip -o download.zip -d tmp_data/

    SUCCESS=false
    for attempt in \$(seq 1 ${max_attempts}); do
        if datasets rehydrate --directory tmp_data/ --max-workers ${task.cpus} --gzip; then
            SUCCESS=true; break
        fi
        echo "[WARN] Rehydration attempt \${attempt} failed. Retrying in 10s..."
        sleep 10
    done

    # --------------------------------------------------------------------------
    # 3. Output Preparation & Metadata Merging
    # --------------------------------------------------------------------------
    if [ "\$SUCCESS" = true ]; then

        datasets summary genome accession --inputfile accessions.txt --report sequence --as-json-lines | \\
        dataformat tsv genome-seq --fields accession,genbank-seq-acc,refseq-seq-acc,chr-name > sequence_metadata.tsv

        datasets summary genome accession --inputfile accessions.txt --report genome --as-json-lines | \\
        dataformat tsv genome --fields accession,organism-tax-id,organism-name,source_database > assembly_metadata.tsv

        sort -k1,1 assembly_metadata.tsv > assembly_sorted.tsv
        sort -k1,1 sequence_metadata.tsv > sequence_sorted.tsv
        join -t\$'\t' -1 1 -2 1 assembly_sorted.tsv sequence_sorted.tsv > ${taxid}.tsv

        find tmp_data/ncbi_dataset/data -name "*.fna.gz" -exec gunzip -c {} + > ${taxid}.fasta
    else
        echo "[ERROR] Failed to rehydrate genome dataset."
        exit 1
    fi

    rm -rf tmp_data/ download.zip 

    touch ${taxid}.fasta
    touch ${taxid}.tsv

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

    touch ${taxid}.fasta
    touch ${taxid}.tsv
    """
}
