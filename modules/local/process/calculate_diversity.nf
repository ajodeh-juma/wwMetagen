process CALCULATE_DIVERSITY {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::pysam conda-forge::pandas conda-forge::numpy"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/pysam_pandas_numpy:8c2ec89916fdc9f5' :
        'oras://community.wave.seqera.io/library/pysam_pandas_numpy:8c2ec89916fdc9f5' }"

    input:
    tuple val(meta), path(vcf)
    val diversity_window_size

    output:
    tuple val(meta), path("*_nucleotide_diversity.tsv"), emit: pi
    tuple val(meta), path("*_shannon_diversity.tsv"),    emit: shannon
    tuple val(meta), path("*_summary.txt"),              emit: summary

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    calculate_diversity.py \
        -v ${vcf} \
        -w ${diversity_window_size} \
        -p ${prefix} \
        -o .
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    touch ${prefix}_nucleotide_diversity.tsv
    touch ${prefix}_shannon_diversity.tsv
    touch ${prefix}_summary.txt
    """
}