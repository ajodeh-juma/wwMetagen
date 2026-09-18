process GET_PATHOGEN_REFERENCE {
    tag "$target_ref"
    label 'process_low'

    conda "${moduleDir}/environment.yml"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.9--h91753b0_8' :
        'biocontainers/samtools:1.9--h91753b0_8' }"

    input:
    val target_ref
    path pathogen_db

    output:
    path "${target_ref}.fasta"

    script:
    """
    # Create index if not present, then extract specific ID
    samtools faidx ${pathogen_db}
    samtools faidx ${pathogen_db} ${target_ref} > ${target_ref}.fasta
    """
}
