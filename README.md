# GLP-1 Pharmacovigilance Analysis Using FDA FAERS Data

## Overview

This project investigates **serious adverse events associated with GLP-1 receptor agonists** using the **FDA Adverse Event Reporting System (FAERS)** database.

GLP-1 receptor agonists such as **semaglutide, tirzepatide, and dulaglutide** are widely used for the treatment of **type 2 diabetes and obesity**. With the rapid expansion in their use, understanding their real-world safety profile has become increasingly important.

Using FAERS data from 2025, this project examines patterns of serious adverse outcomes and commonly reported adverse reactions associated with GLP-1 medications.

## Dataset

**Source:** FDA Adverse Event Reporting System (FAERS)

FAERS is a spontaneous reporting database used by the FDA for post-marketing pharmacovigilance and drug safety monitoring.

Reports are submitted by:

- Healthcare professionals
- Pharmaceutical manufacturers
- Patients and consumers

Because FAERS contains millions of adverse event reports, it is widely used in drug safety research and epidemiologic studies.

## Data Summary

| Metric | Value |
|--------|-------|
| Total FAERS reports analyzed | 250,449 |
| Serious adverse event reports | 124,062 |
| Non-serious reports | 126,387 |
| Most reported GLP-1 drug | Mounjaro |
| Second most reported drug | Ozempic |
| Most common adverse reaction | Incorrect dose administered |
| Second most common reaction | Nausea |
| Most common serious outcome | Other serious outcome |
| Second most common serious outcome | Hospitalization |

These values summarize aggregated adverse event reports involving GLP-1 receptor agonists in the FAERS dataset.

## Methods

The analysis was conducted using **R**.

Main steps included:

- Importing and cleaning FAERS datasets
- Filtering reports involving **GLP-1 receptor agonists**
- Removing duplicate case reports
- Aggregating adverse events using preferred terms (PT)
- Summarizing serious outcomes
- Visualizing patterns using **ggplot2**

## Data Visualizations

### Most Reported GLP-1 Drugs in FAERS

![Most Reported Drugs](figures/figure4_most_reported.png)

### Serious Adverse Outcome Distribution

![Serious Outcomes](figures/figure1_serious_outcomes.png)

### Serious Outcomes Associated with GLP-1 Reports

![Outcome Associated](figures/figure5_outcome_associated.png)

### Distribution of Serious Outcomes by Drug

![Outcomes by Drug](figures/figure2_serious_outcomes_by_drug.png)

### Top 25 Adverse Reactions

![Top Reactions](figures/figure3_top25_adverse_reactions.png)

### Top 20 Adverse Events

![Top Events](figures/figure6_top20_adverse_events.png)

### Percentage Distribution of Serious Outcomes by Drug

![Outcome Percentage](figures/figure7_outcome_percentage_by_drug.png)

## Repository Structure

```text
GLP1-FAERS-Pharmacovigilance-Analysis

README.md
GLP1_FAERS_Pharmacovigilance_Report.pdf
glp1_faers_analysis.R
GLP1_FAERS_tables.xlsx

figures/
   figure1_serious_outcomes.png
   figure2_serious_outcomes_by_drug.png
   figure3_top25_adverse_reactions.png
   figure4_most_reported.png
   figure5_outcome_associated.png
   figure6_top20_adverse_events.png
   figure7_outcome_percentage_by_drug.png


Limitations

FAERS is a spontaneous reporting system and has several limitations:

Underreporting of adverse events

Reporting bias

Lack of denominator data

Inability to establish causal relationships

Therefore, these results reflect reporting patterns rather than incidence rates.

Author

Asmita Thapa
Master of Public Health (MPH)
Epidemiology & Biostatistics

Project Purpose

This project demonstrates:

Pharmacovigilance analysis using FAERS data

Epidemiologic analysis of large health datasets

Data visualization in R

Reproducible research workflows
