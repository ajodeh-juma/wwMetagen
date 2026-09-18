process PATHOGEN_METRICS {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:2.2.1' :
        'biocontainers/pandas:2.2.1' }"

    input:
    tuple val(meta), path(coverage_txt)
    path pathogen_tsv

    output:
    tuple val(meta), path("*.csv") , emit: metrics

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"


    """
    pathogen_metrics.py \\
        --input_file ${coverage_txt} \\
        --pathogen_tsv ${pathogen_tsv} \\
        --sample_id ${meta.id} \\
        --output ${prefix}_metrics.csv
    """
}
