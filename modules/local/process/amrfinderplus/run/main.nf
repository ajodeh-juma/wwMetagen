process AMRFINDERPLUS_RUN {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ncbi-amrfinderplus:4.2.7--hf69ffd2_0':
        'biocontainers/ncbi-amrfinderplus:4.2.7--hf69ffd2_0' }"

    input:
    tuple val(meta), path(fasta)
    path db
    val organisms

    output:
    tuple val(meta), path("${prefix}.tsv")          , emit: report
    tuple val(meta), path("${prefix}-mutations.tsv"), emit: mutation_report, optional: true
    env 'VER'                                       , emit: tool_version
    env 'DBVER'                                     , emit: db_version
    path("versions.yml")                            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args           = task.ext.args   ?: ''
    def type_label     = meta.type ? "_${meta.type}" : ""
    prefix             = task.ext.prefix ?: "${meta.id}${type_label}"

    // 1. Parse allowed AMRFinderPlus organisms list (trims whitespace and handles empty inputs)
    def allowed_orgs   = organisms ? organisms.toString().tokenize(',').collect { it.trim() } : []

    // 2. Extract genus, species, and metadata (checking meta first, then falling back to params)
    def g              = (meta.genus ?: params.genus ?: "").toString().trim().capitalize()
    def s              = (meta.species ?: params.species ?: "").toString().trim().toLowerCase()
    def meta_org       = (meta.organism ?: "").toString().trim()

    // 3. Construct candidate search list in order of specificity
    def candidates = []
    if (meta_org)  candidates << meta_org
    if (g && s)    candidates << "${g}_${s}"   // e.g., Acinetobacter_baumannii
    if (g)         candidates << g              // e.g., Salmonella

    // 4. Find the first candidate that exists in the allowed amrfinder_organisms list
    def match_org = candidates.find { cand ->
        allowed_orgs.any { allowed -> 
            allowed.equalsIgnoreCase(cand) || allowed.replaceAll('_', ' ').equalsIgnoreCase(cand.replaceAll('_', ' '))
        }
    }

    // 5. Build parameter flag using the exact casing required by AMRFinderPlus
    def final_org      = match_org ? allowed_orgs.find { it.equalsIgnoreCase(match_org) } : null
    def organism_param = final_org ? "--organism ${final_org}" : ""

    // Determine if input is protein or nucleotide
    def fasta_param    = meta.is_proteins ? "-p" : "-n"

    """
    # Set database directory
    if [[ "${db}" == *.tar.gz ]] || [[ "${db}" == *.tgz ]]; then
        mkdir -p amr_db
        tar -xzf ${db} -C amr_db --strip-components=1
        DB_PATH="amr_db"
    else
        DB_PATH="${db}"
    fi

    # Identify if input target is directory or single file
    [ -d "${fasta}" ] && TARGETS=${fasta}/* || TARGETS="${fasta}"

    FIRST=true
    for fasta in \$TARGETS; do
        fasta_id=\$(basename "\$fasta")
        
        # 1. Standard AMRFinderPlus Run
        amrfinder \\
            ${fasta_param} "\$fasta" \\
            ${organism_param} \\
            --database \$DB_PATH \\
            --threads ${task.cpus} \\
            ${args} > "tmp_\${fasta_id}.tsv"

        # 2. Specialized Mutation Run (Only executed if an organism flag was successfully resolved)
        if [ -n "${organism_param}" ]; then
            amrfinder \\
                ${fasta_param} "\$fasta" \\
                ${organism_param} \\
                --mutation_all "tmp_\${fasta_id}_mut.tsv" \\
                --database \$DB_PATH \\
                --threads ${task.cpus} \\
                ${args} > /dev/null
        fi

        # 3. Merge headers and multi-contig results
        if [ "\$FIRST" = true ]; then
            head -n 1 "tmp_\${fasta_id}.tsv" | sed 's/\$/\\tsource_file/' > ${prefix}.tsv
            [ -f "tmp_\${fasta_id}_mut.tsv" ] && head -n 1 "tmp_\${fasta_id}_mut.tsv" | sed 's/\$/\\tsource_file/' > ${prefix}-mutations.tsv
            FIRST=false
        fi
        
        tail -n +2 "tmp_\${fasta_id}.tsv" | awk -v f="\$fasta_id" '{print \$0 "\\t" f}' >> ${prefix}.tsv
        if [ -f "tmp_\${fasta_id}_mut.tsv" ]; then
             tail -n +2 "tmp_\${fasta_id}_mut.tsv" | awk -v f="\$fasta_id" '{print \$0 "\\t" f}' >> ${prefix}-mutations.tsv
        fi
    done

    VER=\$(amrfinder --version)
    DBVER=\$(amrfinder --database \$DB_PATH --database_version 2>&1 | tail -n 1)

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        amrfinder: \$VER
        amrfinder_db: \$DBVER
    END_VERSIONS
    """

    stub:
    def type_label = meta.type ? "_${meta.type}" : ""
    prefix         = task.ext.prefix ?: "${meta.id}${type_label}"

    """
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        amrfinder: \$('amrfinder --version')
        amrfinderdb: \$(amrfinder --database \$DB_PATH --database_version 2>&1 | tail -n 1)
    END_VERSIONS
    """
}
