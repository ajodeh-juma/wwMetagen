process REHEADER_VCF {
    tag "${meta.id}"
    label 'process_low'
    
    conda "bioconda::bcftools=1.23.1 bioconda::htslib=1.23.1"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/0b/0b4d52ca9a56d07be3f78a12af654e5116f5112908dba277e6796fd9dfb83fe5/data'
        : 'community.wave.seqera.io/library/bcftools_htslib:1.23.1--9f08ec665533d64a'}"

    input:
    tuple val(meta), path(vcf)
    tuple val(meta2), path(fai)

    output:
    tuple val(meta), path("*.vcf.gz"),      emit: vcf
    tuple val(meta), path("*.vcf.gz.tbi"),  emit: tbi


    when:
    task.ext.when == null || task.ext.when


    script:
    def prefix = task.ext.prefix ?: "${meta.id}"


    """

    bcftools view -h ${vcf} | grep -v '^#CHROM' > ${prefix}_header.txt
    awk '{print "##contig=<ID=" \$1 ",length=" \$2 ">"}' ${fai} >> ${prefix}_header.txt
    bcftools view -h ${vcf} | grep '^#CHROM' >> ${prefix}_header.txt
    bcftools reheader -h ${prefix}_header.txt ${vcf} > ${prefix}_tmp.vcf


    bgzip -c ${prefix}_tmp.vcf > ${prefix}_variants.vcf.gz
    tabix -p vcf ${prefix}_variants.vcf.gz
    """
}