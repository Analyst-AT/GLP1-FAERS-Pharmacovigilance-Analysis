# ============================================================
# GLP-1 FAERS Project 2025
#Author: Asmita Thapa
# Pipeline: Import -> Filter GLP-1 (PS) -> Merge -> Tables -> Export
# ============================================================

# 0) Clear environment
rm(list = ls())
gc()

# 1) Packages
if (!requireNamespace("data.table", quietly = TRUE)) install.packages("data.table")
if (!requireNamespace("stringr", quietly = TRUE)) install.packages("stringr")
library(data.table)
library(stringr)


# 2) Setting working directory

setwd("C:/Users/User/Desktop/PROJECTS/GLP-1_FAERS_Project/FAERS 2025 txt file")

# 3) Helper: read FAERS ASCII files (delimiter is $)
read_faers <- function(filename) {
  fread(
    filename,
    sep = "$",
    quote = "",
    header = TRUE,
    fill = TRUE,
    showProgress = TRUE,
    encoding = "Latin-1"
  )
}

# 4) Load 2025 data (Q1–Q4)
message("Loading DEMO (2025)...")
DEMO <- rbindlist(list(
  read_faers("DEMO25Q1.txt"),
  read_faers("DEMO25Q2.txt"),
  read_faers("DEMO25Q3.txt"),
  read_faers("DEMO25Q4.txt")
), use.names = TRUE, fill = TRUE)

message("Loading DRUG (2025)...")
DRUG <- rbindlist(list(
  read_faers("DRUG25Q1.txt"),
  read_faers("DRUG25Q2.txt"),
  read_faers("DRUG25Q3.txt"),
  read_faers("DRUG25Q4.txt")
), use.names = TRUE, fill = TRUE)

message("Loading OUTC (2025)...")
OUTC <- rbindlist(list(
  read_faers("OUTC25Q1.txt"),
  read_faers("OUTC25Q2.txt"),
  read_faers("OUTC25Q3.txt"),
  read_faers("OUTC25Q4.txt")
), use.names = TRUE, fill = TRUE)

message("Loading REAC (2025)...")
REAC <- rbindlist(list(
  read_faers("REAC25Q1.txt"),
  read_faers("REAC25Q2.txt"),
  read_faers("REAC25Q3.txt"),
  read_faers("REAC25Q4.txt")
), use.names = TRUE, fill = TRUE)

# 5) Standardize column names to uppercase (easier merges)
setnames(DEMO, names(DEMO), toupper(names(DEMO)))
setnames(DRUG, names(DRUG), toupper(names(DRUG)))
setnames(OUTC, names(OUTC), toupper(names(OUTC)))
setnames(REAC, names(REAC), toupper(names(REAC)))

# 6) Keep only needed columns (safe if some columns differ across quarters)
DEMO_keep <- intersect(c("PRIMARYID","CASEID","CASEVERSION","FDA_DT","EVENT_DT","AGE","AGE_COD","SEX","GNDR_COD","REPORTER_COUNTRY","OCCR_COUNTRY"), names(DEMO))
DEMO <- DEMO[, ..DEMO_keep]

DRUG_keep <- intersect(c("PRIMARYID","DRUGNAME","ROLE_COD"), names(DRUG))
DRUG <- DRUG[, ..DRUG_keep]

OUTC_keep <- intersect(c("PRIMARYID","OUTC_COD"), names(OUTC))
OUTC <- OUTC[, ..OUTC_keep]

REAC_keep <- intersect(c("PRIMARYID","PT"), names(REAC))
REAC <- REAC[, ..REAC_keep]

# Harmonize sex column if needed (some quarters use GNDR_COD)
if (!"SEX" %in% names(DEMO) && "GNDR_COD" %in% names(DEMO)) {
  DEMO[, SEX := GNDR_COD]
}

# 7) Deduplicate DEMO by CASEID keeping latest CASEVERSION (common FAERS step)
if (all(c("CASEID","CASEVERSION") %in% names(DEMO))) {
  DEMO[, CASEVERSION := as.integer(CASEVERSION)]
  setorder(DEMO, CASEID, -CASEVERSION)
  DEMO <- DEMO[!duplicated(CASEID)]
}

