process COMPUTE_PATHOGEN_METRICS {
    tag "$meta.id"
    label 'process_low'

    conda 'conda-forge::pandas:2.2.1'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:2.2.1' :
        'biocontainers/pandas:2.2.1' }"

    input:
    tuple val(meta), path(coverage)
    path metadata

    output:
    tuple val(meta), path("*_metrics.csv") , emit: metrics

    when:
    task.ext.when == null || task.ext.when

    script:

    """
    compute_pathogen_metrics.py \\
        --metadata ${metadata} \\
        --coverage ${coverage} \\
        --sample_id ${meta.id} \\
        --outdir ./
    """
}