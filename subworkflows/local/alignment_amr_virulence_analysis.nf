/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW: ALIGNMENT_AMR_VIRULENCE_ANALYSIS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { ABRICATE_RUN_MULTIDB as ABRICATE_CONSENSUS        } from '../../modules/local/process/abricate/run_multidb/main'
include { ABRICATE_SUMMARY                                  } from '../../modules/local/process/abricate/summary/main'
include { AMRFINDERPLUS_UPDATE                              } from '../../modules/local/process/amrfinderplus/update/main'
include { AMRFINDERPLUS_RUN as AMRFINDERPLUS_CONSENSUS      } from '../../modules/local/process/amrfinderplus/run/main'


workflow ALIGNMENT_AMR_VIRULENCE_ANALYSIS {
    take:
    ch_contigs       // [meta, path(contigs)]
    abricate_db_list 
    organisms_list

    main:
    ch_versions = Channel.empty()

    ch_contigs.view { meta, fasta ->
        "[CHANNEL VIEW] Sample: ${meta.id} | Organism: ${meta.organism} | File: ${fasta}"
    }
    

    //
    // MODULE: ABRICATE_RUN_MULTIDB - run abricate
    //

    // contigs
    ABRICATE_CONSENSUS (
        ch_contigs.map { meta, fasta -> [ meta + [type: 'consensus'], fasta ] },
        abricate_db_list
    )

    ch_versions = ch_versions.mix(ABRICATE_CONSENSUS.out.versions)

    //
    // MODULE: AMRFINDERPLUS_UPDATE - run amrfinderplus
    //

    AMRFINDERPLUS_UPDATE ()

    // contigs
    AMRFINDERPLUS_CONSENSUS ( 
        ch_contigs.map { meta, fasta -> [ meta + [type: 'consensus'], fasta ] },
        AMRFINDERPLUS_UPDATE.out.db, 
        organisms_list 
    )

    ch_versions = ch_versions.mix(AMRFINDERPLUS_CONSENSUS.out.versions)


    emit:
    abricate_contigs_report     = ABRICATE_CONSENSUS.out.report
    amrfinder_contigs_report    = AMRFINDERPLUS_CONSENSUS.out.report
    versions                    = ch_versions
}