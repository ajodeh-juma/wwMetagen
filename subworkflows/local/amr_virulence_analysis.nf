/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW: AMR_VIRULENCE_ANALYSIS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { ABRICATE_RUN_MULTIDB as ABRICATE_CONTIGS          } from '../../modules/local/process/abricate_multi'
include { ABRICATE_RUN_MULTIDB as ABRICATE_BINS             } from '../../modules/local/process/abricate_multi'
include { ABRICATE_SUMMARY                                  } from '../../modules/local/process/abricate_summary'
include { AMRFINDERPLUS_UPDATE                              } from '../../modules/local/process/amrfinderplus_update'
include { AMRFINDERPLUS_RUN as AMRFINDERPLUS_CONTIGS        } from '../../modules/local/process/amrfinderplus_run'
include { AMRFINDERPLUS_RUN as AMRFINDERPLUS_BINS           } from '../../modules/local/process/amrfinderplus_run'


workflow AMR_VIRULENCE_ANALYSIS {
    take:
    ch_contigs       // [meta, path(contigs)]
    ch_bins          // [meta, path(bins_dir)]
    abricate_db_list 
    organisms_list

    main:
    ch_versions = Channel.empty()

    //
    // MODULE: ABRICATE_RUN_MULTIDB - run abricate
    //

    // contigs
    ABRICATE_CONTIGS (
        ch_contigs.map { meta, fasta -> [ meta + [type: 'contigs'], fasta ] },
        abricate_db_list
    )

    // refined Bins
    ABRICATE_BINS (
        ch_bins.map { meta, dir -> [ meta + [type: 'bins'], dir ] },
        abricate_db_list
    )

    ch_versions = ch_versions.mix(ABRICATE_BINS.out.versions)

    //
    // MODULE: AMRFINDERPLUS_UPDATE - run amrfinderplus
    //

    AMRFINDERPLUS_UPDATE ()

    // contigs
    AMRFINDERPLUS_CONTIGS ( 
        ch_contigs.map { meta, fasta -> [ meta + [type: 'contigs'], fasta ] },
        AMRFINDERPLUS_UPDATE.out.db, 
        organisms_list 
    )

    // bins
    AMRFINDERPLUS_BINS ( 
        ch_bins.map { meta, dir -> [ meta + [type: 'bins'], dir ] },
        AMRFINDERPLUS_UPDATE.out.db, 
        organisms_list 
    )

    ch_versions = ch_versions.mix(AMRFINDERPLUS_BINS.out.versions)


    emit:
    abricate_contigs_report     = ABRICATE_CONTIGS.out.report
    abricate_bins_report        = ABRICATE_BINS.out.report
    amrfinder_contigs_report    = AMRFINDERPLUS_CONTIGS.out.report
    amrfinder_bins_report       = AMRFINDERPLUS_BINS.out.report
    versions       = ch_versions
}