z <- stats::qnorm(0.975)
data_summary <- read_tab("data.csv")
summary <- read_tab("summary.csv")
robustness <- read_tab("robustness.csv")
elections <- read_tab("elections.csv")
event <- read_tab("event.csv")

window_labels <- c(week_before = "Week before", day_before = "Day before", birthday = "Election Day")
widen <- function(data, ...) {
  data |>
    dplyr::filter(window %in% names(window_labels)) |>
    dplyr::mutate(value = with_se(estimate, std_error), window = factor(window, names(window_labels))) |>
    dplyr::select(..., window, value) |>
    tidyr::pivot_wider(names_from = window, values_from = value)
}
blank_repeats <- \(x) dplyr::if_else(x == dplyr::lag(x, default = ""), "", x)
method_names <- c(polls = "polls", early = "early", mail = "mail")

# Table 1: the data.
data_summary |>
  dplyr::transmute(
    State = state_labels[state],
    Elections = paste0(elections, " (", first_year, "--", last_year, ")"),
    Registrants = count(registrants), `Person-elections` = count(person_elections),
    `Election Day birthdays` = count(birthday_n), Turnout = pct(turnout),
    Method = dplyr::if_else(is.na(methods) | methods == "", "--", purrr::map_chr(strsplit(methods, ", "), \(m) {
      paste(method_names[m], collapse = ", ")
    }))
  ) |>
  write_table(file.path(table_dir, "data.tex"), "lrrrrrl", c(
    "State", "Elections", "Registrants", "Person-elections", "Birthday on E-Day", "Turnout", "Method recorded"
  ))

# Table 2: main estimates.
summary |>
  dplyr::mutate(
    scope = factor(scope, names(state_labels)), outcome = factor(outcome, names(outcomes))
  ) |>
  dplyr::arrange(scope, outcome) |>
  widen(scope, outcome) |>
  dplyr::transmute(
    State = blank_repeats(unname(state_labels[as.character(scope)])),
    Outcome = unname(outcomes[as.character(outcome)]),
    week_before, day_before, birthday
  ) |>
  write_table(
    file.path(table_dir, "main.tex"), "llrrr",
    c("", "Outcome", window_labels)
  )

# Table 3: robustness of the turnout estimates for all three states.
check_labels <- c(
  main = "Main specification", cluster_md_state = "Clustered by birth date within state",
  cluster_twoway = "Clustered by birth date and by election$^a$",
  discovery = "Florida 2006--2016 only", replication = "All other elections",
  florida_late = "\\quad Florida 2018--2020 only",
  general = "General elections only", primary = "Primaries only",
  oh_pa_all = "Ohio and Pennsylvania", oh_pa_settled = "\\quad registered a year or more before"
)
robustness |>
  widen(check) |>
  dplyr::mutate(check = factor(check, names(check_labels))) |>
  dplyr::arrange(check) |>
  dplyr::transmute(Specification = check_labels[as.character(check)], week_before, day_before, birthday) |>
  write_table(file.path(table_dir, "robustness.tex"), "lrrr", c("", window_labels))

# Appendix: turnout by election.
elections |>
  dplyr::transmute(
    State = blank_repeats(unname(state_labels[state])),
    Election = paste(sub(" 0", " ", format(election_date, "%b %d, %Y")), election_type),
    Registrants = count(n), Turnout = pct(voted / n),
    Official = dplyr::if_else(is.na(turnout_pct), "--", paste0(formatC(turnout_pct, format = "fg"), "\\%")),
    `E-Day birthdays` = count(treated_n)
  ) |>
  write_longtable(file.path(table_dir, "elections.tex"), "llrrrr",
    c("State", "Election", "Registrants", "Turnout", "Official", "Birthday on E-Day"),
    caption = paste(
      "Registrants and turnout by election. Turnout is the share of registrants in the analysis",
      "sample who voted; Official is the state's reported turnout where we could verify it."
    ), label = "tab:elections"
  )

# Numbers quoted in the text.
registration <- readr::read_csv(file.path(cells_dir, "oh_2016_registration_by_birthday.csv"), show_col_types = FALSE)
registration_ratio <- registration$registrations[registration$days_from_birthday == 0L] /
  stats::median(registration$registrations[abs(registration$days_from_birthday) > 60L])
