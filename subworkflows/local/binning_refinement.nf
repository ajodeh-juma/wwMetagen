/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW: BINNING_REFINEMENT
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { METABAT2_SUMMARIZE_DEPTHS }     from '../../modules/local/process/metabat2_summarize_depths'
include { METABAT2_METABAT2         }     from '../../modules/local/process/metabat2'
include { MAXBIN2_PILEUP_COVERAGE   }     from '../../modules/local/process/maxbin2_pileup_coverage'
include { MAXBIN2                   }     from '../../modules/local/process/maxbin2'
include { CONCOCT_CONCOCT           }     from '../../modules/local/process/concoct_concoct'
include { CONCOCT_EXTRACTFASTABINS  }     from '../../modules/local/process/concoct_extractfastabins'
include { DASTOOL_FASTATOCONTIG2BIN }     from '../../modules/local/process/dastool_fastatocontig2bin'
include { DASTOOL_DASTOOL           }     from '../../modules/local/process/dastool'

workflow BINNING_REFINEMENT {
    take:
    ch_contigs      // channel: [ val(meta), path(fasta) ]
    ch_bam          // channel: [ val(meta), path(bam) ]
    ch_bai          // channel: [ val(meta), path(bai) ]
    ch_coverm_depth // channel: [ val(meta), path(coverage) ] from COVERM_CONTIGS
    ch_reads        // channel: [ val(meta), path(reads) ] 

    main:
    ch_versions = channel.empty()


    // MODULE: MetaBAT2 Summarise depths
    ch_metabat2_summarize_depths_input = ch_bam.join(ch_bai)
    METABAT2_SUMMARIZE_DEPTHS ( ch_metabat2_summarize_depths_input )

    //
    // MODULE: MetaBAT2
    // MetaBAT2 is excellent at high-resolution binning for distinct species.
    ch_metabat2_input = ch_contigs.join(METABAT2_SUMMARIZE_DEPTHS.out.depth)
    METABAT2_METABAT2 ( ch_metabat2_input )
    ch_versions = ch_versions.mix(METABAT2_METABAT2.out.versions)

    // MODULE: Pileup MaxBin2 abundance
    MAXBIN2_PILEUP_COVERAGE ( ch_bam )

    //
    // MODULE: MaxBin2
    // MaxBin2 uses marker genes and is robust for lower-coverage MAGs.
    // Note: MaxBin2 usually requires a simplified abundance list.
    //

    ch_maxbin2_input = ch_contigs.join(MAXBIN2_PILEUP_COVERAGE.out.abundance)
    MAXBIN2 ( ch_maxbin2_input )
    ch_versions = ch_versions.mix(MAXBIN2.out.versions)

    //
    // MODULE: CONCOCT
    // CONCOCT - linking contigs that co-vary in abundance.
    //
    ch_concoct_input = ch_contigs.join(ch_coverm_depth)
    ch_concoct_min_len = Channel.value(params.concoct_min_contig)
    CONCOCT_CONCOCT ( ch_concoct_input, ch_concoct_min_len )
    ch_versions = ch_versions.mix(CONCOCT_CONCOCT.out.versions)

    //
    // MODULE: CONCOCT_EXTRACTFASTABINS
    //
    ch_concoct_extractfastabins_input = ch_contigs.join(CONCOCT_CONCOCT.out.clustering_csv)
    CONCOCT_EXTRACTFASTABINS(ch_concoct_extractfastabins_input)


    //
    // MODULE: DASTOOL_FASTATOCONTIG2BIN
    // convert all binning outputs into a TSV format for DASTOOL
    //
    ch_metabat2_conversion = METABAT2_METABAT2.out.binned_fastas.map{ meta, bins -> [meta, bins, 'metabat2'] }
    ch_maxbin2_conversion = MAXBIN2.out.binned_fastas.map{ meta, bins -> [meta, bins, 'maxbin2'] }
    ch_concoct_conversion = CONCOCT_EXTRACTFASTABINS.out.fasta.map{ meta, bins -> [meta, bins, 'concoct'] }

    // mix all conversion channels
    ch_all_conversions = ch_metabat2_conversion.mix(ch_maxbin2_conversion, ch_concoct_conversion)

    // run the conversion process
    // split the tuple: [meta, bins] goes to first input, [binner_name] to second
    DASTOOL_FASTATOCONTIG2BIN (
        ch_all_conversions.map { meta, bins, binner -> [ meta, bins ] },
        ch_all_conversions.map { meta, bins, binner -> binner }
    )


    // aggregate the TSVs and Labels back together
    // DASTOOL_FASTATOCONTIG2BIN.out.tsv emits: [ meta, path(tsv), val(binner) ]
    // groupTuple() will collect them into: [ meta, [tsv1, tsv2, ...], [name1, name2, ...] ]
    ch_grouped_tsvs = DASTOOL_FASTATOCONTIG2BIN.out.tsv
        .groupTuple()

    //  with the original contigs to create the final DASTool input [ meta, path(contigs), [tsv_list], [name_list] ]
    ch_dastool_input = ch_contigs.join(ch_grouped_tsvs)

    //
    // MODULE: DAS Tool (Refinement)
    // takes bins from all three tools, compares them, and picks the highest-quality version of each genome.
    //
    DASTOOL_DASTOOL ( ch_dastool_input )
    ch_versions = ch_versions.mix(DASTOOL_DASTOOL.out.versions)

    emit:
    refined_bins = DASTOOL_DASTOOL.out.bins
    versions     = ch_versions
}