process BUILD_PATHOGEN_DB {
    tag "Building Database"
    label 'process_low'

    conda "conda-forge::entrez-direct"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/entrez-direct:24.0--he881be0_0' :
        'biocontainers/entrez-direct:24.0--he881be0_0' }"

    input:
    path pathogen_tsv

    output:
    path "*.fasta"           , emit: fasta
    path "versions.yml"      , emit: versions

    script:
    """
    # Initialize empty file
    touch pathogen_db.fasta

    # Skip header and read TSV
    tail -n +2 ${pathogen_tsv} | while IFS='	' read -r pathogen strain segment taxid len refseq acc ftp; do
        echo "Fetching \$pathogen (\$acc) via EDirect..."
        
        # Download using efetch
        # we pipe to sed to sanitize headers to >Pathogen_Strain
        efetch -db nuccore -id \$acc -format fasta >> pathogen_db.fasta
        # efetch -db nuccore -id \$acc -format fasta | sed "s/^>.*/>\${pathogen}_\${strain}/" >> pathogen_db.fasta
        
        # Respect NCBI rate limits (3 requests/sec without API key)
        sleep 0.5
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        entrez-direct: \$(esearch -version | cut -d ' ' -f 2)
        sed: \$(sed --version | head -n 1 | cut -d ' ' -f 4)
    END_VERSIONS
    """
}