get <- \(scope_, outcome_, window_) dplyr::filter(summary, scope == scope_, outcome == outcome_, window == window_)
rob <- \(check_, window_) dplyr::filter(robustness, check == check_, window == window_)
far <- dplyr::filter(event, scope == "Pooled", outcome == "voted", abs(shift) %in% placebo_days)
pooled_day <- get("Pooled", "voted", "day_before")
pooled_week <- get("Pooled", "voted", "week_before")
pooled_birthday <- get("Pooled", "voted", "birthday")
values <- c(
  nStates = nrow(data_summary),
  nElections = sum(data_summary$elections),
  nElectionsPa = data_summary$elections[data_summary$state == "PA"],
  nPersonElections = count(sum(data_summary$person_elections)),
  nBirthday = count(sum(data_summary$birthday_n)),
  nRegistrantsFl = count(data_summary$registrants[data_summary$state == "FL"]),
  window = event_window,
  weekPooled = pts(-pooled_week$estimate), weekPooledSe = pts(pooled_week$std_error),
  dayPooled = pts(-pooled_day$estimate), dayPooledSe = pts(pooled_day$std_error),
  dayPooledRate = pct(pooled_day$rate),
  dayPooledRelative = pct(-pooled_day$estimate / pooled_day$rate, 1),
  birthdayPooled = pts(pooled_birthday$estimate), birthdayPooledSe = pts(pooled_birthday$std_error),
  birthdayPooledLo = pts(pooled_birthday$estimate - z * pooled_birthday$std_error),
  birthdayPooledHi = pts(pooled_birthday$estimate + z * pooled_birthday$std_error),
  dayFl = pts(-get("FL", "voted", "day_before")$estimate),
  dayOh = pts(-get("OH", "voted", "day_before")$estimate),
  dayPa = pts(-get("PA", "voted", "day_before")$estimate),
  birthdayFl = pts(get("FL", "voted", "birthday")$estimate),
  birthdayOh = pts(get("OH", "voted", "birthday")$estimate),
  birthdayPa = pts(get("PA", "voted", "birthday")$estimate),
  pollsDayFl = pts(-get("FL", "polls", "day_before")$estimate),
  pollsDayPa = pts(-get("PA", "polls", "day_before")$estimate),
  pollsBirthdayFl = pts(-get("FL", "polls", "birthday")$estimate),
  earlyBirthdayFl = pts(get("FL", "early", "birthday")$estimate),
  mailBirthdayFl = pts(get("FL", "mail", "birthday")$estimate),
  mailBirthdayPa = pts(get("PA", "mail", "birthday")$estimate),
  replicationDay = pts(-rob("replication", "day_before")$estimate),
  replicationDaySe = pts(rob("replication", "day_before")$std_error),
  discoveryDay = pts(-rob("discovery", "day_before")$estimate),
  lateFlDay = pts(-rob("florida_late", "day_before")$estimate),
  lateFlDaySe = pts(rob("florida_late", "day_before")$std_error),
  settledDay = pts(-rob("oh_pa_settled", "day_before")$estimate),
  allDay = pts(-rob("oh_pa_all", "day_before")$estimate),
  twowaySe = pts(rob("cluster_twoway", "day_before")$std_error),
  farSd = pts(stats::sd(far$estimate)),
  generalDay = pts(-rob("general", "day_before")$estimate),
  primaryDay = pts(-rob("primary", "day_before")$estimate),
  placeboFrom = min(placebo_days),
  registrationRatio = formatC(registration_ratio, format = "f", digits = 1),
  threeDaysPooled = pts(-get("Pooled", "voted", "three_days_before")$estimate),
  threeDaysPooledSe = pts(get("Pooled", "voted", "three_days_before")$std_error),
  twoWeeksPooled = pts(-get("Pooled", "voted", "two_weeks_before")$estimate),
  twoWeeksPooledSe = pts(get("Pooled", "voted", "two_weeks_before")$std_error)
)
write_macros(values, file.path(table_dir, "macros.tex"))

writeLines(paste0(
  "\\newcommand{\\TableStyle}{\\", table_style$font_size,
  "\\setlength{\\tabcolsep}{", table_style$column_padding,
  "}\\renewcommand{\\arraystretch}{", table_style$row_stretch, "}}"
), file.path(table_dir, "style.tex"))
