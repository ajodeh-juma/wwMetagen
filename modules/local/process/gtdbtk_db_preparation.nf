
process GTDBTK_DB_PREPARATION {
    tag "${database}"

    conda "conda-forge::sed=4.7"

    conda "bioconda::gtdbtk=2.3.2"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/ubuntu:20.04'
        : 'biocontainers/ubuntu:20.04'}"

    input:
    path(database)

    output:
    tuple val("${database.toString().replace(".tar.gz", "")}"), path("database/*"), emit: db

    script:
    """
    mkdir database
    tar -xzf ${database} -C database --strip 1
    """
}