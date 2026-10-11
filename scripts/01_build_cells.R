# Usage: Rscript scripts/01_build_cells.R FL 2017
# The only stage that reads the restricted voter files. Each election is
# taken from the earliest extract filed after it, so a person who appears in
# two extracts contributes each election once.
source("scripts/00_config.R")
source(project_file("R", "cells_fl.R"))
source(project_file("R", "cells_oh.R"))
source(project_file("R", "cells_pa.R"))
args <- commandArgs(trailingOnly = TRUE)
state <- args[1]
extract <- args[2]

extracts <- utils::read.csv(project_file("docs", "extracts.csv"), colClasses = "character")
extracts <- extracts[extracts$state == state, ]
extracts <- extracts[order(extracts$extract_date), ]
i <- match(extract, extracts$extract)
after <- if (i > 1L) as.Date(extracts$extract_date[i - 1L]) else as.Date("1900-01-01")
elections <- utils::read.csv(project_file("docs", "elections.csv"), colClasses = "character")
elections <- elections[elections$state == state, ]
elections$election_date <- as.Date(elections$election_date)
elections <- elections[elections$election_date > after & elections$election_date < as.Date(extracts$extract_date[i]), ]

dir.create(work_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(cells_dir, recursive = TRUE, showWarnings = FALSE)
con <- DBI::dbConnect(duckdb::duckdb(), file.path(work_dir, paste0(tolower(state), "_", extract, ".duckdb")))
# Bound memory and spill to the source drive, so the build does not depend on how much RAM is free.
DBI::dbExecute(con, sprintf("SET memory_limit = '%s'", duckdb_memory_limit))
DBI::dbExecute(con, sprintf("SET temp_directory = '%s'", file.path(work_dir, "duckdb_tmp")))
DBI::dbExecute(con, "SET preserve_insertion_order = false")


deadline <- registration_deadline_days[state]
cells <- switch(state,
  FL = build_fl_cells(extract, elections[c("election_date", "election_type")], deadline, con),
  OH = build_oh_cells(extract, deadline, con),
  PA = build_pa_cells(extract, con)
)
stem <- file.path(cells_dir, paste0(tolower(state), "_", extract))
readr::write_csv(cells, paste0(stem, ".csv.gz"))
diagnostics <- switch(state,
  FL = fl_diagnostics(con),
  OH = oh_diagnostics(con),
  PA = pa_diagnostics(con)
)
for (name in names(diagnostics)) readr::write_csv(diagnostics[[name]], paste0(stem, "_", name, ".csv"))
message("cells: ", nrow(cells), " rows, ", sum(cells$n), " person-elections")

# The cells are the analysis files; the extracted text and database can be rebuilt from the archives.
DBI::dbDisconnect(con, shutdown = TRUE)
db_file <- file.path(work_dir, paste0(tolower(state), "_", extract, ".duckdb"))
unlink(c(file.path(work_dir, tolower(state), extract), db_file), recursive = TRUE)
