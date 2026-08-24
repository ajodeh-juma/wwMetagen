process KRAKEN2_KRAKEN2 {
    tag "$meta.id"
    label 'process_high'
    

    conda "bioconda::kraken2=2.1.3 conda-forge::pigz=2.8"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-5799ab18b5fc681e75923b2450abaa969907ec98:941789bd7fe00db16531c26de8bf3c5c985242a5-0' :
        'biocontainers/mulled-v2-5799ab18b5fc681e75923b2450abaa969907ec98:941789bd7fe00db16531c26de8bf3c5c985242a5-0' }"

    input:
    tuple val(meta), path(reads)
    path  db

    output:
    tuple val(meta), path('*.classified.fastq.gz')  , emit: classified  , optional: true
    tuple val(meta), path('*.unclassified.fastq.gz'), emit: unclassified, optional: true
    tuple val(meta), path('*report.txt')            , emit: report
    path 'versions.yml'                             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args         = task.ext.args ?: ''
    def prefix       = task.ext.prefix ?: "${meta.id}"
    def paired       = meta.single_end ? "" : "--paired"
    def classified   = meta.single_end ? "${prefix}.classified.fastq"   : "${prefix}.classified#.fastq"
    def unclassified = meta.single_end ? "${prefix}.unclassified.fastq" : "${prefix}.unclassified#.fastq"

    """
    kraken2 \\
        --db $db \\
        --threads $task.cpus \\
        --unclassified-out $unclassified \\
        --classified-out $classified \\
        --report ${prefix}.kraken2.report.txt \\
        --output /dev/null \\
        --gzip-compressed \\
        $paired \\
        $args \\
        $reads
        
    pigz -p $task.cpus *.fastq

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kraken2: \$(kraken2 --version 2>&1) | sed 's/^.*Kraken version //; s/ .*\$//' | head -n 1
    END_VERSIONS

    """

    stub:
    """
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kraken2: \$(kraken2 --version 2>&1) | sed 's/^.*Kraken version //; s/ .*\$//' | head -n 1
    END_VERSIONS
    """
}