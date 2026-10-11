project_root <- rprojroot::find_root(rprojroot::has_file("DESCRIPTION"))
project_file <- function(...) file.path(project_root, ...)
# Voter files are large and restricted, so they live outside the repository.
source_root <- Sys.getenv("BIRTHDAY_VOTER_SOURCE", "/Volumes/Staging/birthday_voter")
raw_dir <- file.path(source_root, "raw")
work_dir <- file.path(source_root, "work")
duckdb_memory_limit <- Sys.getenv("BIRTHDAY_VOTER_DUCKDB_MEMORY", "6GB")
cells_dir <- Sys.getenv("BIRTHDAY_VOTER_CELLS", project_file("data", "cells"))
table_dir <- project_file("tabs")
figure_dir <- project_file("figs")
sources_file <- project_file("docs", "sources.csv")

dataverse_server <- "https://dataverse.harvard.edu"
dataverse_token_file <- file.path(Sys.getenv("HOME"), ".config", "dataverse", "token")

# Registration closes 29 days before an election in Florida (s. 97.055, Fla. Stat.) and 30 in Ohio (R.C. 3503.01).
registration_deadline_days <- c(FL = 29L, OH = 30L, PA = 30L)

# Cell files that enter the analysis, by state.
analysis_cells <- list(FL = c("fl_2017", "fl_2022"), OH = "oh_2016", PA = "pa_2024")
state_labels <- c(FL = "Florida", OH = "Ohio", PA = "Pennsylvania", Pooled = "All three")
event_window <- 30L
placebo_days <- 8:30
# Florida 2006-2016 is where the pattern was first seen; the rest test it.
discovery_cells <- "fl_2017"

read_tab <- function(name) readr::read_csv(file.path(table_dir, name), show_col_types = FALSE)

figure_sizes <- list(turnout = c(width = 6.5, height = 5), methods = c(width = 7.5, height = 6.4))
figure_dpi <- 180
reference_colour <- "grey60"
estimate_colour <- "grey25"
birthday_colour <- "#B2182B"
table_style <- list(font_size = "normalsize", column_padding = "6pt", row_stretch = 1)
theme_paper <- function() {
  ggplot2::theme_minimal(base_size = 11, base_family = "sans") +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold", hjust = 0),
      plot.title.position = "plot"
    )
}