# 8) Define GLP-1 patterns (generic + brands)
glp1_patterns <- c(
  "SEMAGLUTIDE", "OZEMPIC", "WEGOVY", "RYBELSUS",
  "LIRAGLUTIDE", "VICTOZA", "SAXENDA", "XULTOPHY",
  "DULAGLUTIDE", "TRULICITY",
  "EXENATIDE", "BYETTA", "BYDUREON",
  "LIXISENATIDE", "ADLYXIN", "SOLIQUA", "LYXUMIA",
  "TIRZEPATIDE", "MOUNJARO", "ZEPBOUND"
)

DRUG[, DRUGNAME := toupper(trimws(DRUGNAME))]
pat <- paste(glp1_patterns, collapse = "|")

# 9) Filter GLP-1 drug rows + keep Primary Suspect only
GLP1 <- DRUG[str_detect(DRUGNAME, pat)]
GLP1_PS <- GLP1[ROLE_COD == "PS"]

# 10) Merge GLP-1 PS with DEMO (demographics)
GLP1_DEMO <- merge(GLP1_PS, DEMO, by = "PRIMARYID", all.x = TRUE)

# 11) Merge with OUTC (outcomes) and REAC (reactions)
# Note: allow cartesian because one report can have multiple outcomes/reactions
GLP1_OUTC <- merge(GLP1_DEMO, OUTC, by = "PRIMARYID", all.x = TRUE, allow.cartesian = TRUE)
GLP1_FULL <- merge(GLP1_OUTC, REAC, by = "PRIMARYID", all.x = TRUE, allow.cartesian = TRUE)

# 12) Create a serious outcome flag + readable outcome label
serious_map <- data.table(
  OUTC_COD = c("DE","LT","HO","DS","CA","RI","OT"),
  OUTCOME  = c("Death","Life-threatening","Hospitalization","Disability","Congenital anomaly","Required intervention","Other serious outcome")
)
GLP1_FULL <- merge(GLP1_FULL, serious_map, by = "OUTC_COD", all.x = TRUE)

GLP1_FULL[, SERIOUS_FLAG := fifelse(!is.na(OUTC_COD), 1L, 0L)]

# 13) Quick counts
cat("\n===== SANITY CHECKS =====\n")
cat("DEMO rows:", nrow(DEMO), "\n")
cat("DRUG rows:", nrow(DRUG), "\n")
cat("GLP-1 rows:", nrow(GLP1), "\n")
cat("GLP-1 PS rows:", nrow(GLP1_PS), "\n")
cat("Unique GLP-1 PS reports (PRIMARYID):", uniqueN(GLP1_PS$PRIMARYID), "\n")
cat("Merged FULL rows (with reactions/outcomes):", nrow(GLP1_FULL), "\n")

# ============================================================
# OUTPUT TABLES (Excel-ready)
# ============================================================

# RQ1: Serious outcome distribution among GLP-1 PS reports
# Count unique PRIMARYID per outcome (avoid double counting due to multiple reactions)
rq1 <- unique(GLP1_FULL[!is.na(OUTCOME), .(PRIMARYID, OUTCOME)])
rq1_table <- rq1[, .N, by = OUTCOME][order(-N)]
setnames(rq1_table, "N", "Reports")

# RQ2: Most common reactions among serious reports (top 25)
rq2 <- unique(GLP1_FULL[SERIOUS_FLAG == 1 & !is.na(PT), .(PRIMARYID, PT)])
rq2_table <- rq2[, .N, by = PT][order(-N)][1:25]
setnames(rq2_table, "N", "Reports")

