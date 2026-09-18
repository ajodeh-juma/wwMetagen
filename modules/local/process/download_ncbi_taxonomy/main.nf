// Download NCBI taxonomy files
process DOWNLOAD_NCBI_TAXONOMY {
    tag "${taxonomy_url}"
    label "taxonomy"
    label "single"

    // flexible caching if the source metadata fluctuates
    cache 'lenient'

    input:
    val taxonomy_url

    output:
    path "taxonomy.zip", emit: tax_zip

    script:
    
    """
    wget -q --show-progress "${taxonomy_url}" -O taxonomy.zip
    """

}
