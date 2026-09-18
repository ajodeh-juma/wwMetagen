// merge all fastp metrics

process MERGE_FASTP_METRICS {
    tag 'merge_fastp'
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:2.2.1' :
        'biocontainers/pandas:2.2.1' }"

    input:
    path tsv_files // Collects all individual TSVs into a list

    output:
    path "fastp_summary.tsv", emit: combined_tsv

    script:
    """
    python <<EOF
    import pandas as pd
    import glob

    # Read all files passed as arguments and merge
    file_list = "${tsv_files}".split()
    df_list = [pd.read_csv(f, sep='\t') for f in file_list]
    
    if df_list:
        combined_df = pd.concat(df_list, ignore_index=True)
        # Optional: Sort by sample name
        combined_df.sort_values('sample_name', inplace=True)
        combined_df.to_csv("fastp_summary.tsv", sep='\t', index=False)
    EOF
    """
}
