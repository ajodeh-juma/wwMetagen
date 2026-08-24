process CONCATENATE_PATHOGEN_INDICATOR_GENOMES {
    tag "${meta.id}"
    label "process_low"

    input:
    tuple val(meta), path(fastas), path(metas)

    output:
    tuple val(meta), path("${meta.id}_ref.fasta")    , emit: fasta
    tuple val(meta), path("${meta.id}_metadata.tsv") , emit: metadata

    script:
    """
    # concatenate FASTA sequences
    # use 'cat' - safe here as your previous step injected TaxIDs into headers
    cat ${fastas} > ${meta.id}_ref.fasta

    # concatenate Metadata TSVs
    # extract the header from the very first file (the pathogen meta)
    head -n 1 ${metas[0]} > ${meta.id}_metadata.tsv
    
    # append content from all files, skipping their headers
    for f in ${metas}; do
        tail -n +2 \$f >> ${meta.id}_metadata.tsv
    done
    """
}