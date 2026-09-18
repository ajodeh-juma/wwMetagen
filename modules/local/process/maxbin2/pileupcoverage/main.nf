process MAXBIN2_PILEUP_COVERAGE {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
   
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bbmap:39.01--h92535d8_1' :
        'biocontainers/bbmap:39.01--h92535d8_1' }"

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("*.coverage.txt")    , emit: coverage
    tuple val(meta), path("*.abundance.txt")   , emit: abundance

    when:
    task.ext.when == null || task.ext.when
    
    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    pileup.sh \\
        $args \\
        in=${bam} \\
        out=${prefix}.coverage.txt

    tail -n+2 ${prefix}.coverage.txt | cut -f 1,5 > ${prefix}.abundance.txt
    """
}
