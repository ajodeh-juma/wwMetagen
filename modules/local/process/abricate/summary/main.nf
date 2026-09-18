process ABRICATE_SUMMARY {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/abricate%3A1.2.0--h05cac1d_0'
        : 'biocontainers/abricate:1.2.0--h05cac1d_0'}"

    input:
    tuple val(meta), path(reports)

    output:
    tuple val(meta), path("*.txt"), emit: report
    path("versions.yml")          , emit: versions


    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    abricate \\
        --summary \\
        ${reports} > ${prefix}_summary.txt

        
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        abricate: \$("abricate --version | sed 's/^.* //' ")
    END_VERSIONS
    """
    
    stub:
    """
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        abricate: \$("abricate --version | sed 's/^.* //' ")
    END_VERSIONS
    """
}
