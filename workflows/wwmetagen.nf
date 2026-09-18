/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { HOSTILE_FETCH            } from '../modules/nf-core/hostile/fetch/main'
include { FASTQC                   } from '../modules/nf-core/fastqc/main'
include { FASTP                    } from '../modules/nf-core/fastp/main'
include { EXTRACT_FASTP_METRICS    } from '../modules/local/process/extract_fastp_metrics/main'
include { MERGE_FASTP_METRICS      } from '../modules/local/process/merge_fastp_metrics/main'
include { HOSTILE_CLEAN            } from '../modules/nf-core/hostile/clean/main'
include { EXTRACT_HOSTILE_METRICS  } from '../modules/local/process/extract_hostile_metrics/main'
include { MERGE_HOSTILE_METRICS    } from '../modules/local/process/merge_hostile_metrics/main'


include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_wwmetagen_pipeline'


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { BAKTA_AMRFINDER_UPDATE }     from '../modules/local/process/bakta/amrfinderupdate/main'
include { BAKTA_BAKTADBDOWNLOAD  }     from '../modules/local/process/bakta/baktadbdownload/main'

include { TARGETED_ALIGNMENT     }    from '../subworkflows/local/targeted_alignment'
include { GENERATE_CONSENSUS     }    from '../subworkflows/local/generate_consensus'
include { ASSEMBLY               }    from '../subworkflows/local/assembly' 
include { TAXONOMIC_PROFILING    }    from '../subworkflows/local/taxonomic_profiling'
// include { PREPARE_TARGET_GENOMES }    from '../subworkflows/local/prepare_target_genomes'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow WWMETAGEN {

    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:

    ch_versions = channel.empty()
    ch_multiqc_files = channel.empty()
    
    //
    // MODULE: Fetch Hostile index
    //

    if (params.hostile_db){
        ch_hostile_db = Channel.of(tuple('human-t2t-hla', file(params.hostile_db)))
    } else {
        HOSTILE_FETCH(params.hostile_index_name)
        ch_hostile_db = HOSTILE_FETCH.out.reference
    }
    
    //
    // MODULE: Run FastQC
    //
    
    if (!params.skip_qc) {
        
        FASTQC ( ch_samplesheet )
        ch_versions = ch_versions.mix(FASTQC.out.versions.first())
        ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]})
    }
    

    //
    // MODULE: Preprocessing (QC)
    //
    FASTP(ch_samplesheet, [], false, false)
    EXTRACT_FASTP_METRICS(FASTP.out.json)
    MERGE_FASTP_METRICS(EXTRACT_FASTP_METRICS.out.tsv.collect())


    //
    // MODULE: Dehosting using fetch Hostile 
    //
    HOSTILE_CLEAN(
        FASTP.out.reads,
        ch_hostile_db.collect()
    )

    //
    // MODULE: Extract hostile metrics and merge
    //
    EXTRACT_HOSTILE_METRICS(HOSTILE_CLEAN.out.json)
    ch_hostile_metrics = EXTRACT_HOSTILE_METRICS.out.tsv
    ch_hostile_metrics
        .filter { row -> file(row[1]) }
        .map { it[1] }
        .set { ch_hostile_metrics }
    MERGE_HOSTILE_METRICS(ch_hostile_metrics.collect())

    ch_hostile_clean_reads = HOSTILE_CLEAN.out.fastq

    
    if (params.analysis_type == 'assembly') {
        ASSEMBLY(ch_hostile_clean_reads)
    }

    else if (params.analysis_type == 'taxonomy') {

        // Kraken 2 database
        if (params.kraken2_db) {
            ch_kraken2_db = channel.fromPath(params.kraken2_db, type: 'dir')
        } else if (params.kraken2_db == null) {
            exit 1, "Missing options, database path: ${params.kraken2_db}"
        }

        TAXONOMIC_PROFILING(ch_hostile_clean_reads, ch_kraken2_db.collect() )
    }
    
    else if (params.analysis_type == 'alignment') {
        TARGETED_ALIGNMENT (
            params.target_pathogen_taxid,
            params.n_genomes,
            params.max_attempts,
            ch_hostile_clean_reads
        )

        ch_variants = TARGETED_ALIGNMENT.out.vcf.join(TARGETED_ALIGNMENT.out.tbi)
        

        def abricate_db_list  = params.abricate_dbs.tokenize(',')
        def ch_proteins       = params.proteins        ? file(params.proteins) : []
        def ch_tf             = params.prodigal_tf     ? file(params.prodigal_tf)     : []
        def ch_regions        = params.regions         ? file(params.regions)         : []
        def ch_hmms           = params.hmms            ? file(params.hmms)            : []


        def db_type = params.bakta_db_type
        if (params.bakta_db) {
            ch_bakta_db = Channel.value(file(params.bakta_db))

        } else {
            BAKTA_BAKTADBDOWNLOAD(db_type)
            ch_bakta_db = BAKTA_BAKTADBDOWNLOAD.out.db
        }

        GENERATE_CONSENSUS(
            ch_variants,
            TARGETED_ALIGNMENT.out.reference,
            TARGETED_ALIGNMENT.out.bam,
            TARGETED_ALIGNMENT.out.bai,
            ch_bakta_db,
            ch_proteins,
            ch_tf,
            ch_regions,
            ch_hmms,
            abricate_db_list,
            // params.amrfinder_organisms
        )


    }


    //
    // Collate and save software versions
    //
    def topic_versions = Channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_'  +  'wwmetagen_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        channel.fromPath(params.multiqc_config, checkIfExists: true) :
        channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    emit:multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
