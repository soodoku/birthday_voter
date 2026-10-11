source("scripts/00_config.R")
for (module in c("calendar.R", "analysis.R", "paper.R")) {
  source(project_file("R", module))
}
for (path in c(table_dir, figure_dir)) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
}
for (stage in c("02_estimate.R", "03_figures.R", "04_tables.R")) {
  sys.source(project_file("scripts", stage), envir = new.env(parent = globalenv()))
}