# RQ3: Serious outcomes by GLP-1 drug (unique reports)
drug_clean <- function(x) {
  # simple grouping for readability
  fifelse(str_detect(x, "SEMAGLUTIDE|OZEMPIC|WEGOVY|RYBELSUS"), "Semaglutide",
          fifelse(str_detect(x, "TIRZEPATIDE|MOUNJARO|ZEPBOUND"), "Tirzepatide",
                  fifelse(str_detect(x, "LIRAGLUTIDE|VICTOZA|SAXENDA|XULTOPHY"), "Liraglutide",
                          fifelse(str_detect(x, "DULAGLUTIDE|TRULICITY"), "Dulaglutide",
                                  fifelse(str_detect(x, "EXENATIDE|BYETTA|BYDUREON"), "Exenatide",
                                          fifelse(str_detect(x, "LIXISENATIDE|ADLYXIN|SOLIQUA|LYXUMIA"), "Lixisenatide", "Other"))))))
}

GLP1_FULL[, DRUG_GROUP := drug_clean(DRUGNAME)]

rq3 <- unique(GLP1_FULL[!is.na(OUTCOME), .(PRIMARYID, DRUG_GROUP, OUTCOME)])
rq3_table <- rq3[, .N, by = .(DRUG_GROUP, OUTCOME)][order(DRUG_GROUP, -N)]
setnames(rq3_table, "N", "Reports")

# Optional: Demographics summary (for dashboard)
demo_summary <- unique(GLP1_FULL[, .(PRIMARYID, DRUG_GROUP, SEX, AGE, AGE_COD)])
demo_summary <- demo_summary[, .(
  Reports = .N,
  Age_Median = suppressWarnings(median(as.numeric(AGE), na.rm = TRUE))
), by = .(DRUG_GROUP, SEX)][order(DRUG_GROUP)]

# 14) Save outputs
dir.create("outputs", showWarnings = FALSE)

write.csv(rq1_table, "outputs/RQ1_serious_outcome_distribution_2025.csv", row.names = FALSE)
write.csv(rq2_table, "outputs/RQ2_top25_reactions_among_serious_2025.csv", row.names = FALSE)
write.csv(rq3_table, "outputs/RQ3_serious_outcomes_by_drug_2025.csv", row.names = FALSE)
write.csv(demo_summary, "outputs/Demographics_summary_by_drug_sex_2025.csv", row.names = FALSE)

# Save final merged dataset (so you don’t re-run imports every time)
saveRDS(GLP1_FULL, "outputs/GLP1_FAERS_2025_FULL.rds")

cat("\nSaved files in /outputs:\n")
cat("- RQ1_serious_outcome_distribution_2025.csv\n")
cat("- RQ2_top25_reactions_among_serious_2025.csv\n")
cat("- RQ3_serious_outcomes_by_drug_2025.csv\n")
cat("- Demographics_summary_by_drug_sex_2025.csv\n")
cat("- GLP1_FAERS_2025_FULL.rds\n")


# Figures 
# Figure 1: Serious outcome distribution


dir.create("figures")

png("figures/figure1_drug_distribution.png",
    width = 2400,
    height = 1600,
    res = 300)

library(ggplot2)

