process CONCOCT_CONCOCT {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/concoct:1.1.0--py39h8907335_8'
        : 'biocontainers/concoct:1.1.0--py39h8907335_8'}"

    input:
    tuple val(meta), path(contigs), path(coverage_file)
    val min_contig_len

    output:
    tuple val(meta), path("*_args.txt")                                         , emit: args_txt
    tuple val(meta), path("*.csv")                                              , emit: csv
    tuple val(meta), path("*_clustering_gt${min_contig_len}.csv")               , emit: clustering_csv
    tuple val(meta), path("*_log.txt")                                          , emit: log_txt
    tuple val(meta), path("*_original_data_gt${min_contig_len}.csv")            , emit: original_data_csv
    tuple val(meta), path("*_PCA_components_data_gt${min_contig_len}.csv")      , emit: pca_components_csv
    tuple val(meta), path("*_PCA_transformed_data_gt${min_contig_len}.csv")     , emit: pca_transformed_csv
    path "versions.yml"                                                         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    concoct \\
        ${args} \\
        --length_threshold ${min_contig_len} \\
        --threads ${task.cpus} \\
        --composition_file ${contigs} \\
        --coverage_file ${coverage_file} \\
        -b ${prefix}


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        concoct: \$('concoct --version | cut -d " " -f2')
    END_VERSIONS

    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        concoct: \$('concoct --version | cut -d " " -f2')
    END_VERSIONS

    
    touch ${prefix}_args.txt
    touch ${prefix}_clustering_gt${min_contig_len}.csv
    touch ${prefix}_log.txt
    touch ${prefix}_original_data_gt${min_contig_len}.csv
    touch ${prefix}_PCA_components_data_gt${min_contig_len}.csv
    touch ${prefix}_PCA_transformed_data_gt${min_contig_len}.csv

    """
}
