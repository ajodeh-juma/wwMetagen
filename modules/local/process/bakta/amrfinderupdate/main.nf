process BAKTA_AMRFINDER_UPDATE {
    tag "update_amrfinder_in_bakta"
    label 'process_single'

    conda "${moduleDir}/environment.yml"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ncbi-amrfinderplus:4.2.7--hf69ffd2_0':
        'biocontainers/ncbi-amrfinderplus:4.2.7--hf69ffd2_0' }"

    input:
    path db 

    output:
    path "db", emit: db

    script:
    """
    cp -r ${db} ./db

    AMR_PATH=\$(find db -type d -name "amrfinder*" | head -n 1)

    if [ -z "\$AMR_PATH" ]; then
        echo "Error: Could not locate amrfinderplus db inside the provided database directory."
        exit 1
    fi

    amrfinder_update --force_update --database "\$AMR_PATH"
    """
}
