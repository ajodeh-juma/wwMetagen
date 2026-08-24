#!/bin/bash

#SBATCH -w compute06
#SBATCH --partition=batch,highmem
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
# PROJ_DIR="${HOME}/projects/ww-Kenya/pipelines/wwmetagen"          # user directory
PROJ_DIR="/export/data/ilri/sarscov2/projects/pipelines/wwmetagen"  # genomics team directory
SCRATCH_DIR="/var/scratch/${USER}"
GENPATH_DEST="${HOME}/projects/GenPath_Africa/wwmetagen/results"

export NXF_OPTS="-Xms512M -Xmx4G"
export SINGULARITY_CACHEDIR="/export/data/ilri/sarscov2/projects/pipelines/wwmetagen/singularity/"

# Load Slurm Environment Modules
module load nextflow/25.04

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

nextseq_2k_runs=(
  "20260515_wwP2run45_NextSeq2k" # 90 UNEP=26, GenPath=64
)


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
      machine_type="2K"
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
for platform in "nextseq_550"; do

  # Select the active run array for the current platform
  case "${platform}" in
    # "miseq_i100")  runs=("${miseq_i100_runs[@]}") ;;
    # "miseq")       runs=("${miseq_runs[@]}") ;;
    "nextseq_550") runs=("${nextseq_550_runs[@]}") ;;
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
    workdir="${SCRATCH_DIR}/wwmetagen/work"

    nextflow run "${PROJ_DIR}/main.nf" \
      -c "${PROJ_DIR}/conf/slurm.config" \
      -profile singularity \
      --input "${input_manifest}" \
      --skip_qc true \
      --analysis_type alignment \
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

# #!/bin/bash

# #SBATCH -w compute06
# #SBATCH --partition=batch,highmem
# #SBATCH --output=logs/output_%j.txt
# #SBATCH --error=logs/error_output_%j.txt
# #SBATCH --job-name=ww-pathogen-tracking
# #SBATCH --mail-type=BEGIN,END,FAIL
# #SBATCH --mail-user=J.Juma@cgiar.org

# # TESTING
# hostname

# # # project directory
# PROJ_DIR="${HOME}/projects/ww-Kenya/pipelines/wwmetagen"

# ##########################################################################
# #####                                                                #####
# ####                Prepare raw data for the pipeline                #####
# ####                                                                 #####
# ##########################################################################

# miseq_i100_runs=(
#   "20250630_MiSeqi100_wwP2Run35" # 1
# )

# for d in ${miseq_i100_runs[@]};
# do
#   if [ $(basename ${d}) != '20220218_NextSeq_10_meta00_seq35_MT' ]; then
#     DIR=$(basename ${d})

#     DATADIR=$(find /export/data/ilri/miseq/users/Sam/wwater/${d} -name 'fastq' -type d | tail -n 1 )

#     # generate samplesheet
#     if [ ! -f "/var/scratch/${USER}/${DIR}/metadata/${DIR}.csv" ]; then
#       echo -e "$DIR: /var/scratch/${USER}/${DIR}/metadata/${DIR}.csv"
#       python ${PROJ_DIR}/bin/generate_csv_manifest.py \
#         --data-dir ${DATADIR} \
#         --prefix ${DIR} \
#         --machine miseq \
#         --out-dir /var/scratch/${USER}/${DIR}/metadata
      
#     fi
#   fi
# done

# miseq_runs=(
#   "20240202_MiSeq_wwP2Run03" # 2
#   "20251009_MiSeq_wwP2run37" # 1
#   "20251015_MiSeq_wwP2run38" # 1
#   "20251020_MiSeq_wwP2run39" # 1
# )

# for d in ${miseq_runs[@]};
# do
#   if [ $(basename ${d}) != '20220218_NextSeq_10_meta00_seq35_MT' ]; then
#     DIR=$(basename ${d})

#     DATADIR=$(find /export/data/ilri/miseq/users/Sam/wwater/${d} -name 'Fastq' -type d -path "*/*/Alignment*/*" | tail -n 1)

#     # generate samplesheet
#     if [ ! -f "/var/scratch/${USER}/${DIR}/metadata/${DIR}.csv" ]; then
#       echo -e "$DIR: /var/scratch/${USER}/${DIR}/metadata/${DIR}.csv"
#       python ${PROJ_DIR}/bin/generate_csv_manifest.py \
#         --data-dir ${DATADIR} \
#         --prefix ${DIR} \
#         --machine miseq \
#         --out-dir /var/scratch/${USER}/${DIR}/metadata
      
