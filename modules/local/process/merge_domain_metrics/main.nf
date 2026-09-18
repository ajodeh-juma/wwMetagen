// merge all DOMAIN metrics

process MERGE_DOMAIN_METRICS {
    tag "${prefix}"
    label "process_low"

    conda "${moduleDir}/environment.yml"
    
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:2.2.1' :
        'biocontainers/pandas:2.2.1' }"

    input:
    path (metrics)
    val (prefix)

    output:
    path("*_domain_metrics.tsv") , emit: report

    script:
    """
    merge_domain_metrics.py \\
        --input ${metrics} \\
        --output ${prefix}_domain_metrics.tsv
    """
}
