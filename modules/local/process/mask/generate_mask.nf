process GENERATE_MASK {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${moduleDir}/generate_mask.sif"

    input:
    tuple val(meta), path(bam), path(bai)

    output:
    tuple val(meta), path("*.bed"), emit: bed

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    # 1. Calculate depth for every base
    # 2. Extract regions where depth is below threshold - params.min_depth
    # 3. Format as BED: chrom, start, end
    
    samtools depth -a ${bam} | \\
    awk -v d=${params.min_depth} '\$3 < d {print \$1 "\t" \$2-1 "\t" \$2}' | \\
    bedtools merge > ${prefix}_low_coverage.bed
    """
}