#     fi
#   fi
# done


# nextseq_550_runs=(
#   "20231201_NextSeq_wwP2Run01" # 20
#   "20240119_NextSeq_wwP2Run02" # 20
#   "20240202_NextSeq_wwP2Run04" # 20
#   "20240215_NextSeq_wwP2Run05" # 20
#   "20240219_NextSeq_wwP2Run06" # 20
#   "20240221_NextSeq_wwP2Run07" # 20
#   "20240228_NextSeq_wwP2Run08" # 20
#   "20240308_NextSeq_wwP2Run09" # 20
#   "20240322_NextSeq_wwP2Run10" # 20
#   "20240424_NextSeq_wwP2Run11" # 20
#   "20240429_NextSeq_wwP2Run12" # 20
#   "20241011_NextSeq_wwP2Run15" # 6
#   "20241018_NextSeq_wwP2Run16" # 6
#   "20250120_NextSeq_wwP2Run19" # 6
#   "20250131_NextSeq_wwP2Run20" # 6
#   "20250221_NextSeq_wwP2Run21" # 6
#   "20250305_NextSeq_wwP2Run22" # 6
#   "20250319_NextSeq_wwP2Run23" # 6
#   "20250402_NextSeq_wwP2Run24" # 6
#   "20250403_NextSeq_wwP2Run25" # 6
#   "20250404_NextSeq_wwP2Run27" # 6
# )


# for d in ${nextseq_550_runs[@]};
# do
#   if [ $(basename ${d}) != '20220218_NextSeq_10_meta00_seq35_MT' ]; then
#     DIR=$(basename ${d})

#     DATADIR=$(find /export/data/ilri/nextseq/wwater/${d} -name 'Fastq' -type d -path "/*Fastq" | tail -n 1)
#     # DATADIR=$(find /export/data/ilri/nextseq/wwater/${d} -name 'Fastq' -type d -path "*/*/Alignment*/*" | tail -n 1)
#     # DATADIR=$(find "/export/data/ilri/nextseq/wwater/${d}/" -name 'Fastq' -type d | tail -n 1 )

#     # generate samplesheet
#     if [ ! -f "/var/scratch/${USER}/${DIR}/metadata/${DIR}.csv" ]; then
#       echo -e "$DIR: /var/scratch/${USER}/${DIR}/metadata/${DIR}.csv"
#       python ${PROJ_DIR}/bin/generate_csv_manifest.py \
#         --data-dir ${DATADIR} \
#         --prefix ${DIR} \
#         --machine 2K \
#         --out-dir /var/scratch/${USER}/${DIR}/metadata
      
#     fi
#   fi
# done


# nextseq_2k_runs=(
#   "20240802_NextSeq2k_wwP2Run13" # 20
#   "20240911_NextSeq2k_wwP2Run14" # 90
#   "20241119_NextSeq2k_wwP2Run17" # 25
#   "20250110_NextSeq2K_wwP2Run18" # 90
#   "20250404_NextSeq2K_wwP2Run26" # 90
#   "20250410_NextSeq2K_wwP2Run28" # 90
#   "20250417_NextSeq2K_wwP2run29" # 90
#   "20250425_NextSeq2K_wwP2run30" # 90
#   "20250530_NextSeq2K_wwP2run31" # 90
#   "20250605_NextSeq2K_wwP2run32" # 20
#   "20250626_NextSeq2k_wwP2run34" # 60
#   "20250828_NextSeq2k_wwP2run36" # 90
#   "20251023_NextSeq2K_wwP2run40" # 90
#   "20251215_NextSeq2K_wwP2run41" # 80
#   "20251220_NextSeq2K_wwP2run42" # 90
#   "20260225_wwP2run43_NextSeq2k" # 90
#   "20260401_wwP2run44_NextSeq2k" # 90
# )

# nextseq_2k_runs=(
#   "20260515_wwP2run45_NextSeq2k" # 90 UNEP=26, GenPath=64
# )

# for d in ${nextseq_2k_runs[@]};
# do
#   if [ $(basename ${d}) != '20220218_NextSeq_10_meta00_seq35_MT' ]; then
#     DIR=$(basename ${d})

#     # OUTDIR="/var/scratch/global/${USER}/${DIR}/data"
#     DATADIR=$(find "/export/data/ilri/nextseq/wwater/${d}/" -name 'fastq' -type d | tail -n 1 )
    
