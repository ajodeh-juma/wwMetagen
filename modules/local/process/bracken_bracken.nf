process BRACKEN_BRACKEN {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::bracken=2.9"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ? 
        'https://depot.galaxyproject.org/singularity/bracken:2.9--py312h28adbb1_1':
        'biocontainers/bracken:2.9--py312h28adbb1_1' }"

    input:
    tuple val(meta), path(kraken_report)
    path db

    output:
    tuple val(meta), path("*.tsv")                 , emit: report
    tuple val(meta), path("*.txt")                 , emit: tax_level_report
    path 'versions.yml'                            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args         = task.ext.args ?: ''
    def prefix       = task.ext.prefix ?: "${meta.id}"

    """
    bracken \\
        $args \\
        -d $db \\
        -i $kraken_report \\
        -o ${prefix}.tsv


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bracken: \$(echo \$(bracken -v) | cut -f2 -d'v')
    END_VERSIONS

    """

    stub:
    """
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bracken: \$(echo \$(bracken -v) | cut -f2 -d'v')
    END_VERSIONS
    """
}