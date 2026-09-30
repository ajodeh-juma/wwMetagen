#!/bin/bash

#SBATCH -w compute07
#SBATCH --partition=highmem
#SBATCH --output=logs/%u_output_%j.txt
#SBATCH --error=logs/%u_error_output_%j.txt
#SBATCH --job-name=ww-pathogen-tracking
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=J.Juma@cgiar.org

# Print compute environment metadata
echo "================================================="
echo "Node Hostname : $(hostname)"
echo "Start Time    : $(date)"
echo "================================================="

#-------------------------------------------------------------------------------
# Environment Setup & Paths
#-------------------------------------------------------------------------------
PROJ_DIR="${HOME}/projects/ww-Kenya/pipelines/wwmetagen"          # user directory
# PROJ_DIR="/export/data/ilri/sarscov2/projects/pipelines/wwmetagen"  # genomics team directory
SCRATCH_DIR="/var/scratch/${USER}"
GENPATH_DEST="${HOME}/projects/GenPath_Africa/wwmetagen/results"

export NXF_OPTS="-Xms512M -Xmx4G"
export SINGULARITY_CACHEDIR="${PROJ_DIR}/singularity/"

# Load Slurm Environment Modules
module load nextflow/25.04

# analysis type
ANALYSIS_TYPE="taxonomy"

# Target Pathogen Configuration
TAXID=1773
GENUS="Mycobacterium"
SPECIES="tuberculosis"


#-------------------------------------------------------------------------------
# Define Platform Run Arrays
#-------------------------------------------------------------------------------
miseq_i100_runs=(
  "20250630_MiSeqi100_wwP2Run35" # 1
)

miseq_runs=(
  "20240202_MiSeq_wwP2Run03" # 2
  "20251009_MiSeq_wwP2run37" # 1
  "20251015_MiSeq_wwP2run38" # 1
  "20251020_MiSeq_wwP2run39" # 1
)


nextseq_550_runs=(
  "20231201_NextSeq_wwP2Run01" # 20
  "20240119_NextSeq_wwP2Run02" # 20
  "20240202_NextSeq_wwP2Run04" # 20
  "20240215_NextSeq_wwP2Run05" # 20
  "20240219_NextSeq_wwP2Run06" # 20
  "20240221_NextSeq_wwP2Run07" # 20
  "20240228_NextSeq_wwP2Run08" # 20
  "20240308_NextSeq_wwP2Run09" # 20
  "20240322_NextSeq_wwP2Run10" # 20
  "20240424_NextSeq_wwP2Run11" # 20
  "20240429_NextSeq_wwP2Run12" # 20
  "20241011_NextSeq_wwP2Run15" # 6
  "20241018_NextSeq_wwP2Run16" # 6
  "20250120_NextSeq_wwP2Run19" # 6
  "20250131_NextSeq_wwP2Run20" # 6
  "20250221_NextSeq_wwP2Run21" # 6
  "20250305_NextSeq_wwP2Run22" # 6
  "20250319_NextSeq_wwP2Run23" # 6
  "20250402_NextSeq_wwP2Run24" # 6
  "20250403_NextSeq_wwP2Run25" # 6
  "20250404_NextSeq_wwP2Run27" # 6
)

nextseq_2k_runs=(
  "20240802_NextSeq2k_wwP2Run13" # 20
  "20240911_NextSeq2k_wwP2Run14" # 90
  "20241119_NextSeq2k_wwP2Run17" # 25
  "20250110_NextSeq2K_wwP2Run18" # 90
  "20250404_NextSeq2K_wwP2Run26" # 90
  "20250410_NextSeq2K_wwP2Run28" # 90
  "20250417_NextSeq2K_wwP2run29" # 90
  "20250425_NextSeq2K_wwP2run30" # 90
  "20250530_NextSeq2K_wwP2run31" # 90
  "20250605_NextSeq2K_wwP2run32" # 20
  "20250626_NextSeq2k_wwP2run34" # 60
  "20250828_NextSeq2k_wwP2run36" # 90
  "20251023_NextSeq2K_wwP2run40" # 90
  "20251215_NextSeq2K_wwP2run41" # 80
  "20251220_NextSeq2K_wwP2run42" # 90
  "20260225_wwP2run43_NextSeq2k" # 90
  "20260401_wwP2run44_NextSeq2k" # 90
)

# nextseq_2k_runs=(
#   "20260515_wwP2run45_NextSeq2k" # 90 UNEP=26, GenPath=64
# )

#-------------------------------------------------------------------------------
# Helper Functions
#-------------------------------------------------------------------------------

get_run_info() {
  local run_id="$1"
  local platform="$2"
  local machine_type=""
  local datadir=""

  case "${platform}" in
    "miseq_i100")
      machine_type="miseq"
      datadir=$(find "/export/data/ilri/miseq/users/Sam/wwater/${run_id}" -name 'fastq' -type d | tail -n 1)
      ;;
    "miseq")
      machine_type="miseq"
      datadir=$(find "/export/data/ilri/miseq/users/Sam/wwater/${run_id}" -name 'Fastq' -type d -path "*/*/Alignment*/*" | tail -n 1)
      ;;
    "nextseq_550")
      machine_type="550"
      datadir=$(find "/export/data/ilri/nextseq/wwater/${run_id}" -name 'Fastq' -type d -path "/*Fastq" | tail -n 1)
      ;;
    "nextseq_2k")
      machine_type="2K"
      datadir=$(find "/export/data/ilri/nextseq/wwater/${run_id}/" -name 'fastq' -type d | tail -n 1)
      ;;
    *)
      echo "[ERROR] Unknown platform type: ${platform}" >&2
      return 1
      ;;
  esac

  echo "${machine_type}|${datadir}"
}


