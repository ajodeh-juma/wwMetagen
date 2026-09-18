// Set a default scale (1 million) if not provided by the user
params.normalization_scale = 1000000

process NORMALIZE_ABUNDANCES {
    tag "normalize_${type}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:2.2.1' :
        'biocontainers/pandas:2.2.1' }"
    

    input:
    path(merged_mpa)             // merged MPA file (raw counts)
    path(merged_domain_metrics)  // merged domain metrics (with classified_reads)
    val(type)                    // 'kraken2' or 'bracken'

    output:
    path("*_normalized_rpm.mpa.txt"), emit: normalized_mpa

    script:
    """
    compute_mpa_relative_abundance.py \\
        --mpa ${merged_mpa} \\
        --summary ${merged_domain_metrics} \\
        --scale ${params.normalization_scale} \\
        --output ${type}_normalized_rpm.mpa.txt
    """
}
