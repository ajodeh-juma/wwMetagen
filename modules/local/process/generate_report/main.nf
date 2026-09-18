process GENERATE_REPORT {
    tag "Generating report"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"

    container 'wave.seqera.io/wt/7231418c545b/wave/build:r-tidyverse_r-argparse_r-zoo_r-viridis--4cee4cd0fb9b5041'

    input:
    path metrics_csv 
    val pmmov_threshold

    output:
    path "*_report.csv"               , emit: report
    path "*_summary.csv"              , emit: summary
    path "*.png"                      , emit: plots
    path "versions.yml"               , emit: versions

    script:
    """
    # Run the R script using the current directory as input
    # Scripts in bin/ are automatically added to the PATH by Nextflow
    wastewater.R \\
        --input ${metrics_csv} \\
        --threshold ${pmmov_threshold} \\
        --outdir .

    # Capture software versions for reproducibility
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        R: \$(R --version | head -n 1 | cut -d ' ' -f 3)
        tidyverse: \$(Rscript -e "packageVersion('tidyverse')" | awk '{print \$2}' | tr -d "‘" | tr -d "’")
        optparse: \$(Rscript -e "packageVersion('optparse')" | awk '{print \$2}' | tr -d "‘" | tr -d "’")
    END_VERSIONS
    """
}
