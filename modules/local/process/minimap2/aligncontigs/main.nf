process MINIMAP2_ALIGN {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/66/66dc96eff11ab80dfd5c044e9b3425f52d818847b9c074794cf0c02bfa781661/data' :
        'community.wave.seqera.io/library/minimap2_samtools:33bb43c18d22e29c' }"

    input:
    tuple val(meta), path(reads), path(contigs)

    output:
    tuple val(meta), path("*.bam")                , optional: true, emit: bam
    tuple val(meta), path("*.bai")                , optional:true,  emit: bai
    tuple val(meta), path("*.txt")                , optional:true,  emit: coverage
    path "versions.yml"                           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args  = task.ext.args ?: ''
    def args2 = task.ext.args2 ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"


    if (meta.single_end) {
        """
        minimap2 \\
            -ax sr \\
            ${args} \\
            -t ${task.cpus} \\
            $contigs \\
            ${reads[0]} \\
            | samtools view -@ $task.cpus -bhS ${args2} - | samtools sort -@ $task.cpus -o ${prefix}.bam

        samtools index ${prefix}.bam
        samtools coverage ${prefix}.bam -o ${prefix}.coverage.txt

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            minimap2: \$(minimap2 --version)
            samtools: \$(samtools --version | head -n 1 | grep -o '[0-9.]\\+')
        END_VERSIONS
        """
    } else {
        """
        minimap2 \\
            -ax sr \\
            ${args} \\
            -t ${task.cpus} \\
            $contigs \\
            ${reads[0]} ${reads[1]} \\
            | samtools view -@ $task.cpus -bhS ${args2} - | samtools sort -@ $task.cpus -o ${prefix}.bam

        samtools index ${prefix}.bam

        samtools coverage ${prefix}.bam -o ${prefix}.coverage.txt

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            minimap2: \$(minimap2 --version)
            samtools: \$(samtools --version | head -n 1 | grep -o '[0-9.]\\+')
        END_VERSIONS
        """
    }


    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch "${prefix}.bam"
    touch "${prefix}.bam.bai"
    touch "${prefix}.coverage.txt"
    """
}