#     if [ ! -f "/var/scratch/${USER}/${DIR}/metadata/${DIR}.csv" ]; then
#       echo -e "$DIR: /var/scratch/${USER}/${DIR}/metadata/${DIR}.csv"
#       python ${PROJ_DIR}/bin/generate_csv_manifest.py \
#         --data-dir ${DATADIR} \
#         --prefix ${DIR} \
#         --machine 2K \
#         --out-dir /var/scratch/${USER}/${DIR}/metadata
#     fi
#   fi
# done

# # # clean environment
# # module purge

# # load module(s)
# module load nextflow/25.04

# export NXF_OPTS='-Xms512M -Xmx4G'
# export SINGULARITY_CACHEDIR="/export/data/ilri/sarscov2/projects/pipelines/wastewatermetagenomics/singularity/"


# # set input/output directory
# SCRATCH_DIR=/var/scratch/$USER
# TAXID=28901
# GENUS="Salmonella"
# SPECIES="enterica"


# if [ ! -d "${SCRATCH_DIR}" ]; then
#  mkdir -p "${SCRATCH_DIR}"
# fi

# for dir in ${miseq_i100_runs[@]};
# for dir in ${miseq_runs[@]};
# for dir in ${nextseq_550_runs[@]};
# for dir in ${nextseq_2k_runs[@]};


# do
# echo -e "Start date:\t $(date)"
# runid=$(basename $dir)
# input=/var/scratch/global/${USER}/${runid}/metadata/${runid}.csv

# # input=/var/scratch/${USER}/${runid}/metadata/${runid}.csv
# awk 'NR==1 || /^SPL/' /var/scratch/${USER}/${runid}/metadata/${runid}.csv > /var/scratch/${USER}/${runid}/metadata/${runid}_genpath.csv

# outdir=/var/scratch/${USER}/wwmetagen/results/${runid}
# workdir=/var/scratch/${USER}/wwmetagen/work

# echo -e "\n runid: $runid \n input: $input \n outdir: $outdir \n workdir: $workdir \n"

# nextflow run ${PROJ_DIR}/main.nf \
#   -c ${PROJ_DIR}/conf/slurm.config \
#   -profile singularity \
#   --input /var/scratch/${USER}/${runid}/metadata/${runid}_genpath.csv \
#   --skip_qc true \
#   --analysis_type alignment \
#   --confidence 0.1 \
#   --target_pathogen_taxid ${TAXID} \
#   --centre ILRI \
#   --genus ${GENUS} \
#   --species ${SPECIES} \
#   --assembly_source 'refseq' \
#   --n_genomes 1 \
#   --min_contig_length 300 \
#   --outdir ${outdir} \
#   -work-dir ${workdir} \
#   -ansi-log true \
#   -resume

# echo -e "End date:\t $(date)"


# ######################################################################

# DEST_DIR="${HOME}/projects/GenPath_Africa/wwmetagen/results/${runid}"

# if [ -d ${DEST_DIR} ];then
#   echo -e "Destination directory: ${DEST_DIR} exists, it will be deleted"
#   rm -r ${DEST_DIR}
# fi


# mkdir -p ${DEST_DIR}

# rsync -avP -q --partial ${outdir} \
#   --exclude="work" \
#   --exclude="pathogens" \
#   --exclude="*.report.txt" \
#   --exclude="*.mpa" \
#   --exclude="fastqc" \
#   --exclude="hostile" \
#   --exclude="multiqc" \
#   --exclude="*.json" \
#   --exclude="pipeline_info" \
#   --exclude="*.mmi" \
#   --exclude="references" \
#   --exclude="*.html" \
#   --exclude="*.log" \
#   --exclude="*.zip" \
#   --exclude="*.bam" \
#   --exclude="*.bai" \
#   --exclude="*.png" \
#   --exclude="reports" \
#   --exclude="lofreq" \
#   --exclude="*.vcf" \
#   --exclude="amrfinderplus" \
#   --exclude="bcftools" \
#   --exclude="db*" \
#   --exclude="ncbi" \
#   ${HOME}/projects/GenPath_Africa/wwmetagen/results/

# done

# # clean up all runs
# # nextflow log -q | while read -r run; do nextflow clean -f "$run"; done
# # find ${workdir} \( -iname "*fastq*" -o -iname "*bam*" \) 