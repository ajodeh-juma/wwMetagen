process DASTOOL_DASTOOL {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::das_tool=1.1.7"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/das_tool:1.1.7--r43hdfd78af_0'
        : 'biocontainers/das_tool:1.1.7--r43hdfd78af_0'}"

    input:
    tuple val(meta), path(contigs), path(tsvs), val(binner_names)

    output:
    tuple val(meta), path("*.log")                   , emit: log
    tuple val(meta), path("*_summary.tsv")           , emit: summary
    tuple val(meta), path("*_DASTool_bins/*.fa")     , optional: true, emit: bins
    path "versions.yml"                              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def bins = tsvs instanceof List ? tsvs.join(",") : "$tsvs"
    def labels = binner_names.join(',')


    """
    DAS_Tool \\
        -i $bins \\
        -l $labels \\
        -c $contigs \\
        -o $prefix \\
        -t $task.cpus \\
        --write_bins \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DAS_Tool: \$( DAS_Tool --version 2>&1 | grep "DAS Tool" | sed 's/DAS Tool //' )
    END_VERSIONS
    """

    stub:
    """
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DAS_Tool: \$( DAS_Tool --version 2>&1 | grep "DAS Tool" | sed 's/DAS Tool //' )
    END_VERSIONS
    """
}