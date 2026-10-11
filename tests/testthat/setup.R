source(rprojroot::find_root(rprojroot::has_file("DESCRIPTION")) |> file.path("scripts", "00_config.R"))
for (module in c("calendar.R", "analysis.R", "paper.R")) source(project_file("R", module))
