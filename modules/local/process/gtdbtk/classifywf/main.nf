process GTDBTK_CLASSIFYWF {
    tag "${meta.id}"
    label 'process_high_memory'

    conda "${moduleDir}/environment.yml"

    // gtdbtk:2.3.2--pyhdfd78af_0
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/gtdbtk:2.4.1--pyhdfd78af_1'
        : 'biocontainers/gtdbtk:2.4.1--pyhdfd78af_1'}"

    input:
    tuple val(meta)   , path("bins/*")
    tuple val(db_name), path(db)
    path(mash_db)


    output:
    tuple val(meta), path("${prefix}")                               , emit: gtdb_outdir
    tuple val(meta), path("${prefix}/classify/*.summary.tsv")        , emit: summary
    tuple val(meta), path("${prefix}/classify/*.classify.tree")      , emit: tree       , optional: true
    tuple val(meta), path("${prefix}/identify/*.markers_summary.tsv"), emit: markers    , optional: true
    tuple val(meta), path("${prefix}/align/*.msa.fasta.gz")          , emit: msa        , optional: true
    tuple val(meta), path("${prefix}/align/*.user_msa.fasta.gz")     , emit: user_msa   , optional: true
    tuple val(meta), path("${prefix}/align/*.filtered.tsv")          , emit: filtered   , optional: true
    tuple val(meta), path("${prefix}/identify/*.failed_genomes.tsv") , emit: failed     , optional: true
    tuple val(meta), path("${prefix}/${prefix}.log")                 , emit: log
    tuple val(meta), path("${prefix}/${prefix}.warnings.log")        , emit: warnings
    path("versions.yml")                                             , emit: versions

    // tuple val("${task.process}"), val('gtdbtk'), eval("gtdbtk --version 2>&1 | grep -Eo '[0-9]+(\\.[0-9]+)+' | head -1") , topic: versions, emit: versions_gtdbtk
    // tuple val("${task.process}"), val('gtdb_db'), eval('grep VERSION_DATA $GTDBTK_DATA_PATH/metadata/metadata.txt | sed "s/VERSION_DATA=//"'), topic: versions, emit: versions_gtdbtk_db

    when:
    task.ext.when == null || task.ext.when

    script:
    def args            = task.ext.args ?: ''
    prefix              = task.ext.prefix ?: "${meta.id}"
    // def pplacer_scratch = use_pplacer_scratch_dir ? "--scratch_dir pplacer_tmp" : ""
    def extension = params.gtdbtk_extension ?: "fa" // Default to fa, but adjustable
    def pplacer_scratch = params.gtdbtk_pplacer_scratch ? "--scratch_dir pplacer_tmp" : ""
    def mash_mode = mash_db ? "--mash_db ${mash_db}" : "--skip_ani_screen"

    """
    export GTDBTK_DATA_PATH="\$(find -L ${db} -name 'metadata' -type d -exec dirname {} \\;)"

    if [ "${pplacer_scratch}" != "" ] ; then
        mkdir pplacer_tmp
    fi

    gtdbtk classify_wf \\
        ${args} \\
        --genome_dir bins \\
        --extension ${extension} \\
        --prefix "${prefix}" \\
        --out_dir ${prefix} \\
        --cpus ${task.cpus} \\
        ${pplacer_scratch} \\
        $mash_mode \\
        --min_perc_aa $params.gtdbtk_min_perc_aa \\
        --min_af $params.gtdbtk_min_af

    mv ${prefix}/gtdbtk.log "${prefix}/${prefix}.log"
    mv ${prefix}/gtdbtk.warnings.log "${prefix}/${prefix}.warnings.log"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gtdbtk: \$(gtdbtk --version 2>&1 | grep -Eo '[0-9]+(\\.[0-9]+)+' | head -1)
    END_VERSIONS


    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir ${prefix}
    mkdir ${prefix}/identify
    mkdir ${prefix}/classify
    mkdir ${prefix}/align

    touch ${prefix}/classify/${prefix}.ar53.summary.tsv
    touch ${prefix}/classify/${prefix}.bac120.summary.tsv
    touch ${prefix}/classify/${prefix}.ar53.classify.tree
    touch ${prefix}/classify/${prefix}.bac120.classify.tree

    touch ${prefix}/identify/${prefix}.ar53.markers_summary.tsv
    touch ${prefix}/identify/${prefix}.bac120.markers_summary.tsv

    echo "" | gzip > ${prefix}/align/${prefix}.ar53.msa.fasta.gz
    echo "" | gzip > ${prefix}/align/${prefix}.bac120.user_msa.fasta.gz
    touch ${prefix}/align/${prefix}.ar53.filtered.tsv
    touch ${prefix}/align/${prefix}.bac120.filtered.tsv

    touch ${prefix}/${prefix}.log
    touch ${prefix}/${prefix}.warnings.log
    touch ${prefix}/${prefix}.failed_genomes.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gtdbtk: \$(gtdbtk --version 2>&1 | grep -Eo '[0-9]+(\\.[0-9]+)+' | head -1)
    END_VERSIONS

    """
}
