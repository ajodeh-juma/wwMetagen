/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW: BINNING_ANALYSIS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { CHECKM2_DOWNLOADDATABASE     } from '../../modules/local/process/checkm2_downloaddatabase'
include { CHECKM2_PREDICT              } from '../../modules/local/process/checkm2_predict'
include { GTDBTK_DB_PREPARATION        } from '../../modules/local/process/gtdbtk_db_preparation'
include { GTDBTK_CLASSIFYWF            } from '../../modules/local/process/gtdbtk_classifywf'
include { GENOMAD_DOWNLOADDATABASE     } from '../../modules/local/process/genomad_downloaddatabase'
include { GENOMAD_ENDTOEND             } from '../../modules/local/process/genomad_endtoend'
include { CHECKV_DOWNLOADDATABASE      } from '../../modules/local/process/checkv_downloaddatabase'
include { CHECKV_ENDTOEND              } from '../../modules/local/process/checkv_endtoend'

workflow BINNING_ANALYSIS {
    take:
    ch_bins          // [meta, path(bins_dir)]
    ch_contigs       // [meta, path(contigs)]

    main:
    ch_versions = Channel.empty()

    //
    // MODULE: CHECKM2_DATABASEDOWNLOAD - download checkm2 database 
    //
    if (params.checkm2_db) {
        ch_checkm2_db = Channel.value(file(params.checkm2_db))
    } else {
        CHECKM2_DOWNLOADDATABASE( params.checkm2_db_zenodo_id )
        ch_checkm2_db = CHECKM2_DOWNLOADDATABASE.out.database
            .map { it -> it[1] }
            .collect()
    }

    //
    // MODULE: CHECKM2_PREDICT - predict MAGs
    //
    CHECKM2_PREDICT (
        ch_bins,
        ch_checkm2_db
    )
    ch_versions = ch_versions.mix(CHECKM2_PREDICT.out.versions)


    //
    // MODULE: GTDBTK_CLASSIFYWF - taxonomic classification - GTDB-Tk assigns lineage to bacterial MAGs


    ch_gtdbtk_db = params.gtdb_db

    if (ch_gtdbtk_db) {
        ch_gtdbtk_db = file( "${ch_gtdbtk_db}", checkIfExists: true)
        ch_gtdbtk_mash = params.gtdb_mash ? file("${params.gtdb_mash}", checkIfExists: true) : []
    } else {
        ch_gtdbtk_db = []
    }


     if ( ch_gtdbtk_db.extension == 'gz' ) {
        // Expects to be tar.gz!
        ch_gtdbtk_db = GTDBTK_DB_PREPARATION ( ch_gtdbtk_db ).db
    } else if ( ch_gtdbtk_db.isDirectory() ) {
        // Make up meta id to match expected channel cardinality for GTDBTK
        ch_gtdbtk_db = Channel
                            .of(ch_gtdbtk_db)
                            .map{
                                [ it.toString().split('/').last(), it ]
                            }
                            .collect()
    } else {
        error("Unsupported object given to --gtdb, database must be supplied as either a directory or a .tar.gz file!")
    }


    GTDBTK_CLASSIFYWF ( ch_bins, ch_gtdbtk_db, [])
    ch_versions = ch_versions.mix(GTDBTK_CLASSIFYWF.out.versions)


    //
    // MODULE: GENOMAD_DOWNLOAD - download genomad database and identify viruses, phages or proviruses
    //
    if (params.checkm2_db) {
        ch_genomad_db = Channel.value(file(params.genomad_db))
    } else {
        GENOMAD_DOWNLOADDATABASE()
        ch_genomad_db = GENOMAD_DOWNLOADDATABASE.out.genomad_db
    }

    //
    // MODULE: GENOMAD_ENDTOEND - confirms if bins are truly viral and predicts taxonomy
    //
    GENOMAD_ENDTOEND ( ch_contigs, ch_genomad_db )
    ch_versions = ch_versions.mix(GENOMAD_ENDTOEND.out.versions)

    // check viral Quality & Completeness - CheckV assesses the quality of the viral genomes

    //
    // MODULE: CHECKV_DOWNLOADDATABASE - download database for CheckV
    //

    if (params.checkv_db) {
        ch_checkv_db = Channel.value(file(params.checkv_db))
    } else {
        CHECKV_DOWNLOADDATABASE()
        ch_checkv_db = CHECKV_DOWNLOADDATABASE.out.checkv_db
    }



    CHECKV_ENDTOEND ( GENOMAD_ENDTOEND.out.virus_fasta, ch_checkv_db )
    ch_versions = ch_versions.mix(CHECKV_ENDTOEND.out.versions)

    emit:
    checkm2_report = CHECKM2_PREDICT.out.checkm2_tsv
    gtdb_summary   = GTDBTK_CLASSIFYWF.out.summary
    genomad_tax    = GENOMAD_ENDTOEND.out.taxonomy
    checkv_report  = CHECKV_ENDTOEND.out.quality_summary
    versions       = ch_versions
}