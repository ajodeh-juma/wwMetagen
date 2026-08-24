process MAXBIN2 {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::maxbin2=2.2.7"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/maxbin2:2.2.7--hdbdd923_5' :
        'biocontainers/maxbin2:2.2.7--hdbdd923_5' }"

    input:
    tuple val(meta), path(contigs), path(abundance)

    output:
    tuple val(meta), path("*.fasta")      , emit: binned_fastas
    tuple val(meta), path("*.summary")    , emit: summary
    tuple val(meta), path("*.log")        , emit: log
    tuple val(meta), path("*.marker.gz")  , emit: marker_counts
    tuple val(meta), path("*.noclass.gz") , emit: unbinned_fasta
    tuple val(meta), path("*.tooshort.gz"), emit: tooshort_fasta
    tuple val(meta), path("*_bin.tar.gz") , emit: marker_bins , optional: true
    tuple val(meta), path("*_gene.tar.gz"), emit: marker_genes, optional: true
    path "versions.yml"                   , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    run_MaxBin.pl \\
        -contig $contigs \\
        -abund $abundance \\
        -thread $task.cpus \\
        $args \\
        -out $prefix


    gzip *.noclass *.tooshort *log *.marker

    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        maxbin2: \$( run_MaxBin.pl -v | head -n 1 | sed 's/MaxBin //' )
    END_VERSIONS
    """

    stub:

    """

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        maxbin2: \$( run_MaxBin.pl -v | head -n 1 | sed 's/MaxBin //' )
    END_VERSIONS
    """
}
