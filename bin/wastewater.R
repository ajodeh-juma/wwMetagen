#!/usr/bin/env Rscript

# Load required libraries
suppressPackageStartupMessages({
  library(argparse)
  library(tidyverse)
  library(viridis)
  library(zoo)
})

# 1. ARGUMENT PARSING (using argparse)
parser <- ArgumentParser(description='Wastewater Pathogen Surveillance Visualization and QC')

parser$add_argument("-i", "--input",  nargs="+", type="character", default=NULL,
    help="Path to the individual _metrics.csv files [default %(default)s]")

parser$add_argument("-t", "--threshold", type="double", default=100.0,
    help="PMMoV CPM threshold for Sample Status PASS/FAIL [default %(default)s]")

parser$add_argument("-o", "--outdir", type="character", default=".",
    help="Output directory for plots and reports [default %(default)s]")

args <- parser$parse_args()

# 2. DATA LOADING
files <- unique(unlist(strsplit(args$input," ")))
if (length(files) == 0) {
  parser$print_help()
  stop("At least one input file must be supplied", call.=FALSE)
}
if (!all(file.exists(files))) {
  parser$print_help()
  stop(paste("The following input files don't exist:", 
             paste(input_files[!file.exists(files)], 
                   sep='', collapse=' '), sep=' '), call.=FALSE)
}

df <- map_df(files, read_csv, show_col_types = FALSE)

# 3. HIERARCHICAL NORMALIZATION & STATUS VALIDATION

marker_names <- c("PMMoV", "CrAssphage", "Bacteroides_fragilis")

df_markers <- df %>%
  filter(Pathogen_Name %in% c("PMMoV", "CrAssphage", "Bacteroides_fragilis"))

df_wide <- df_markers %>%
  select(Sample_ID, Pathogen_Name, CPM) %>%
  pivot_wider(names_from = Pathogen_Name, values_from = CPM, values_fill = 0)

# Ensure all marker columns exist
for(marker in c("PMMoV", "CrAssphage", "Bacteroides_fragilis")) {
  if(!(marker %in% names(df_wide))) df_wide[[marker]] <- 0
}

df_status <- df_wide %>%
  mutate(
    Sample_Status = if_else(PMMoV >= args$threshold, "PASS", "FAIL (Low Biomass)"),
    norm_method = case_when(
      PMMoV > 0 ~ "PMMoV",
      CrAssphage > 0 ~ "CrAssphage",
      Bacteroides_fragilis > 0 ~ "Bacteroides",
      TRUE ~ "NONE"
    ),
    norm_factor = case_when(
      PMMoV > 0 ~ PMMoV,
      CrAssphage > 0 ~ CrAssphage,
      Bacteroides_fragilis > 0 ~ Bacteroides_fragilis,
      TRUE ~ NA_real_
    )
  )

# 4. MERGE AND COMPUTE TEMPORAL METRICS
df <- df %>%
  left_join(df_status %>% select(Sample_ID, Sample_Status, norm_method, norm_factor), by = "Sample_ID") %>%
  mutate(Ratio_Normalized = CPM / (norm_factor + 1e-9)) %>%
  arrange(Pathogen_Name, Sample_ID) %>%
  group_by(Pathogen_Name) %>%
  mutate(
    Ratio_Smooth = rollapply(Ratio_Normalized, width = 3, FUN = function(x) mean(x, na.rm = TRUE), fill = NA, align = "right"),
    mu = mean(Ratio_Smooth, na.rm = TRUE),
    sigma = sd(Ratio_Smooth, na.rm = TRUE),
    Z_Score = if_else(!is.na(sigma) & sigma > 0, (Ratio_Smooth - mu) / sigma, 0),
    Is_Spike = !is.na(Z_Score) & Z_Score > 2.0
  ) %>%
  ungroup()



