# wwMetagen

**A Nextflow pipeline for wastewater metagenomics and pathogen surveillance.**

wwMetagen processes short-read wastewater sequencing data end-to-end: read QC and host-read removal, then one of three configurable analysis modes — reference-targeted alignment/variant-calling, shotgun taxonomic profiling, or de novo metagenomic assembly/binning — followed by AMR/virulence screening, consensus genome generation and annotation, and diversity/abundance reporting.

The pipeline is built with [Nextflow](https://www.nextflow.io) DSL2, follows the [nf-core](https://nf-co.re) pipeline template and module conventions, and uses Docker/Singularity containers (via Conda/Wave) so results are reproducible across compute environments (local, HPC/Slurm, cloud).

> This repository is private. If you're reading this on GitHub, it's [ajodeh-juma/wwMetagen](https://github.com/ajodeh-juma/wwMetagen).

## Pipeline summary

1. **Read QC** — [`FastQC`](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/) and [`fastp`](https://github.com/OpenGene/fastp) (adapter/quality trimming; per-sample QC metrics extracted and merged)
2. **Host-read removal** — [`Hostile`](https://github.com/bede/hostile) dehosts reads against a human reference index; per-sample removal metrics extracted and merged
3. One of three **analysis modes**, selected with `--analysis_type`:

   - **`alignment`** (targeted, reference-based) — the most complete path:
     - Resolve and download target pathogen/indicator reference genomes from NCBI (`datasets` CLI / EDirect) for the given taxonomy ID(s)
     - Align dehosted reads to the pathogen reference set with `minimap2`/`samtools`, compute per-pathogen coverage/detection metrics
     - Call low-frequency variants (`LoFreq`), filter and reheader the VCF (`bcftools`), generate a consensus genome (`bcftools consensus` + masking of low-coverage regions)
     - Annotate the consensus genome (`Bakta`) and screen it for AMR/virulence genes (`AMRFinderPlus`, `ABRicate`)
     - Compute nucleotide/Shannon diversity from the called variants
     - Generate the wastewater surveillance summary report (pathogen positivity vs. PMMoV threshold)
   - **`taxonomy`** (shotgun taxonomic profiling):
     - Classify reads with `Kraken2` and `KrakenUniq`; re-estimate abundance with `Bracken`
     - Convert reports to MetaPhlAn-style (MPA) format (`KrakenTools`), merge per-sample tables and normalize to reads-per-million
   - **`assembly`** (de novo metagenomic assembly):
     - Assemble reads with `MEGAHIT`, assess assembly quality with `MetaQUAST`
     - Align reads back to contigs, bin contigs with `MetaBAT2`/`MaxBin2`/`CONCOCT` and refine the bin set with `DAS Tool`
     - Assess bin quality with `CheckM2`, classify bins taxonomically with `GTDB-Tk`, identify plasmids/viruses with `geNomad` and assess their quality with `CheckV`
     - Screen assemblies/bins for AMR/virulence genes (`AMRFinderPlus`, `ABRicate`)

4. **Reporting** — per-process software versions and a [`MultiQC`](http://multiqc.info) report aggregating QC across all samples

See [`docs/output.md`](docs/output.md) for a full description of output files per step.

## Usage

> [!NOTE]
> If you are new to Nextflow, please refer to [this page](https://www.nextflow.io/docs/latest/index.html) for an introduction, and [this page](https://nf-co.re/docs/usage/getting_started/installation) for how to set up Nextflow.

First, prepare a samplesheet with your input data (see [`docs/usage.md`](docs/usage.md) for the full specification):

```csv title="samplesheet.csv"
sample,fastq_1,fastq_2
SAMPLE_PAIRED_END,/path/to/AEG588A1_S1_L002_R1_001.fastq.gz,/path/to/AEG588A1_S1_L002_R2_001.fastq.gz
SAMPLE_SINGLE_END,/path/to/AEG588A4_S4_L003_R1_001.fastq.gz,
```

Then launch the pipeline, e.g. for the reference-targeted alignment mode:

```bash
nextflow run ajodeh-juma/wwMetagen \
   -profile <docker/singularity/conda/institute> \
   --input samplesheet.csv \
   --outdir <OUTDIR> \
   --analysis_type alignment \
   --target_pathogen_taxid <TAXID> \
   --hostile_db <PATH_TO_HOSTILE_INDEX>
```

> [!WARNING]
> Always specify a pipeline version with `-r` when running from the remote repository, and provide profile(s) appropriate to your compute environment (custom configs live under [`conf/`](conf)).

For the full list of parameters, see [`nextflow_schema.json`](nextflow_schema.json) or run:

```bash
nextflow run ajodeh-juma/wwMetagen --help
```

### Batch runs on the ILRI HPC

For processing many sequencing runs at once (e.g. on SLURM), [`runWWKenya.sh`](runWWKenya.sh) drives one pipeline execution per run and syncs curated results out. Cross-run summary tables (QC, pathogen coverage/abundance, diversity, AMR/virulence) are then built by a separate `aggregate.sh` script — see [Batch processing on the ILRI HPC](docs/usage.md#batch-processing-on-the-ilri-hpc) in the usage docs for how the two fit together.

## Pipeline output

For details of the output files and reports produced by the pipeline, see [`docs/output.md`](docs/output.md).

## Modules

Local, pipeline-specific processes live under [`modules/local/process/`](modules/local/process), one directory per tool/subcommand (`main.nf` + `meta.yml` + `environment.yml`, matching [nf-core module conventions](https://nf-co.re/docs/contributing/modules)), mirroring how the [`modules/nf-core/`](modules/nf-core) modules pulled from [nf-core/modules](https://github.com/nf-core/modules) are organised.

## Credits

wwMetagen was written by [John Juma](https://github.com/ajodeh-juma).

## Contributions and support

Issues and pull requests are welcome — please open one against this repository.

## Citations

An extensive list of references for the tools used by this pipeline can be found in [`CITATIONS.md`](CITATIONS.md).

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/master/LICENSE).

> Ewels PA, Peltzer A, Fillinger S, Patel H, Alneberg J, Wilm A, Garcia MU, Di Tommaso P, Nahnsen S. The nf-core framework for community-curated bioinformatics pipelines. Nat Biotechnol. 2020 Mar 20;38(3):276-278. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x)

## License

Released under the [MIT License](LICENSE).
