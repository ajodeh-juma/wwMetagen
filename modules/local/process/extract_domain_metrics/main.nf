// extract individual classification metrics for specific domains and read - total, classified and unclassified

process EXTRACT_DOMAIN_METRICS {
    tag "${meta.id}"
    label "process_low"

    conda "${moduleDir}/environment.yml"
    
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:2.2.1' :
        'biocontainers/pandas:2.2.1' }"

    input:
    tuple val(meta), path(report)

    output:
    tuple val(meta), path("*.tsv"), emit: tsv

    script:
    prefix = task.ext.prefix ?: "${meta.id}"

    """
    extract_domain_metrics.py \\
        --input ${report} \\
        --sample ${prefix} \\
        --outdir ./
    """
}
