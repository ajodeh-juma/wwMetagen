include { NCBI_DOWNLOAD_SINGLE as NCBI_DOWNLOAD_PATHOGEN     } from '../../modules/local/process/ncbi/downloadsingle/main'
include { MINIMAP2_INDEX as MINIMAP2_INDEX_TARGET       } from '../../modules/local/process/minimap2/index/main'
include { MINIMAP2_ALIGN as MINIMAP2_ALIGN_TARGET       } from '../../modules/local/process/minimap2/align/main'
include { SAMTOOLS_FAIDX   } from '../../modules/local/process/samtools/faidx/main'
include { LOFREQ_INDELQUAL } from '../../modules/nf-core/lofreq/indelqual'


workflow CALL_VARIANTS {
    take:
    ch_taxid
    ch_n_genomes             // number of genomes to download if a single taxid is provided otherwise 1 for a file containing pathogen taxids  
    ch_max_attempts          // maximum number of attempts for ncbi-datasets-cli for doenloading
    ch_reads                 // [meta, path(reads)]

    main:
    ch_versions = Channel.empty()

    //
    // MODULE: download pathogen reference genome
    //
    NCBI_DOWNLOAD_PATHOGEN(ch_taxid, ch_n_genomes, ch_max_attempts)

    ch_fasta_target = NCBI_DOWNLOAD_PATHOGEN.out.genome.map{ it[1] }.collect().view()

    //
    // MODULE: index the pathogen reference genome
    //

    MINIMAP2_INDEX_TARGET(ch_fasta_target)

    //
    // MODULE: align to target pathogen
    //

    MINIMAP2_ALIGN_TARGET(ch_reads, MINIMAP2_INDEX_TARGET.out.index.collect())
    
    //
    // MODULE: index the pathogen reference genome
    //
    SAMTOOLS_FAIDX(NCBI_DOWNLOAD_PATHOGEN.out.genome)

    //
    // MODULE: insert indel qualities in a BAM file
    //
    LOFREQ_INDELQUAL(
        MINIMAP2_ALIGN_TARGET.out.bam, 
        NCBI_DOWNLOAD_PATHOGEN.out.genome.collect(), 
        SAMTOOLS_FAIDX.out.fai
    )


    
    emit:
    bam      = LOFREQ_INDELQUAL.out.bam       // channel: [ val(meta), bam ]
    versions = ch_versions.mix(MINIMAP2_ALIGN_TARGET.out.versions, SAMTOOLS_FAIDX.out.versions)

}