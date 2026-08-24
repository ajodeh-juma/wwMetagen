process GENOMAD_DOWNLOADDATABASE {
    tag "Downloading Genomad DB"
    label 'process_high'


    conda "bioconda::genomad"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/genomad:1.5.2--pyhdfd78af_0':
        'biocontainers/genomad:1.5.2--pyhdfd78af_0' }"

    output:
    path "genomad_db/"   , emit: genomad_db


    script:

    """

    genomad download-database .

    """

    stub:
    """
    mkdir genomad_db
    touch genomad_db/genomad_db
    touch genomad_db/genomad_db.dbtype
    touch genomad_db/genomad_db.index
    touch genomad_db/genomad_db.lookup
    touch genomad_db/genomad_db.source
    touch genomad_db/genomad_db_h
    touch genomad_db/genomad_db_h.dbtype
    touch genomad_db/genomad_db_h.index
    touch genomad_db/genomad_db_mapping
    touch genomad_db/genomad_db_taxonomy
    touch genomad_db/genomad_integrase_db
    touch genomad_db/genomad_integrase_db.dbtype
    touch genomad_db/genomad_integrase_db.index
    touch genomad_db/genomad_integrase_db.lookup
    touch genomad_db/genomad_integrase_db.source
    touch genomad_db/genomad_integrase_db_h
    touch genomad_db/genomad_integrase_db_h.dbtype
    touch genomad_db/genomad_integrase_db_h.index
    touch genomad_db/genomad_marker_metadata.tsv
    touch genomad_db/genomad_mini_db
    touch genomad_db/genomad_mini_db.dbtype
    touch genomad_db/genomad_mini_db.index
    touch genomad_db/genomad_mini_db.lookup
    touch genomad_db/genomad_mini_db.source
    touch genomad_db/genomad_mini_db_h
    touch genomad_db/genomad_mini_db_h.dbtype
    touch genomad_db/genomad_mini_db_h.index
    touch genomad_db/genomad_mini_db_mapping
    touch genomad_db/genomad_mini_db_taxonomy
    touch genomad_db/mini_set_ids
    touch genomad_db/names.dmp
    touch genomad_db/nodes.dmp
    touch genomad_db/plasmid_hallmark_annotation.txt
    touch genomad_db/version.txt
    touch genomad_db/virus_hallmark_annotation.txt

    """
}
