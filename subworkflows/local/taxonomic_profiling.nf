/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW: TAXONOMIC_PROFILING
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { KRAKEN2_KRAKEN2          } from '../../modules/local/process/kraken2_kraken2'
include { BRACKEN_BRACKEN          } from '../../modules/local/process/bracken_bracken'
include { KRAKENTOOLS_KREPORT2MPA as KRAKENTOOLS_KREPORT2MPA_KRAKEN2  } from '../../modules/local/process/krakentools_kreport2mpa'
include { KRAKENTOOLS_KREPORT2MPA as KRAKENTOOLS_KREPORT2MPA_BRACKEN  } from '../../modules/local/process/krakentools_kreport2mpa'
include { MERGE_MPA_REPORTS as MERGE_MPA_REPORTS_KRAKEN2              } from '../../modules/local/process/merge_mpa_reports'
include { MERGE_MPA_REPORTS as MERGE_MPA_REPORTS_BRACKEN              } from '../../modules/local/process/merge_mpa_reports'
include { EXTRACT_DOMAIN_METRICS as EXTRACT_DOMAIN_METRICS_KRAKEN2    } from '../../modules/local/process/extract_domain_metrics'
include { EXTRACT_DOMAIN_METRICS as EXTRACT_DOMAIN_METRICS_BRACKEN    } from '../../modules/local/process/extract_domain_metrics'
include { MERGE_DOMAIN_METRICS as MERGE_DOMAIN_METRICS_KRAKEN2        } from '../../modules/local/process/merge_domain_metrics'
include { MERGE_DOMAIN_METRICS as MERGE_DOMAIN_METRICS_BRACKEN        } from '../../modules/local/process/merge_domain_metrics'
include { NORMALIZE_ABUNDANCES as NORMALIZE_ABUNDANCES_KRAKEN2        } from '../../modules/local/process/normalize_abundances'
include { NORMALIZE_ABUNDANCES as NORMALIZE_ABUNDANCES_BRACKEN        } from '../../modules/local/process/normalize_abundances'
include { KRAKENUNIQ               } from '../../modules/local/process/krakenuniq'

workflow TAXONOMIC_PROFILING {
    take:
    ch_reads         // [meta, path(bins_dir)]
    ch_kraken2_db

    main:
    ch_versions = Channel.empty()

    //
    // MODULE: Kraken2 - taxonomic classification 
    //

    KRAKEN2_KRAKEN2( ch_reads, ch_kraken2_db )
    ch_versions = ch_versions.mix(KRAKEN2_KRAKEN2.out.versions)


    // 
    // MODULE: KrakenTools Kreport to mpa - convert kraken2-style report to metaphlan-style report
    //
    KRAKENTOOLS_KREPORT2MPA_KRAKEN2 ( KRAKEN2_KRAKEN2.out.report )
    ch_versions = ch_versions.mix(KRAKENTOOLS_KREPORT2MPA_KRAKEN2.out.versions)



    //
    // MODULE: Merge MPA format files for Bracken
    //
    ch_kraken2_mpa = KRAKENTOOLS_KREPORT2MPA_KRAKEN2.out.mpa
    ch_kraken2_mpa
        .filter { row -> file(row[1]) }
        .map { it[1] }
        .set { ch_kraken2_mpa }
    MERGE_MPA_REPORTS_KRAKEN2(ch_kraken2_mpa.collect(), 'kraken2')

    // 
    // MODULE: Extract domain metrics from Kraken2 report and merge
    //
    EXTRACT_DOMAIN_METRICS_KRAKEN2 ( KRAKEN2_KRAKEN2.out.report )

    ch_kraken2_domain_metrics = EXTRACT_DOMAIN_METRICS_KRAKEN2.out.tsv
    ch_kraken2_domain_metrics
        .filter { row -> file(row[1]) }
        .map { it[1] }
        .set { ch_kraken2_domain_metrics }
    MERGE_DOMAIN_METRICS_KRAKEN2(ch_kraken2_domain_metrics.collect(), 'kraken2')



    //
    // MODULE: Normalize Kraken2 abundances
    //

    // After merging is complete
    NORMALIZE_ABUNDANCES_KRAKEN2(
        MERGE_MPA_REPORTS_KRAKEN2.out.report, 
        MERGE_DOMAIN_METRICS_KRAKEN2.out.report,
        "kraken2"
    )




    //////////////////////////////////////////////////////////////////////////////


    // 
    // MODULE: Bracken - Abundance re-estimation
    //

    BRACKEN_BRACKEN (KRAKEN2_KRAKEN2.out.report, ch_kraken2_db )
    ch_versions = ch_versions.mix(BRACKEN_BRACKEN.out.versions)


    // 
    // MODULE: KrakenTools Bracken report to mpa - convert kraken2-style report to metaphlan-style report
    //
    KRAKENTOOLS_KREPORT2MPA_BRACKEN ( BRACKEN_BRACKEN.out.tax_level_report )
    ch_versions = ch_versions.mix(KRAKENTOOLS_KREPORT2MPA_BRACKEN.out.versions)


    //
    // MODULE: Merge MPA format files for Bracken
    //
    ch_bracken_mpa = KRAKENTOOLS_KREPORT2MPA_BRACKEN.out.mpa
    ch_bracken_mpa
        .filter { row -> file(row[1]) }
        .map { it[1] }
        .set { ch_bracken_mpa }
    MERGE_MPA_REPORTS_BRACKEN(ch_bracken_mpa.collect(), 'bracken')

    // 
    // MODULE: Extract domain metrics from Bracken report and merge
    //
    EXTRACT_DOMAIN_METRICS_BRACKEN ( BRACKEN_BRACKEN.out.tax_level_report )

    ch_bracken_domain_metrics = EXTRACT_DOMAIN_METRICS_BRACKEN.out.tsv
    ch_bracken_domain_metrics
        .filter { row -> file(row[1]) }
        .map { it[1] }
        .set { ch_bracken_domain_metrics }
    MERGE_DOMAIN_METRICS_BRACKEN(ch_bracken_domain_metrics.collect(), 'bracken')


     //
    // MODULE: Normalize bracken abundances - they are already normalized but we use a scaling factor to match that of krakens
    //

    // After merging is complete
    NORMALIZE_ABUNDANCES_BRACKEN(
        MERGE_MPA_REPORTS_BRACKEN.out.report, 
        MERGE_DOMAIN_METRICS_BRACKEN.out.report,
        "bracken"
    )



    // 
    // MODULE: KrakenUniq - get unique k-mers
    //

    // KRAKENUNIQ ( ch_reads, ch_kraken2_db )
    // ch_versions = ch_versions.mix(KRAKENUNIQ.out.versions)
    

    emit:
    kraken2_report         = KRAKEN2_KRAKEN2.out.report
    kraken2_mpa_report     = KRAKENTOOLS_KREPORT2MPA_KRAKEN2.out.mpa
    bracken_report         = BRACKEN_BRACKEN.out.report
    bracken_mpa_report     = KRAKENTOOLS_KREPORT2MPA_BRACKEN.out.mpa
    // krakenuniq_report = KRAKENUNIQ.out.report
    versions       = ch_versions
}