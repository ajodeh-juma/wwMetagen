/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW: TARGETED_ALIGNMENT
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { DOWNLOAD_NCBI_TAXONOMY    } from '../../modules/local/process/download_ncbi_taxonomy'
include { NCBI_DOWNLOAD_SINGLE as NCBI_DOWNLOAD_PATHOGEN     } from '../../modules/local/process/ncbi_download_single'
include { NCBI_DOWNLOAD_SINGLE as NCBI_DOWNLOAD_INDICATOR    } from '../../modules/local/process/ncbi_download_single'
include { CONCATENATE_PATHOGEN_INDICATOR_GENOMES             } from '../../modules/local/process/concatenate_pathogen_indicator_genomes'
include { NCBI_DOWNLOAD_BATCH    } from '../../modules/local/process/ncbi_download_batch'
include { BUILD_PATHOGEN_DB      } from '../../modules/local/process/build_pathogen_db'
include { MINIMAP2_INDEX as MINIMAP2_INDEX_SINGLE       } from '../../modules/local/process/minimap2_index'
include { MINIMAP2_ALIGN as MINIMAP2_ALIGN_SINGLE       } from '../../modules/local/process/minimap2_align'
include { COMPUTE_PATHOGEN_METRICS as COMPUTE_PATHOGEN_METRICS_SINGLE   } from '../../modules/local/process/compute_pathogen_metrics'
include { GET_PATHOGEN_REFERENCE } from '../../modules/local/process/get_pathogen_reference'
include { GENERATE_REPORT        } from '../../modules/local/process/generate_report'

// include { CALL_VARIANTS } from './call_variants'
include { MINIMAP2_INDEX as MINIMAP2_INDEX_TARGET       } from '../../modules/local/process/minimap2_index'
include { MINIMAP2_ALIGN as MINIMAP2_ALIGN_TARGET       } from '../../modules/local/process/minimap2_align'
include { SAMTOOLS_FAIDX as SAMTOOLS_FAIDX_TARGET       } from '../../modules/local/process/samtools_faidx'
include { LOFREQ_INDELQUAL } from '../../modules/nf-core/lofreq/indelqual'
include { SAMTOOLS_INDEX as SAMTOOLS_INDEX_INDELQUAL       } from '../../modules/local/process/samtools_index'
include { LOFREQ_VITERBI } from '../../modules/nf-core/lofreq/viterbi'
include { SAMTOOLS_INDEX as SAMTOOLS_INDEX_VITERBI       } from '../../modules/local/process/samtools_index'
// include { LOFREQ_ALNQUAL } from '../../modules/nf-core/lofreq/alnqual'
// include { SAMTOOLS_INDEX as SAMTOOLS_INDEX_ALNQUAL       } from '../../modules/local/process/samtools_index'
include { LOFREQ_CALLPARALLEL } from '../../modules/local/process/lofreq_callparallel'
include { LOFREQ_FILTER       } from '../../modules/local/process/lofreq_filter'
include { REHEADER_VCF        } from '../../modules/local/process/reheader_vcf'
include { CALCULATE_DIVERSITY } from '../../modules/local/process/calculate_diversity'


