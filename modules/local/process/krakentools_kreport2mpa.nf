
process KRAKENTOOLS_KREPORT2MPA {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::krakentools=1.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ? 
        'https://depot.galaxyproject.org/singularity/krakentools:1.2--pyh5e36f6f_0':
        'biocontainers/krakentools:1.2--pyh5e36f6f_0' }"

    input:
    tuple val(meta), path(report)

    output:
    tuple val(meta), path('*.mpa')  , emit: mpa
    path 'versions.yml'             , emit: versions
    

    script:
    def args       = task.ext.args ?: ''
    def prefix     = task.ext.prefix ?: "${meta.id}"
    def VERSION    = '1.2' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.

    """
    kreport2mpa.py \\
        -r $report \\
        -o ${prefix}.mpa \\
        --display-header \\
        --no-intermediate-ranks \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        KrakenTools: $VERSION
    END_VERSIONS

    """

    stub:
    def VERSION    = '1.2'

    """
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        KrakenTools: $VERSION
    END_VERSIONS
    """
}