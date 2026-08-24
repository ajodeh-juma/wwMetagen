process KRAKENUNIQ {
    tag "${meta.id}"
    label 'process_high'

    conda "bioconda::krakenuniq=1.0.4"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/krakenuniq:1.0.4--pl5321h668145b_4':
        'biocontainers/krakenuniq:1.0.4--pl5321h668145b_4' }"

    input:
    tuple val(meta), path(reads)
    path  db

    output:
    tuple val(meta), path("${prefix}.krakenuniq.report.tsv") , emit: report
    tuple val(meta), path("${prefix}.krakenuniq.output.txt") , emit: raw_output, optional: true
    path "versions.yml"                                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args        = task.ext.args ?: ''
    prefix          = task.ext.prefix ?: "${meta.id}"
    def input_reads = meta.single_end ? "${reads}" : "${reads[0]} ${reads[1]}"
    def paired      = meta.single_end ? "" : "--paired"
    
    """
    krakenuniq \\
        --db ${db} \\
        --threads ${task.cpus} \\
        ${paired} \\
        ${args} \\
        --report-file ${prefix}.krakenuniq.report.tsv \\
        --output ${prefix}.krakenuniq.output.txt \\
        ${input_reads}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        krakenuniq: \$(krakenuniq --version | sed -n 's/.*version //p')
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.krakenuniq.report.tsv
    touch ${prefix}.krakenuniq.output.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        krakenuniq: 1.0.4
    END_VERSIONS
    """
}