workflow TARGETED_ALIGNMENT {
    take:
    // ch_taxonomy_url          // value: NCBI taxonomy URL
    ch_taxid                 // value: Taxid
    // ch_pathogen_fasta        // path(fasta)
    // ch_pathogen_taxids      // [meta, path(pathogens.tsv)]
    ch_n_genomes             // number of genomes to download if a single taxid is provided otherwise 1 for a file containing pathogen taxids  
    ch_max_attempts          // maximum number of attempts for ncbi-datasets-cli for doenloading
    ch_reads                 // [meta, path(reads)]
    

    main:
    ch_versions = Channel.empty()

    //
    // MODULE: DOWNLOAD_NCBI_TAXONOMY
    //
    // DOWNLOAD_NCBI_TAXONOMY(ch_taxonomy_url)


    //
    // MODULE: Download fecal marker genomes
    //

    // channel for fecal markers from the config string
    ch_marker_taxids = channel
        .fromList(params.marker_taxids.tokenize(','))
        .map { it.trim() }


    NCBI_DOWNLOAD_INDICATOR(ch_marker_taxids, ch_n_genomes, ch_max_attempts)


    //
    // MODULE: Download genome for single pathogen using the specified TaxID --target_pathogen_taxid
    //

    NCBI_DOWNLOAD_PATHOGEN(ch_taxid, ch_n_genomes, ch_max_attempts)



    // collect all pathogen and indicator fecal marker genomes and metadata

    ch_target_pathogen = NCBI_DOWNLOAD_PATHOGEN.out.genome
        .join(NCBI_DOWNLOAD_PATHOGEN.out.metadata)


    ch_indicator_fastas = NCBI_DOWNLOAD_INDICATOR.out.genome.map{ it[1] }.collect().map{ [it] }
    ch_indicator_metas  = NCBI_DOWNLOAD_INDICATOR.out.metadata.map{ it[1] }.collect().map{ [it] }



    // combine the pathogen with the fecal indicator markers
    // this creates a channel: [ val(taxid), path(p_fasta), path(p_meta), [f_fastas], [f_metas] ]

    // 2. Pair each pathogen with the global list of indicators
    // We use .combine() so EVERY pathogen gets the same set of indicators
    ch_pathogen_indicators = ch_target_pathogen
        .combine(ch_indicator_fastas)
        .combine(ch_indicator_metas)
        .map { taxid, p_fasta, p_meta, f_fastas, f_metas ->
            // Now f_fastas and f_metas will correctly arrive as ArrayLists
            def meta = [ id: "${taxid}" ]
            return [ meta, [p_fasta] + f_fastas, [p_meta] + f_metas ]
        }

    //
    // MODULE: concatenate pathogen and fecal indicator pathogens genomes and metadata
    //
    CONCATENATE_PATHOGEN_INDICATOR_GENOMES(ch_pathogen_indicators)



    //
    // MODULE: MINIMAP2_INDEX - Build minimap2 index for a single target reference pathogen specified with --target_pathogen_taxid 
    //
    ch_fasta = CONCATENATE_PATHOGEN_INDICATOR_GENOMES.out.fasta.map { meta, fasta -> fasta }
    MINIMAP2_INDEX_SINGLE(ch_fasta)


    //
    // MODULE: Align dehosted reads to the single target reference pathogen specified with --target_pathogen_taxid 
    //

    MINIMAP2_ALIGN_SINGLE(
        ch_reads, 
        MINIMAP2_INDEX_SINGLE.out.index.collect()
    )
    ch_versions = ch_versions.mix(MINIMAP2_ALIGN_SINGLE.out.versions)



    //
    // MODULE: Calculate pathogen metrics
    //

    ch_metadata = CONCATENATE_PATHOGEN_INDICATOR_GENOMES.out.metadata.map { meta, metadata -> metadata }
    COMPUTE_PATHOGEN_METRICS_SINGLE(
        MINIMAP2_ALIGN_SINGLE.out.coverage,
        ch_metadata.collect()
    )



    ch_fasta_target = NCBI_DOWNLOAD_PATHOGEN.out.genome.map{ it[1] }.collect()

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
    SAMTOOLS_FAIDX_TARGET(NCBI_DOWNLOAD_PATHOGEN.out.genome)

    //
    // MODULE: insert indel qualities in a BAM file and index
    //
    LOFREQ_INDELQUAL(
        MINIMAP2_ALIGN_TARGET.out.bam, 
        NCBI_DOWNLOAD_PATHOGEN.out.genome.collect(), 
        SAMTOOLS_FAIDX_TARGET.out.fai
    )
    SAMTOOLS_INDEX_INDELQUAL(LOFREQ_INDELQUAL.out.bam)

    //
    // MODULE: realign and index
    //
    LOFREQ_VITERBI(
        LOFREQ_INDELQUAL.out.bam,
        NCBI_DOWNLOAD_PATHOGEN.out.genome.collect()
    )
    // println(LOFREQ_VITERBI.out.bam.view())
    SAMTOOLS_INDEX_VITERBI(LOFREQ_VITERBI.out.bam)


    // //
    // // MODULE: commpute illumina specific BAQ (uses the -b flag)
    // //
    // LOFREQ_ALNQUAL(
    //     LOFREQ_VITERBI.out.bam,
    //     NCBI_DOWNLOAD_PATHOGEN.out.genome.collect(),
    // )
    // SAMTOOLS_INDEX_ALNQUAL(LOFREQ_ALNQUAL.out.bam)


    ch_bams_bai_lofreq = LOFREQ_VITERBI.out.bam.join(SAMTOOLS_INDEX_VITERBI.out.bai)
    ch_fasta_fai_lofreq = NCBI_DOWNLOAD_PATHOGEN.out.genome.join(SAMTOOLS_FAIDX_TARGET.out.fai)

    // println(ch_bams_bai_lofreq.view())

    LOFREQ_CALLPARALLEL(
        ch_bams_bai_lofreq,
        ch_fasta_fai_lofreq.collect()
    )

    LOFREQ_FILTER(
        LOFREQ_CALLPARALLEL.out.vcf
    )

    // add chromosome lengths to the VCF files

    REHEADER_VCF(
        LOFREQ_FILTER.out.vcf,
        SAMTOOLS_FAIDX_TARGET.out.fai
    )

    CALCULATE_DIVERSITY(
        REHEADER_VCF.out.vcf,
        params.diversity_window_size
    )

    //
    // MODULE: Download multiple genomes
    //
    // NCBI_DOWNLOAD_BATCH(ch_pathogen_taxids, ch_max_attempts)

    
    // //
    // // MODULE: BUILD_PATHOGEN_DB - Fetch the pathogens of interest or use the user-provides FASTA
    // //

    // if (params.pathogen_fasta) {
    //     ch_pathogen_fasta = Channel.fromPath(params.pathogen_fasta, checkIfExists: true)
    //     // pathogen_name = file(params.ref_fasta).baseName
    // } else if (params.pathogen_list) {
    //     ch_pathogens_tsv = Channel.fromPath(params.pathogen_list)
    //     BUILD_PATHOGEN_DB(ch_pathogens_tsv)
    //     ch_pathogen_fasta = BUILD_PATHOGEN_DB.out.fasta
    //     ch_versions = BUILD_PATHOGEN_DB.out.versions
    // }

    // //
    // // MODULE: MINIMAP2_INDEX - Build minimap2 index for the pathogens FASTA
    // //

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
    bam                     = LOFREQ_VITERBI.out.bam
    bai                     = SAMTOOLS_INDEX_VITERBI.out.bai
    vcf                     = REHEADER_VCF.out.vcf
    tbi                     = REHEADER_VCF.out.tbi
    reference               = NCBI_DOWNLOAD_PATHOGEN.out.genome
    coverage                = MINIMAP2_ALIGN_TARGET.out.coverage
    versions                = ch_versions
}