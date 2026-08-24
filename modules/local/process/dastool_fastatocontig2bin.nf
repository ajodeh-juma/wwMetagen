
process DASTOOL_FASTATOCONTIG2BIN {
    tag "$meta.id - $binner"
    label 'process_medium'

    conda "bioconda::das_tool=1.1.7"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/das_tool:1.1.7--r43hdfd78af_0'
        : 'biocontainers/das_tool:1.1.7--r43hdfd78af_0'}"

    input:
    tuple val(meta), path(bins)
    val(binner)

    output:
    tuple val(meta), path("*.tsv"), val(binner), emit: tsv
    path "versions.yml"                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def ext = bins instanceof List ? bins[0].name.replace('.gz', '').tokenize('.')[-1] : bins.name.replace('.gz', '').tokenize('.')[-1]

    """
    if ls *.gz 1> /dev/null 2>&1; then
        gunzip -f *.gz
    fi

    Fasta_to_Contig2Bin.sh \\
        $args \\
        -i . \\
        -e $ext \\
        > ${prefix}_${binner}.tsv


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DAS_Tool: \$( DAS_Tool --version 2>&1 | grep "DAS Tool" | sed 's/DAS Tool //' )
    END_VERSIONS

    """

    stub:
    """
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        DAS_Tool: \$( DAS_Tool --version 2>&1 | grep "DAS Tool" | sed 's/DAS Tool //' )
    END_VERSIONS
    """
}