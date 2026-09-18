// merge all MPA metrics

process MERGE_MPA_REPORTS {
    tag "${prefix}"
    label "process_low"

    conda "${moduleDir}/environment.yml"
    
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:2.2.1' :
        'biocontainers/pandas:2.2.1' }"

    input:
    path (mpa)
    val (prefix)

    output:
    path("*_merged_abundance.txt") , emit: report

    script:
    """
    merge_mpa_tables.py \\
        -i $mpa \\
        --prefix $prefix \\
        --outdir ./
    """
}
