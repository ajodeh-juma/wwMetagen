process MEGAHIT {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"

     container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/megahit:1.2.9--h2e03b76_1' :
        'biocontainers/megahit:1.2.9--h2e03b76_1' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("megahit_out/*.contigs.fa")                                , emit: contigs
    tuple val(meta), path("megahit_out/intermediate_contigs/k*.contigs.fa.gz")       , emit: k_contigs
    tuple val(meta), path("megahit_out/intermediate_contigs/k*.addi.fa.gz")          , emit: addi_contigs
    tuple val(meta), path("megahit_out/intermediate_contigs/k*.local.fa.gz")         , emit: local_contigs
    tuple val(meta), path("megahit_out/intermediate_contigs/k*.final.contigs.fa.gz") , emit: kfinal_contigs
    path "versions.yml"                                                              , emit: versions


    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def input_reads    = params.single_end ? "-r $reads" : "-1 ${reads[0]} -2 ${reads[1]}"

    """
    megahit \\
        $input_reads \\
        -t $task.cpus \\
        $args \\
        --out-prefix $prefix

    gzip megahit_out/intermediate_contigs/*.fa

    # mv megahit_out/* .


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
      megahit: \$(megahit -v 2>&1) | sed 's/MEGAHIT v//'
    END_VERSIONS
    """

    stub:
    """
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
      megahit: \$(megahit -v 2>&1) | sed 's/MEGAHIT v//'
    END_VERSIONS
    """

}