# for platform in "miseq_i100" "miseq" "nextseq_550" "nextseq_2k"; do
for platform in "miseq"; do

  # Select the active run array for the current platform
  case "${platform}" in
    # "miseq_i100")  runs=("${miseq_i100_runs[@]}") ;;
    "miseq")       runs=("${miseq_runs[@]}") ;;
    # "nextseq_550") runs=("${nextseq_550_runs[@]}") ;;
    # "nextseq_2k")  runs=("${nextseq_2k_runs[@]}") ;;
  esac

  for run_id in "${runs[@]}"; do
    # Skip control/excluded runs
    if [[ "${run_id}" == "20220218_NextSeq_10_meta00_seq35_MT" ]]; then
      continue
    fi

    echo "================================================="
    echo " Platform       : ${platform}"
    echo " Processing Run : ${run_id}"
    echo " Start Date     : $(date)"
    echo "================================================="

    # Resolve platform-specific parameters and FASTQ directory
    run_info=$(get_run_info "${run_id}" "${platform}")
    machine_type=$(echo "${run_info}" | cut -d'|' -f1)
    datadir=$(echo "${run_info}" | cut -d'|' -f2)

    if [[ -z "${datadir}" ]]; then
      echo "[WARNING] FASTQ directory not found for ${run_id} under ${platform}. Skipping..." >&2
      continue
    fi

    # Step 1: Generate manifest if missing
    manifest_dir="${SCRATCH_DIR}/${run_id}/metadata"
    raw_manifest="${manifest_dir}/${run_id}.csv"
    genpath_manifest="${manifest_dir}/${run_id}_genpath.csv"

    if [[ ! -f "${raw_manifest}" ]]; then
      echo "[INFO] Generating manifest for ${run_id} (${platform} / Machine: ${machine_type})..."
      mkdir -p "${manifest_dir}"
      python "${PROJ_DIR}/bin/generate_csv_manifest.py" \
        --data-dir "${datadir}" \
        --prefix "${run_id}" \
        --machine "${machine_type}" \
        --out-dir "${manifest_dir}"
    fi

    # Step 2: Determine Nextflow input manifest (Subset ONLY for run45)
    if [[ "${run_id}" =~ "run45" ]]; then
      echo "[INFO] Run45 detected: Subsetting manifest for GenPath samples ('SPL' pattern)..."
      genpath_manifest="${manifest_dir}/${run_id}_genpath.csv"
      awk 'NR==1 || /^SPL/' "${raw_manifest}" > "${genpath_manifest}"
      input_manifest="${genpath_manifest}"
    else
      echo "[INFO] Using full raw manifest for ${run_id}..."
      input_manifest="${raw_manifest}"
    fi

    # Step 3: Run Nextflow pipeline
    outdir="${SCRATCH_DIR}/wwmetagen/results/${run_id}"
    workdir="${SCRATCH_DIR}/wwmetagen/work/${run_id}"

    nextflow run "${PROJ_DIR}/main.nf" \
      -c "${PROJ_DIR}/conf/slurm.config" \
      -profile singularity \
      --input "${input_manifest}" \
      --skip_qc true \
      --analysis_type ${ANALYSIS_TYPE} \
      --confidence 0.1 \
      --target_pathogen_taxid "${TAXID}" \
      --centre ILRI \
      --genus "${GENUS}" \
      --species "${SPECIES}" \
      --assembly_source 'refseq' \
      --n_genomes 1 \
      --min_contig_length 300 \
      --outdir "${outdir}" \
      -work-dir "${workdir}" \
      -ansi-log true \
      -resume

    # Step 4: Sync curated outputs to GenPath directory
    dest_run_dir="${GENPATH_DEST}/${run_id}"
    [[ -d "${dest_run_dir}" ]] && rm -rf "${dest_run_dir}"
    mkdir -p "${GENPATH_DEST}"

    echo "[INFO] Syncing outputs to ${dest_run_dir}..."
    rsync -avP -q --partial "${outdir}" \
      --exclude="work" \
      --exclude="pathogens" \
      --exclude="*.report.txt" \
      --exclude="*.mpa" \
      --exclude="fastqc" \
      --exclude="hostile" \
      --exclude="multiqc" \
      --exclude="*.json" \
      --exclude="pipeline_info" \
      --exclude="*.mmi" \
      --exclude="references" \
      --exclude="*.html" \
      --exclude="*.log" \
      --exclude="*.zip" \
      --exclude="*.bam" \
      --exclude="*.bai" \
      --exclude="*.png" \
      --exclude="reports" \
      --exclude="lofreq" \
      --exclude="*.vcf" \
      --exclude="amrfinderplus" \
      --exclude="bcftools" \
      --exclude="db*" \
      --exclude="ncbi" \
      "${GENPATH_DEST}/"

    echo "================================================="
    echo " Completed Run : ${run_id}"
    echo " End Date      : $(date)"
    echo "================================================="
  done
done

# per-task timing for kraken2
grep -E '(^task_id|KRAKEN2_KRAKEN2)' "${outdir}/pipeline_info/execution_trace_"*.txt | column -t -s$'\t'