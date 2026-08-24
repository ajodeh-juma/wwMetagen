
include { MINIMAP2_INDEX } from '../../modules/local/process/minimap2_index'
include { MINIMAP2_ALIGN } from '../../modules/local/process/minimap2_align_contigs'
include { SAMTOOLS_SORT  } from '../../modules/local/process/samtools_sort'
include { SAMTOOLS_INDEX } from '../../modules/local/process/samtools_index'
include { COVERM_CONTIG  } from '../../modules/local/process/coverm_contig'


workflow ALIGN_TO_CONTIGS {
    take:
    ch_reads_and_contigs // channel: [ val(meta), [reads], contigs.fasta ]

    main:
    ch_versions = Channel.empty()

    // //
    // // Indexing : extract just the meta and the contigs for indexing
    // // 
    // ch_index_input = ch_reads_and_contigs
    //     .map { meta, reads, contigs -> [ meta, contigs ] }
    

    // MINIMAP2_INDEX ( ch_index_input )
    
    //
    // Align reads to the newly created index: join the index back with the original reads using the 'meta' ID
    //


    ch_align_input = ch_reads_and_contigs
        .map { meta, reads, contigs  -> [meta, reads, contigs] }

    MINIMAP2_ALIGN ( ch_align_input )

    //
    // Sort and Index the BAM (Required for MetaBAT2/MaxBin2)
    //

    SAMTOOLS_SORT ( MINIMAP2_ALIGN.out.bam )
    SAMTOOLS_INDEX ( SAMTOOLS_SORT.out.bam )

    //
    // Compute coverage (CoverM): Join the sorted BAM with the original contigs
    //

    // ch_coverm_input = SAMTOOLS_SORT.out.bam
    //     .join(ch_reads_and_contigs.map { meta, reads, contigs -> [ meta, reads, contigs ] })
    //      // [ val(meta), bam, contigs ]
       

    COVERM_CONTIG ( SAMTOOLS_SORT.out.bam )

    
    emit:
    bam      = SAMTOOLS_SORT.out.bam       // channel: [ val(meta), bam ]
    bai      = SAMTOOLS_INDEX.out.bai      // channel: [ val(meta), bai ]
    coverage = COVERM_CONTIG.out.coverage  // channel: [ val(meta), txt ]
    versions = ch_versions.mix(MINIMAP2_ALIGN.out.versions, SAMTOOLS_SORT.out.versions, COVERM_CONTIG.out.versions)

}