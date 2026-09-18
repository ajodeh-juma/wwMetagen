process METABAT2_SUMMARIZE_DEPTHS {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/metabat2:2.15--h4da6f23_2' :
        'biocontainers/metabat2:2.15--h4da6f23_2' }"

    input:
    tuple val(meta), path(bam), path(index)

    output:
    tuple val(meta), path("*.txt"), emit: depth

     when:
    task.ext.when == null || task.ext.when

    script:
    def args          = task.ext.args ?: ""
    def prefix        = task.ext.prefix ?: "${meta.id}"

    """
    export OMP_NUM_THREADS=$task.cpus

    jgi_summarize_bam_contig_depths \\
        --outputDepth ${prefix}.txt \\
        $args \\
        $bam
    """
}