ggplot(rq1_table, aes(x = reorder(OUTCOME, Reports), y = Reports)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  coord_flip() +
  labs(
    title = "Serious Adverse Outcomes Reported for GLP-1 Drugs (FAERS 2025)",
    x = "Outcome Type",
    y = "Number of Reports"
  ) +
  theme_minimal()


dev.off()


# Figure 2: Serious outcomes by GLP-1 drug


png("figures/figure2_serious_outcomes.png",
    width = 2400,
    height = 1600,
    res = 300)



library(ggplot2)

ggplot(rq3_table, aes(x = DRUG_GROUP, y = Reports, fill = OUTCOME)) +
  geom_bar(stat = "identity") +
  labs(
    title = "Distribution of Serious Outcomes by GLP-1 Drug (FAERS 2025)",
    x = "GLP-1 Drug",
    y = "Number of Reports",
    fill = "Outcome Type"
  ) +
  theme_minimal()

dev.off()


# Figure 3: Top 25 adverse reactions among serious reports

png("figures/figure3_top25_adverse_reactions.png",
    width = 3000,
    height = 2200,
    res = 300)

ggplot(top_reactions, aes(x = reorder(PT, N), y = N)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  coord_flip() +
  labs(
    title = "Top 25 Adverse Reactions Among Serious GLP-1 Reports\n(FAERS 2025)",
    x = "Number of Reports",
    y = "Preferred Term (PT)"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 20, face = "bold", hjust = 0.5),
    axis.text.y = element_text(size = 11),
    axis.text.x = element_text(size = 11),
    axis.title = element_text(size = 14),
    plot.margin = margin(30, 30, 30, 30)
  )

dev.off()

ls()

# For Excel Dashboard

install.packages("openxlsx")
library(openxlsx)
wb <- createWorkbook()

addWorksheet(wb, "RQ1_Summary")
writeData(wb, "RQ1_Summary", rq1_table)

addWorksheet(wb, "RQ2_Summary")
writeData(wb, "RQ2_Summary", rq2_table)

addWorksheet(wb, "RQ3_Summary")
writeData(wb, "RQ3_Summary", rq3_table)

saveWorkbook(wb, "GLP1_FAERS_Results.xlsx", overwrite = TRUE)

getwd()


#top adverse event 
names(GLP1_FULL)

top_reactions <- GLP1_FULL[, .N, by = PT][order(-N)][1:20]
outcome_distribution <- GLP1_FULL[, .N, by = OUTCOME][order(-N)]
outcome_distribution
drug_distribution <- GLP1_FULL[, .N, by = DRUGNAME][order(-N)]
drug_distribution
serious_distribution <- GLP1_FULL[, .N, by = SERIOUS_FLAG][order(-N)]
serious_distribution
addWorksheet(wb, "Top_Reactions")
writeData(wb, "Top_Reactions", top_reactions)

addWorksheet(wb, "Outcome_Distribution")
writeData(wb, "Outcome_Distribution", outcome_distribution)

addWorksheet(wb, "Drug_Distribution")
writeData(wb, "Drug_Distribution", drug_distribution)

addWorksheet(wb, "Serious_Distribution")
writeData(wb, "Serious_Distribution", serious_distribution)

saveWorkbook(wb, "GLP1_FAERS_Results.xlsx", overwrite = TRUE)




# Additional Figures 


png("figures/figure4_Top20_adverse_events.png",
    width = 2400,
    height = 1600,
    res = 300)


library(ggplot2)

ggplot(top_reactions, aes(x = reorder(PT, N), y = N)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  coord_flip() +
  labs(
    title = "Top 20 Adverse Events Associated with GLP-1 Drugs (FAERS 2025)",
    x = "Adverse Event",
    y = "Number of Reports"
  ) +
  theme_minimal()

dev.off()




png("figures/figure4_most reported.png",
    width = 2000,
    height = 1200,
    res = 300)

ggplot(drug_distribution[1:10], aes(x = reorder(DRUGNAME, N), y = N)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  coord_flip() +
  labs(
    title = "Most Reported GLP-1 Drugs in FAERS 2025",
    x = "Drug",
    y = "Number of Reports"
  ) +
  theme_minimal()

dev.off()






png("figures/figure5_outcome_associated.png",
    width = 2000,
    height = 1200,
    res = 300)
ggplot(outcome_distribution[!is.na(OUTCOME)], aes(x = reorder(OUTCOME, N), y = N)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  coord_flip() +
  labs(
    title = "Serious Outcomes Associated with GLP-1 Adverse Events",
    x = "Outcome Type",
    y = "Number of Reports"
  ) +
  theme_minimal()

dev.off()



#proportion figure


install.packages("dplyr")
library(dplyr)

outcome_prop <- GLP1_FULL %>%
  filter(!is.na(OUTCOME)) %>%
  group_by(DRUG_GROUP, OUTCOME) %>%
  summarise(N = n(), .groups = "drop") %>%
  group_by(DRUG_GROUP) %>%
  mutate(percent = N / sum(N) * 100)


png("figures/figure1_drug_distribution.png",
    width = 2000,
    height = 1200,
    res = 300)
ggplot(outcome_prop, aes(x = DRUG_GROUP, y = percent, fill = OUTCOME)) +
  geom_bar(stat = "identity") +
  labs(
    title = "Proportion of Serious Outcomes by GLP-1 Drug (FAERS 2025)",
    x = "GLP-1 Drug",
    y = "Percentage of Reports"
  ) +
  theme_minimal()
dev.off()














