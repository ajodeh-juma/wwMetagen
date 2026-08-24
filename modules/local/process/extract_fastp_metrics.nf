// Extract metrics from fastp json file
process EXTRACT_FASTP_METRICS {
    tag "${meta.id}"
    label "process_low"

    conda 'conda-forge::pandas:2.2.1'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:2.2.1' :
        'biocontainers/pandas:2.2.1' }"


    input:
    tuple val(meta), path(json)

    output:
    path "*_summary.tsv", emit: tsv

    script:
    """
    fastp_to_tsv.py --input ${json} --prefix ${meta.id} --outdir ./
    """
}