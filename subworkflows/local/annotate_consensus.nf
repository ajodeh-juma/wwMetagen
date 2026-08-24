/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW: ANNOTATE_CONSENSUS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { PROKKA as PROKKA_ANNOTATE_CONSENSUS    }     from '../../modules/nf-core/prokka/main'
include { BAKTA_BAKTA                            }     from '../../modules/local/process/bakta/bakta/main'


workflow ANNOTATE_CONSENSUS {
    take:
    ch_consensus       // [meta, path(consensus)]
    ch_bakta_db
    ch_proteins
    ch_prodigal_tf
    ch_regions
    ch_hmms

    main:
    ch_versions = Channel.empty()

    //
    // MODULE: Annotate consensus genome
    //

    PROKKA_ANNOTATE_CONSENSUS(ch_consensus, ch_proteins, ch_prodigal_tf)

    

    //
    // MODULE: Annotate consensus genomes 
    //

    // BAKTA_BAKTA(
    //     ch_consensus, 
    //     ch_bakta_db,
    //     ch_proteins,
    //     ch_prodigal_tf,
    //     ch_regions,
    //     ch_hmms
    // )


    emit:
    
    versions       = ch_versions
}