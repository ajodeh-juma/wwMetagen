#!/bin/bash


baseDir="${HOME}/projects/ww-Kenya"
workDir="${baseDir}/results"

results_dirs=(
  "20231201_NextSeq_wwP2Run01"
  "20240119_NextSeq_wwP2Run02"
  "20240202_NextSeq_wwP2Run04"
  "20240215_NextSeq_wwP2Run05"
  "20240219_NextSeq_wwP2Run06"
  "20240221_NextSeq_wwP2Run07"
  "20240228_NextSeq_wwP2Run08" 
  "20240308_NextSeq_wwP2Run09" 
  "20240322_NextSeq_wwP2Run10" 
  "20240424_NextSeq_wwP2Run11" 
  "20240429_NextSeq_wwP2Run12"
  "20241011_NextSeq_wwP2Run15"
  "20241018_NextSeq_wwP2Run16"
  "20250120_NextSeq_wwP2Run19"
  "20250131_NextSeq_wwP2Run20"
  "20250221_NextSeq_wwP2Run21"
  "20250305_NextSeq_wwP2Run22"
  "20250319_NextSeq_wwP2Run23"
  "20250402_NextSeq_wwP2Run24"
  "20250403_NextSeq_wwP2Run25"
  "20250404_NextSeq_wwP2Run27"
  "20240802_NextSeq2k_wwP2Run13"
  "20240911_NextSeq2k_wwP2Run14"
  "20241119_NextSeq2k_wwP2Run17"
  "20250110_NextSeq2K_wwP2Run18"
  "20250404_NextSeq2K_wwP2Run26"
  "20250410_NextSeq2K_wwP2Run28"
  "20250417_NextSeq2K_wwP2run29"
  "20250425_NextSeq2K_wwP2run30"
  "20250530_NextSeq2K_wwP2run31"
  "20250605_NextSeq2K_wwP2run32"
  "20250626_NextSeq2k_wwP2run34"
  "20250828_NextSeq2k_wwP2run36"
  "20251023_NextSeq2K_wwP2run40"
  "20251215_NextSeq2K_wwP2run41"
  "20251220_NextSeq2K_wwP2run42"
  "20260225_wwP2run43_NextSeq2k"
)


for d in ${results_dirs[@]};
do
  dir=${workDir}/${d}
  ls -v ${dir}/alignment/pathogens/*.coverage.txt | while IFS= read -r coverage; do
  sample_id=$(basename $coverage ".coverage.txt")
  outDir=$(dirname $(dirname $(dirname ${coverage})))
  outDir=${outDir}/metrics

  
  python ${baseDir}/pipelines/wwmetagen/bin/pathogen_metrics.py \
    --input_file ${coverage} \
    --pathogen_tsv ${baseDir}/pipelines/wwmetagen/assets/priority_pathogens.tsv \
    --sample_id ${sample_id} \
    --output ${outDir}/${sample_id}_metrics.csv

  done
done



# python pipelines/wwmetagen/bin/aggregate_coverage.py --input_files results/*/metrics/*_metrics.csv --metadata metadata/Wastewater-Metadata-Master-Sheet-2026-02-05.csv --output pipelines/wwmetagen/master_pathogen_metrics.tsv 