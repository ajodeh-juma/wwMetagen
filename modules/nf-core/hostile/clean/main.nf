process HOSTILE_CLEAN {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/hostile:2.0.2--pyhdfd78af_0' :
        'biocontainers/hostile:2.0.2--pyhdfd78af_0' }"

    input:
    tuple val(meta)          , path(reads, stageAs: "input_reads/")
    tuple val(reference_name), path(reference_dir)

    output:
    tuple val(meta), path('*.fastq.gz'), emit: fastq
    tuple val(meta), path('*.json')    , emit: json
    path 'versions.yml'                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args         = task.ext.args ?: ''
    def prefix       = task.ext.prefix ?: "${meta.id}"
    def reads_cmd    = meta.single_end ? "--fastq1 ${reads[0]}" : "--fastq1 ${reads[0]} --fastq2 ${reads[1]}"
    """
    export HOSTILE_CACHE_DIR=${reference_dir}

    hostile \\
        clean \\
        ${args} \\
        --threads ${task.cpus} \\
        ${reads_cmd} \\
        --index ${reference_name} \\
        --output . \\
        | tee > ${prefix}.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        hostile: \$(hostile --version)
    END_VERSIONS
    """
}