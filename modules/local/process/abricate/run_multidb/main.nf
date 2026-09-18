process ABRICATE_RUN_MULTIDB {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/abricate%3A1.2.0--h05cac1d_0'
        : 'biocontainers/abricate:1.2.0--h05cac1d_0'}"

    input:
    tuple val(meta), path(fasta)
    val db_list

    output:
    tuple val(meta), path("*.tsv"), emit: report
    path("versions.yml")          , emit: versions


    when:
    task.ext.when == null || task.ext.when

    script:
    def args       = task.ext.args   ?: ''
    def dbs        = db_list.join(' ')
    def type_label = meta.type ? "_${meta.type}" : ""
    // def prefix  = task.ext.prefix ?: "${meta.id}"
    def prefix     = task.ext.prefix ?: "${meta.id}${type_label}"

    """

    # Check if 'fasta' is a directory (bins) or a file (contigs)
    if [ -d "${fasta}" ]; then
        # It is a directory, point Abricate to all files inside
        INPUT_DATA="${fasta}/*"
    else
        # It is a single file
        INPUT_DATA="${fasta}"
    fi


    for db_name in ${dbs}; do
        abricate \\
            --db \$db_name \\
            --threads ${task.cpus} \\
            ${args} \\
            \$INPUT_DATA > \\
            ${prefix}_\${db_name}.tsv
    done

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
