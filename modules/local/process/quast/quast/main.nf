
process QUAST {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/a5/a515d04307ea3e0178af75132105cd36c87d0116c6f9daecf81650b973e870fd/data' :
        'community.wave.seqera.io/library/quast:5.3.0--755a216045b6dbdd' }"

    input:
    tuple val(meta), path(assembly)

    output:
    tuple val(meta), path("${prefix}")                   , emit: results
    tuple val(meta), path("${prefix}.tsv")               , emit: tsv
    path "versions.yml"                                  , emit: versions


    when:
    task.ext.when == null || task.ext.when

    script:
    def args      = task.ext.args   ?: ''
    prefix        = task.ext.prefix ?: "${meta.id}"


    """
    metaquast.py \\
        --threads $task.cpus \\
        --rna-finding \\
        --max-ref-number 0 \\
        $args \\
        -l $prefix \\
        $assembly \\
        --output-dir $prefix

    ln -s ${prefix}/report.tsv ${prefix}.tsv

    cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            quast: \$(metaquast.py --version | sed "s/QUAST v//; s/ (MetaQUAST mode)//")
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"

    """
    mkdir -p $prefix
    touch $prefix/report.tsv
    touch $prefix/report.html
    touch $prefix/report.pdf
    touch $prefix/quast.log
    touch $prefix/transposed_report.txt
    touch $prefix/transposed_report.tex
    touch $prefix/icarus.html
    touch $prefix/report.tex
    touch $prefix/report.txt


    mkdir -p $prefix/basic_stats
    touch $prefix/basic_stats/cumulative_plot.pdf
    touch $prefix/basic_stats/Nx_plot.pdf
    touch $prefix/basic_stats/genome_GC_content_plot.pdf
    touch $prefix/basic_stats/GC_content_plot.pdf

    mkdir -p $prefix/icarus_viewers
    touch $prefix/icarus_viewers/contig_size_viewer.html

    ln -s $prefix/report.tsv ${prefix}.tsv


    cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            quast: \$(metaquast.py --version | sed "s/QUAST v//; s/ (MetaQUAST mode)//")
        END_VERSIONS
    """


}
