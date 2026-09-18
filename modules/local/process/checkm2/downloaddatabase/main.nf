def downloadZenodoApiEntry(zenodo_id) {
    // Download metadata from Zenodo API, setting "Accept: application/json" header
    def api_url  = "https://zenodo.org/api/records/${zenodo_id}"
    def conn     = new URL(api_url).openConnection()
    conn.setRequestProperty('Accept', 'application/json')
    conn.setRequestProperty('User-Agent', "Nextflow ${nextflow.version ?: ''}".trim())

    def api_text = conn.getInputStream().getText('UTF-8')
    def parser   = new groovy.json.JsonSlurper()

    return parser.parseText(api_text)
}

process CHECKM2_DOWNLOADDATABASE {
    tag "Downloading CheckM2 DB"
    label 'process_single'

    conda "${moduleDir}/environment.yml"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/95/95c0d3d867f5bc805b926b08ee761a993b24062739743eb82cc56363e0f7817d/data':
        'community.wave.seqera.io/library/aria2:1.37.0--3a9ec328469995dd' }"

    input:
    val(db_zenodo_id)

    output:
    tuple val(meta), path("checkm2_db_v${db_version}.dmnd"), emit: database
    path "versions.yml"                                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def zenodo_id = db_zenodo_id ?: 14897628
    api_data   = downloadZenodoApiEntry(zenodo_id)
    db_version = api_data.metadata.version
    meta = [id: 'checkm2_db', zenodo_id: zenodo_id]

    """
    # Automatic download is broken when using singularity/apptainer (https://github.com/chklovski/CheckM2/issues/73)
    # So it's necessary to download the database manually
    aria2c \\
        --user-agent="Wget/1.21.4" \\
        https://zenodo.org/records/${zenodo_id}/files/checkm2_database.tar.gz

    tar -xzf checkm2_database.tar.gz

    db_path=\$(find . -name *.dmnd)
    mv \$db_path checkm2_db_v${db_version}.dmnd

    # cleanup
    # rm -f checkm2_database.tar.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        aria2c:  \$(aria2c --version 2>&1) | grep 'aria2 version' | cut -f3 -d ' '
    END_VERSIONS
    """

    stub:
    """
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        aria2c:  \$(aria2c --version 2>&1) | grep 'aria2 version' | cut -f3 -d ' '
    END_VERSIONS
    """
}
