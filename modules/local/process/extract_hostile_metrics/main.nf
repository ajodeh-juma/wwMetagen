// Extract hostile metrics
process EXTRACT_HOSTILE_METRICS {
    tag "${meta.id}"
    label 'process_single'

    input:
    tuple val(meta), path(hostile_json)

    output:
    tuple val(meta), path("*_hostile_metrics.tsv"), emit: tsv

    script:
    def prefix     = task.ext.prefix ?: "${meta.id}"

    """
    python3 <<CODE
    import json
    import os

    with open('${hostile_json}', 'r') as f:
        data = json.load(f)
    
    # Hostile outputs a list of dictionaries; we take the first one
    stats = data[0]
    
    metrics = {
        'sample_name': '${prefix}',
        'reads_in': stats.get('reads_in', 0),
        'reads_out': stats.get('reads_out', 0),
        'reads_removed': stats.get('reads_removed', 0),
        'reads_removed_proportion': stats.get('reads_removed_proportion', 0)
    }

    with open('${prefix}_hostile_metrics.tsv', 'w') as out:
        out.write("\\t".join(metrics.keys()) + "\\n")
        out.write("\\t".join(map(str, metrics.values())) + "\\n")
    CODE
    """
}
