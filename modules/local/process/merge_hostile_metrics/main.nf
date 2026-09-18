process MERGE_HOSTILE_METRICS {
    tag "merging_hostile_summaries"
    label 'process_low'

    conda "${moduleDir}/environment.yml"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:2.2.1' :
        'biocontainers/pandas:2.2.1' }"

    input:
    path(reports) // Collects all outputs from EXTRACT_HOSTILE_METRICS

    output:
    path("hostile_dehosting_summary.tsv"), emit: summary

    script:
    """
    merge_hostile_metrics.py \\
        --input ${reports} \\
        --output hostile_dehosting_summary.tsv
    """
}
