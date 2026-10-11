# Usage: Rscript scripts/00_fetch.R FL 2017
source("scripts/00_config.R")
source(project_file("R", "fetch.R"))
args <- commandArgs(trailingOnly = TRUE)
fetch_extract(args[1], args[2])
