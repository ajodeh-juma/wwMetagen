process COVERM_CONTIG {
    tag "${meta.id}"
    label "process_medium"

    conda "bioconda::coverm"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/coverm:0.7.0--hcb7b614_4' :
        'biocontainers/coverm:0.7.0--hcb7b614_4' }"

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("*.depth.txt") , emit: coverage
    path "versions.yml"                  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args          = task.ext.args ?: ""
    def prefix        = task.ext.prefix ?: "${meta.id}"

    """
    TMPDIR=.

    coverm contig \\
        --bam-files ${bam} \\
        --threads ${task.cpus} \\
        $args \\
        --output-file ${prefix}.depth.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        coverm: \$(coverm --version | sed 's/coverm //')
    END_VERSIONS
    """

    stub:
    """
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        coverm: \$(coverm --version | sed 's/coverm //')
    END_VERSIONS
    """
}