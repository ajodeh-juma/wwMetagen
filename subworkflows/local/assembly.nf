/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { MEGAHIT                }     from '../../modules/local/process/megahit'
include { QUAST                  }     from '../../modules/local/process/quast'
include { ALIGN_TO_CONTIGS       }     from '../local/align_to_contigs'
include { BINNING_REFINEMENT     }     from '../local/binning_refinement'
include { BINNING_ANALYSIS       }     from '../local/binning_analysis'
include { AMR_VIRULENCE_ANALYSIS }     from '../local/amr_virulence_analysis'



workflow ASSEMBLY {

    take:
    ch_hostile_clean_reads // dehosted and preprocessed reads

    main:

    //
    // MODULE: De novo assembly
    //

    MEGAHIT(ch_hostile_clean_reads)
    ch_assembly = MEGAHIT.out.contigs

    //
    // MODULE: assembly metrics
    //
    QUAST(ch_assembly)

    // join reads and contigs into a single channel by their metadata/sample ID
    ch_align_input = ch_hostile_clean_reads.join(MEGAHIT.out.contigs)
    
    // 
    // SUBWORKFLOW: alignment to contigs
    //
    ALIGN_TO_CONTIGS(ch_align_input)

    //
    // SUBWORKFLOW: binning, refinement
    //
    BINNING_REFINEMENT(
        MEGAHIT.out.contigs,
        ALIGN_TO_CONTIGS.out.bam,
        ALIGN_TO_CONTIGS.out.bai,
        ALIGN_TO_CONTIGS.out.coverage,
        ch_hostile_clean_reads
    )

    //
    // SUBWORKFLOW: bins analysis - pathogen quality control and prediction
    //

    BINNING_ANALYSIS(
        BINNING_REFINEMENT.out.refined_bins,
        MEGAHIT.out.contigs
    )

    //
    // SUBWORKFLOW: amr and virulence factors analysis
    //

    def abricate_db_list  = params.abricate_dbs.tokenize(',')
    // def organisms_list    = params.amrfinder_organisms.tokenize(',')

    AMR_VIRULENCE_ANALYSIS ( 
        MEGAHIT.out.contigs,
        BINNING_REFINEMENT.out.refined_bins, 
        abricate_db_list,
        params.amrfinder_organisms
    )


    emit:
    contigs    = MEGAHIT.out.contigs
    bam        = ALIGN_TO_CONTIGS.out.bam
    quast      = QUAST.out.tsv


}