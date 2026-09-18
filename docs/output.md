# wwMetagen: Output

## Introduction

This document describes the output produced by the pipeline. Most of the QC plots are taken from the MultiQC report, which summarises results at the end of the pipeline.

The directories listed below are created under `--outdir` after the pipeline has finished. All paths are relative to the top-level results directory. Several output paths are namespaced by `${params.analysis_type}` (`alignment`, `taxonomy` or `assembly`) and, for the `alignment`/diversity steps, by `${params.target_pathogen_taxid}`.

## Pipeline overview

The pipeline processes data using the following steps, run for every sample:

- [Preprocessing](#preprocessing) — read QC, adapter/quality trimming and host-read removal
- One of three analysis modes:
  - [Reference-targeted alignment](#reference-targeted-alignment-analysis_type-alignment) (`--analysis_type alignment`)
  - [Taxonomic profiling](#taxonomic-profiling-analysis_type-taxonomy) (`--analysis_type taxonomy`)
  - [De novo assembly](#de-novo-assembly-analysis_type-assembly) (`--analysis_type assembly`)
- [MultiQC](#multiqc) — aggregate QC report
- [Pipeline information](#pipeline-information) — execution reports and software versions

### Preprocessing

<details markdown="1">
<summary>Output files</summary>

- `preprocessing/fastqc/`
  - `*_fastqc.html`, `*_fastqc.zip`: raw-read [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/) reports.
- `preprocessing/fastp/`
  - `*.fastp.json`, `*.fastp.html`: [fastp](https://github.com/OpenGene/fastp) trimming/QC reports.
  - `*_summary.tsv`: per-sample QC metrics extracted from the fastp report.
- `preprocessing/hostile/reference/`
  - the [Hostile](https://github.com/bede/hostile) human reference index (skipped if `--hostile_db` is supplied).
- `preprocessing/hostile/dehosted/`
  - `*.fastq.gz`: reads with host (human) sequence removed.
  - `*_hostile_metrics.tsv`: per-sample read-removal metrics.
- `preprocessing/summary/`
  - `fastp_summary.tsv`, `hostile_dehosting_summary.tsv`: fastp/Hostile metrics merged across all samples.

</details>

FastQC and fastp give general quality metrics and trimming statistics for the raw reads. Hostile removes reads that map to a human reference so that only microbial reads continue into the analysis modes below.

### Reference-targeted alignment (`--analysis_type alignment`)

<details markdown="1">
<summary>Output files</summary>

- `alignment/ncbi/taxonomy/`: downloaded NCBI taxonomy dump.
- `alignment/<taxid>/references/`: pathogen/indicator reference genome(s) and metadata resolved from NCBI for the target taxonomy ID.
- `alignment/<taxid>/minimap2/`: reads aligned to the pathogen reference set (`minimap2`/`samtools`) and per-pathogen coverage.
- `metrics/`: per-sample pathogen detection metrics (coverage/breadth vs. pathogen reference).
- `diversity/<taxid>/references/`: indexed target reference used for variant calling.
- `diversity/<taxid>/minimap2/`: reads aligned to the target reference.
- `diversity/<taxid>/lofreq/variants/`, `.../filtered-variants/`: raw and filtered [LoFreq](https://csb5.github.io/lofreq/) VCFs.
- `diversity/<taxid>/metrics/`: nucleotide (pi) and Shannon diversity TSVs.
- `alignment/<taxid>/bcftools/`: normalized/filtered VCF, low-coverage mask and consensus genome FASTA.
- `alignment/<taxid>/bakta/`: [Bakta](https://github.com/oschwengers/bakta) annotation of the consensus genome.
- `alignment/<taxid>/abricate/`, `alignment/<taxid>/amrfinder/`: AMR/virulence gene screening of the consensus genome ([ABRicate](https://github.com/tseemann/abricate), [AMRFinderPlus](https://github.com/ncbi/amr)).
- `reports/`: the wastewater surveillance summary report and plots (pathogen positivity vs. PMMoV threshold).

</details>

### Taxonomic profiling (`--analysis_type taxonomy`)

<details markdown="1">
<summary>Output files</summary>

- `taxonomy/kraken2/`: [Kraken2](https://github.com/DerrickWood/kraken2) classification reports and per-domain read metrics.
- `taxonomy/bracken/`: [Bracken](https://github.com/jenniferlu717/Bracken) abundance re-estimates and per-domain read metrics.
- `taxonomy/krakenuniq/`: [KrakenUniq](https://github.com/fbreitwieser/krakenuniq) classification reports.
- `taxonomy/summary/`: merged MetaPhlAn-style (MPA) abundance tables and reads-per-million normalized tables, per classifier.

</details>

### De novo assembly (`--analysis_type assembly`)

<details markdown="1">
<summary>Output files</summary>

- `assembly/megahit/`: assembled contigs ([MEGAHIT](https://github.com/voutcn/megahit)).
- `assembly/quast/`: assembly quality metrics ([MetaQUAST](http://quast.sourceforge.net)).
- `assembly/alignment/`, `assembly/coverm/`: reads aligned back to contigs and per-contig coverage.
- `assembly/metabat2/`, `assembly/maxbin2/`, `assembly/concoct/`: genome bins from each binning tool.
- `assembly/dastool/`: consolidated, non-redundant bin set ([DAS Tool](https://github.com/cmks/DAS_Tool)).
- `assembly/checkm/`: bin completeness/contamination ([CheckM2](https://github.com/chklovski/CheckM2)).
- `assembly/gtdbtk/`: taxonomic classification of bins ([GTDB-Tk](https://github.com/Ecogenomics/GTDBTk)).
- `assembly/genomad/`, `assembly/checkv/`: plasmid/virus identification ([geNomad](https://github.com/apcamargo/genomad)) and quality assessment ([CheckV](https://bitbucket.org/berkeleylab/checkv)).
- `assembly/abricate/`, `assembly/amrfinder/`: AMR/virulence gene screening of contigs and bins.

</details>

### MultiQC

<details markdown="1">
<summary>Output files</summary>

- `multiqc/`
  - `multiqc_report.html`: a standalone HTML file that can be viewed in your web browser.
  - `multiqc_data/`: directory containing parsed statistics from the different tools used in the pipeline.
  - `multiqc_plots/`: directory containing static images from the report in various formats.

</details>

[MultiQC](http://multiqc.info) generates a single HTML report summarising QC across all samples (FastQC, fastp, and per-process software versions).

### Pipeline information

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.dot`/`pipeline_dag.svg`.
  - Reports generated by the pipeline: `pipeline_report.html`, `pipeline_report.txt` and `software_versions.yml`. The `pipeline_report*` files are only produced if `--email`/`--email_on_fail` are used.
  - Reformatted samplesheet used as input: `samplesheet.valid.csv`.
  - Parameters used for the run: `params.json`.

</details>

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) provides reports relevant to the running and execution of the pipeline, useful for troubleshooting errors and reviewing launch commands, run times and resource usage.
