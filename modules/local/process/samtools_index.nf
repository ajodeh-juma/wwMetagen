process SAMTOOLS_INDEX {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::samtools=1.3.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.3.1--h9071d68_10' :
        'biocontainers/samtools:1.3.1--h9071d68_10' }"

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("*.bai")        , emit: bai
    path "versions.yml"                   , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:

    """
    samtools index $bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(samtools --version | head -n 1 | grep -o '[0-9.]\\+')
    END_VERSIONS

    """
    stub:
    """
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(samtools --version | head -n 1 | grep -o '[0-9.]\\+')
    END_VERSIONS
    """
}
