include { BCFTOOLS_NORM                          }     from '../../modules/local/process/bcftools/norm/main'
include { BCFTOOLS_FILTER                        }     from '../../modules/local/process/bcftools/filter/main'
include { GENERATE_MASK                          }     from '../../modules/local/process/mask/generate_mask'
include { BCFTOOLS_CONSENSUS                     }     from '../../modules/local/process/bcftools/consensus/main'

include { ANNOTATE_CONSENSUS                     }     from '../local/annotate_consensus'
include { ALIGNMENT_AMR_VIRULENCE_ANALYSIS       }     from '../local/alignment_amr_virulence_analysis'



workflow GENERATE_CONSENSUS {
    take:
    ch_variants
    ch_reference
    ch_bam
    ch_bai
    ch_bakta_db
    ch_proteins
    ch_prodigal_tf
    ch_regions
    ch_hmms
    abricate_db_list 
    // organisms_list

    main:
    ch_versions = Channel.empty()

    //
    // MODULE: Normalize variants
    //

    BCFTOOLS_NORM(ch_variants, ch_reference)


    //
    // MODULE: Filter variants on QUAL > params.qual ; adjust this in the nextflow.config
    //

    ch_bcftools_filter_input = BCFTOOLS_NORM.out.vcf.join(BCFTOOLS_NORM.out.index)
    BCFTOOLS_FILTER(ch_bcftools_filter_input)

    //
    // MODULE: Generate regions with low depth
    //

    ch_generate_mask_input = ch_bam.join(ch_bai)

    GENERATE_MASK(ch_generate_mask_input)

    //
    // MODULE: Generate consensus
    //

    ch_bcftools_consensus_input = BCFTOOLS_FILTER.out.vcf.join(BCFTOOLS_FILTER.out.index).join(GENERATE_MASK.out.bed)

    BCFTOOLS_CONSENSUS(ch_bcftools_consensus_input, ch_reference)

    ch_consensus = BCFTOOLS_CONSENSUS.out.consensus.map { 
        meta, fasta -> [ meta + [type: 'consensus'], fasta ] 
    }


    //
    // MODULE: Annotate consensus
    //

    ANNOTATE_CONSENSUS(
        ch_consensus,
        ch_bakta_db,
        ch_proteins,
        ch_prodigal_tf,
        ch_regions,
        ch_hmms
    )


    //
    // SUBWORKFLOW: AMR profiling and Virulence analysis
    //

    ALIGNMENT_AMR_VIRULENCE_ANALYSIS(
        ch_consensus, 
        abricate_db_list, 
        params.amrfinder_organisms
    )
    
    emit:
    abricate_contigs_report  = ALIGNMENT_AMR_VIRULENCE_ANALYSIS.out.abricate_contigs_report
    amrfinder_contigs_report = ALIGNMENT_AMR_VIRULENCE_ANALYSIS.out.amrfinder_contigs_report
    versions  = ch_versions.mix(BCFTOOLS_CONSENSUS.out.versions_bcftools)
    consensus = ch_consensus
}