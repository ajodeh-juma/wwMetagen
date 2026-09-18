process METABAT2_METABAT2 {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
   
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/metabat2:2.15--h4da6f23_2' :
        'biocontainers/metabat2:2.15--h4da6f23_2' }"

    input:
    tuple val(meta), path(contigs), path(depth)

    output:
    tuple val(meta), path("*.tooShort.fa")                    , optional:true, emit: tooshort
    tuple val(meta), path("*.lowDepth.fa")                    , optional:true, emit: lowdepth
    tuple val(meta), path("*.unbinned.fa")                    , optional:true, emit: unbinned
    tuple val(meta), path("*.tsv")                            , optional:true, emit: membership
    tuple val(meta), path("*[!lowDepth|tooShort|unbinned].fa"), optional:true, emit: binned_fastas
    path  'versions.yml'                                      , emit: versions



    when:
    task.ext.when == null || task.ext.when

    script:
    def args          = task.ext.args ?: ""
    def prefix        = task.ext.prefix ?: "${meta.id}"
    def metabat2_min_contig = params.metabat2_min_contig < 1500 ? "-m 1500" : "-m ${params.metabat2_min_contig}"
    
    """
    metabat2 \\
        $args \\
        -i $contigs \\
        -a $depth \\
        -t $task.cpus \\
        --saveCls \\
        -o ${prefix}


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        metabat2: \$( metabat2 --help 2>&1 | head -n 2 | tail -n 1| sed 's/.*\\:\\([0-9]*\\.[0-9]*\\).*/\\1/' )
    END_VERSIONS

    """
    stub:

    """
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        metabat2: \$( metabat2 --help 2>&1 | head -n 2 | tail -n 1| sed 's/.*\\:\\([0-9]*\\.[0-9]*\\).*/\\1/' )
    END_VERSIONS
    """
}
