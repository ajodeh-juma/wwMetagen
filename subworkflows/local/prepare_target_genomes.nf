/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW: PREPARE_TARGET_GENOMES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { DOWNLOAD_NCBI_TAXONOMY              } from '../../modules/local/process/download_ncbi_taxonomy/main'
include { NCBI_DATASETS_DOWNLOAD_GENOMES      } from '../../modules/local/process/ncbi_datasets_download_genomes'

workflow PREPARE_TARGET_GENOMES {
    take:
    ch_taxonomy_url          // value: NCBI taxonomy URL
    ch_taxid                 // value: Taxid
    ch_max_attempts          // value: number of maximum number of attempts for download
    ch_is_reference          // value: true or false
    

    main:
    versions = Channel.empty()

    //
    // MODULE: DOWNLOAD_NCBI_TAXONOMY
    //
    DOWNLOAD_NCBI_TAXONOMY(ch_taxonomy_url)


    //
    // MODULE: Download genomes
    //
    NCBI_DATASETS_DOWNLOAD_GENOMES(ch_taxid)


    // if (params.pathogen_fasta) {
    //     ch_pathogen_fasta = Channel.fromPath(params.pathogen_fasta, checkIfExists: true)
    //     // pathogen_name = file(params.ref_fasta).baseName
    // } else if (params.pathogen_list) {
    //     ch_pathogens_tsv = Channel.fromPath(params.pathogen_list)
    //     BUILD_PATHOGEN_DB(ch_pathogens_tsv)
    //     ch_pathogen_fasta = BUILD_PATHOGEN_DB.out.fasta
    //     ch_versions = BUILD_PATHOGEN_DB.out.versions
    // }

    //
    // MODULE: MINIMAP2_INDEX - Build minimap2 index for the pathogens FASTA
    //

    // if (params.pathogen_index) {
    //     index_ch = Channel.fromPath(params.pathogen_index, checkIfExists: true)
    //     pathogen_index_ch = index_ch.collect()
    // } else {
    //     MINIMAP2_INDEX(ch_pathogen_fasta)
    //     pathogen_index_ch = MINIMAP2_INDEX.out.index.collect()
    // } 

    // //
    // // MODULE: Align dehosted reads to the pathogens references
    // //
    // MINIMAP2_ALIGN(
    //     ch_reads, 
    //     pathogen_index_ch
    // )
    // ch_versions = ch_versions.mix(MINIMAP2_ALIGN.out.versions)


    //
    // MODULE: Calculate pathogen metrics from coverage results
    //
    // PATHOGEN_METRICS(
    //     MINIMAP2_ALIGN.out.coverage,
    //     ch_pathogens_tsv.collect()
    // )


    //
    // MODULE: Generate report
    //
    // channel for all the metrics csv files
    // ch_pathogen_metrics = PATHOGEN_METRICS.out.metrics
    // ch_pathogen_metrics
    //     .filter { row -> file(row[1])}
    //     .map { it[1] }
    //     .set { ch_pathogen_metrics }


    //
    // MODULE: Get specific target pathogen reference genome
    //

    // GET_PATHOGEN_REFERENCE(params.target_ref, BUILD_PATHOGEN_DB.out.fasta)


    // // wave --conda-package r-tidyverse --conda-package r-argparse --conda-package r-zoo --conda-package r-viridis
    // GENERATE_REPORT(
    //     ch_pathogen_metrics.collect(),
    //     params.ppmov_threshold
    // )

    

    emit:
    
    // fasta          = NCBI_DATASETS_DOWNLOAD_GENOMES.genomes
    // metadata       = NCBI_DATASETS_DOWNLOAD_GENOMES.metadata
    versions       = NCBI_DATASETS_DOWNLOAD_GENOMES.versions
}