# 6. QC PLOT
qc_plot <- df_markers %>%
  left_join(df_status %>% select(Sample_ID, Sample_Status), by = "Sample_ID") %>%
  ggplot(aes(x = Sample_ID, y = CPM, fill = Pathogen_Name)) +
  geom_bar(stat = "identity", position = "dodge", aes(alpha = Sample_Status)) +
  scale_y_log10(labels = scales::comma) +
  scale_alpha_manual(values = c("FAIL (Low Biomass)" = 0.3, "PASS" = 1.0)) +
  scale_fill_brewer(palette = "Set2") +
  theme_classic() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  labs(title = "Sample Quality Control: Fecal Markers",
       subtitle = paste("Threshold for PASS:", args$threshold, "CPM (PMMoV)"),
       y = "CPM (Log10 Scale)", x = "Sample ID")

ggsave(file.path(args$outdir, "Sample_QC_Status.png"), qc_plot, width = 10, height = 6)


# 7. PLOT: LONGITUDINAL HEATMAP
plot_pathogens <- df %>% filter(!Pathogen_Name %in% marker_names)

heatmap_plot <- ggplot(plot_pathogens, aes(x = Sample_ID, y = Pathogen_Name)) +
  geom_tile(aes(fill = log10(Ratio_Normalized + 1e-7)), color = "white") +
  scale_fill_viridis(name = "Log10 Ratio", option = "magma") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  labs(title = "Wastewater Pathogen Heatmap", x = "Sample ID", y = "Pathogen")

ggsave(file.path(args$outdir, "Pathogen_Heatmap.png"), heatmap_plot, width = 12, height = 8)

# 8. LOOP: TOP 5 TRENDLINE PLOTS
top_5_pathogens <- plot_pathogens %>%
  group_by(Pathogen_Name) %>%
  summarize(total_abundance = sum(CPM, na.rm = TRUE)) %>%
  top_n(5, total_abundance) %>%
  pull(Pathogen_Name)

for (target in top_5_pathogens) {
  trend_data <- df %>% filter(Pathogen_Name == target)
  clean_name <- gsub("[^[:alnum:]]", "_", target) # Sanitize filename
  
  p <- ggplot(trend_data, aes(x = Sample_ID, group = 1)) +
    geom_point(aes(y = Ratio_Normalized), color = "grey70", alpha = 0.5) +
    geom_line(aes(y = Ratio_Smooth, color = "3-Sample Moving Average"), size = 1.2) +
    geom_point(data = filter(trend_data, Is_Spike == TRUE), 
               aes(y = Ratio_Smooth, color = "Statistical Spike (Z > 2)"), size = 4) +
    scale_color_manual(values = c("3-Sample Moving Average" = "#2C3E50", "Statistical Spike (Z > 2)" = "#E74C3C")) +
    theme_classic() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1), legend.position = "bottom") +
    labs(title = paste("Trend Analysis:", target), y = "Normalized Ratio", x = "Sample ID")

  ggsave(file.path(args$outdir, paste0("Trend_", clean_name, ".png")), p, width = 10, height = 6)
}


# 9. PATHOGEN RANKING TABLE (Latest Sample)
latest_date <- max(df$Sample_ID)
pathogen_ranking <- df %>%
  filter(Sample_ID == latest_date, !Pathogen_Name %in% marker_names) %>%
  select(Pathogen_Name, Sample_ID, CPM, Breadth_Pct, Ratio_Normalized, Z_Score, Is_Spike) %>%
  arrange(desc(Z_Score))

# 10. GENERATE OUTPUTS

cat("Reporting complete. Heatmap, QC plot, and top 5 trends generated.\n")

# write_csv(df_status %>% select(Sample_ID, PMMoV, CrAssphage, Bacteroides_fragilis, Sample_Status, norm_method), 
#           file.path(args$outdir, "sample_status_summary.csv"))

write_csv(df, file.path(args$outdir, "master_pathogen_report.csv"))
write_csv(df_status, file.path(args$outdir, "sample_status_summary.csv"))
write_csv(pathogen_ranking, file.path(args$outdir, "pathogen_intensity_ranking.csv"))
