elections <- readr::read_csv(project_file("docs", "elections.csv"), show_col_types = FALSE)
read_cells <- \(file) readr::read_csv(file.path(cells_dir, paste0(file, ".csv.gz")), show_col_types = FALSE)
analytic <- purrr::imap(analysis_cells, \(files, state) {
  purrr::map(files, \(f) dplyr::mutate(read_cells(f), cell_file = f)) |>
    dplyr::bind_rows() |>
    as.data.frame() |>
    prepare_cells(as.data.frame(elections), state)
}) |>
  dplyr::bind_rows()

# Description of each state's data.
registrants <- purrr::map_dbl(rlang::set_names(unlist(analysis_cells)), \(f) {
  detail <- readr::read_csv(file.path(cells_dir, paste0(f, "_detail.csv")), show_col_types = FALSE)
  detail$rows - detail$missing_dob
})
recorded <- \(d) paste(purrr::keep(setdiff(names(outcomes), "voted"), \(y) measured(d, y)), collapse = ", ")
data_summary <- analytic |>
  dplyr::summarise(
    first_year = min(election_year), last_year = max(election_year),
    elections = dplyr::n_distinct(election), generals = dplyr::n_distinct(election[election_type == "GEN"]),
    person_elections = sum(n), birthday_n = sum(n[days == 0L]), turnout = sum(voted) / sum(n),
    methods = recorded(dplyr::pick(dplyr::everything())), .by = state
  ) |>
  dplyr::mutate(registrants = purrr::map_dbl(state, \(s) max(registrants[analysis_cells[[s]]])))
readr::write_csv(data_summary, file.path(table_dir, "data.csv"))

official <- readr::read_csv(project_file("docs", "official_turnout.csv"), show_col_types = FALSE)
analytic |>
  dplyr::summarise(
    treated_n = sum(n[days == 0L]), voted = sum(voted), n = sum(n),
    .by = c(state, election_date, election_type)
  ) |>
  dplyr::mutate(year = as.integer(format(election_date, "%Y"))) |>
  dplyr::left_join(official |> dplyr::select(state, year, election_type, turnout_pct),
    by = c("state", "year", "election_type")
  ) |>
  dplyr::arrange(state, election_date) |>
  readr::write_csv(file.path(table_dir, "elections.csv"))

# Main estimates: each state and all three together, for every outcome a state records.
scopes <- c(split(analytic, analytic$state), list(Pooled = analytic))
runs <- tidyr::expand_grid(scope = names(scopes), outcome = names(outcomes)) |>
  dplyr::filter(purrr::map2_lgl(scope, outcome, \(s, y) measured(scopes[[s]], y)))
estimates <- purrr::map2(runs$scope, runs$outcome, \(s, y) {
  fit <- fit_event(scopes[[s]], y, event_window)
  on.exit(gc(verbose = FALSE))
  list(
    days = dplyr::mutate(event_days(fit, scopes[[s]], y), scope = s, .before = 1),
    summary = dplyr::mutate(summarise_event(fit, scopes[[s]], y), scope = s, .before = 1)
  )
})
readr::write_csv(purrr::list_rbind(purrr::map(estimates, "days")), file.path(table_dir, "event.csv"))
readr::write_csv(purrr::list_rbind(purrr::map(estimates, "summary")), file.path(table_dir, "summary.csv"))
rm(scopes, estimates)

# Robustness of the turnout estimates for all three states together.
# Each check is a sample and a clustering; samples are built one at a time to bound memory.
checks <- list(
  main = list(\(d) d, ~birth_md),
  cluster_md_state = list(\(d) d, ~md_state),
  cluster_twoway = list(\(d) d, ~ birth_md + election),
  discovery = list(\(d) dplyr::filter(d, cell_file == discovery_cells), ~birth_md),
  replication = list(\(d) dplyr::filter(d, cell_file != discovery_cells), ~birth_md),
  general = list(\(d) dplyr::filter(d, election_type == "GEN"), ~birth_md),
  primary = list(\(d) dplyr::filter(d, election_type != "GEN"), ~birth_md),
  oh_pa_all = list(\(d) dplyr::filter(d, !is.na(settled)), ~birth_md),
  oh_pa_settled = list(\(d) dplyr::filter(d, !is.na(settled), settled), ~birth_md)
)
purrr::imap(checks, \(spec, label) {
  data <- spec[[1]](analytic)
  on.exit(gc(verbose = FALSE))
  fit <- fit_event(data, "voted", event_window, spec[[2]])
  dplyr::mutate(summarise_event(fit, data, "voted"), check = label, .before = 1)
}) |>
  purrr::list_rbind() |>
  readr::write_csv(file.path(table_dir, "robustness.csv"))
