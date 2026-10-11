# Estimation on cells. A cell is one election x exact date of birth, with
# counts of registrants and of each kind of ballot. A regression of cell
# shares weighted by cell size returns the same coefficient as the
# person-level linear probability model, and, with only the G / (G - 1)
# cluster correction, the same clustered standard error (see
# tests/testthat/test-analysis.R).

outcomes <- c(
  voted = "Turnout", polls = "In person on Election Day", early = "Early in person", mail = "By mail"
)

cell_ssc <- fixest::ssc(K.adj = FALSE, G.adj = TRUE)

# Sample rules act on whole birth-year cohorts so that no rule depends on
# where in the year someone was born. A cohort is kept when its youngest
# member had turned 18 at least `margin_days` before the election (past the
# registration deadline) and its oldest member is under 100.
#
# Birth-date fixed effects are specific to state and election type, and
# election fixed effects to state, so pooled estimates compare people only
# with others born on the same date in the same state.
prepare_cells <- function(cells, elections, state, margin_days = 60L) {
  cells <- cells[cells$registered, ]
  elections <- elections[elections$state == state, c("election_date", "election_type", "cycle")]
  cells <- merge(cells, elections, by = c("election_date", "election_type"))
  cells$state <- state
  cells$birth_year <- as.integer(format(cells$dob, "%Y"))
  cells$election_year <- as.integer(format(cells$election_date, "%Y"))
  youngest <- as.Date(paste0(cells$birth_year, "-12-31"))
  oldest <- as.Date(paste0(cells$birth_year, "-01-01"))
  keep <- age_on(youngest, cells$election_date - margin_days) >= 18L & age_on(oldest, cells$election_date) < 100L
  cells <- cells[keep, ]
  cells$birth_md <- format(cells$dob, "%m-%d")
  cells$days <- days_to_birthday(cells$dob, cells$election_date)
  cells$age_years <- cells$election_year - cells$birth_year
  # Florida records how every ballot was cast; Pennsylvania records polls and
  # mail; Ohio records only whether someone voted.
  if (!"voted" %in% names(cells)) cells$voted <- cells$polls + cells$early + cells$mail
  for (y in intersect(names(outcomes), names(cells))) cells[[paste0("share_", y)]] <- cells[[y]] / cells$n
  cells$election <- factor(paste(state, cells$election_date, cells$election_type))
  cells$md_group <- factor(paste(state, cells$election_type, cells$birth_md))
  cells$md_state <- factor(paste(state, cells$birth_md))
  cells
}

measured <- function(cells, outcome) {
  column <- paste0("share_", outcome)
  column %in% names(cells) && !anyNA(cells[[column]])
}

# All days within `window` of the election enter one regression, against
# birthdays further away. Estimating each day in its own regression instead
# lets an effect on one day leak, with the opposite sign, into the estimates
# for its neighbours, because a birth date's other years serve as its
# comparison.
fit_event <- function(cells, outcome = "voted", window = 30L, cluster = ~birth_md) {
  cells$day <- ifelse(abs(cells$days) <= window, cells$days, 999L)
  fixest::feols(
    stats::as.formula(paste0("share_", outcome, " ~ i(day, ref = 999) | md_group + election^birth_year")),
    data = cells, weights = ~n, cluster = cluster, ssc = cell_ssc, notes = FALSE, lean = TRUE
  )
}

day_of <- \(term) as.integer(sub("^day::", "", term))

# Daily estimates, with how many people had their birthday on each day.
event_days <- function(fit, cells, outcome) {
  treated <- cells |>
    dplyr::filter(abs(days) <= event_window) |>
    dplyr::summarise(treated_n = sum(n), treated_rate = sum(.data[[outcome]]) / sum(n), .by = days)
  broom::tidy(fit) |>
    dplyr::transmute(outcome = outcome, shift = day_of(term), estimate, std_error = std.error) |>
    dplyr::left_join(treated, by = c(shift = "days"))
}

# Summaries of the daily estimates: the average over the week before the
# birthday, the day before, and Election Day itself, with standard errors
# from the clustered covariance of the daily coefficients.
# The week was chosen after seeing Florida; three days and two weeks show how much the choice matters.
summary_windows <- list(
  week_before = -7:-1, day_before = -1L, birthday = 0L, three_days_before = -3:-1, two_weeks_before = -14:-1
)

summarise_event <- function(fit, cells, outcome) {
  shift <- day_of(names(stats::coef(fit)))
  weights <- vapply(summary_windows, \(w) as.numeric(shift %in% w) / length(w), numeric(length(shift)))
  rownames(weights) <- names(stats::coef(fit))
  context <- purrr::map(summary_windows, \(w) {
    on <- cells$days %in% w
    tibble::tibble(treated_n = sum(cells$n[on]), rate = sum(cells[[outcome]][on]) / sum(cells$n[on]))
  }) |>
    purrr::list_rbind(names_to = "window")
  marginaleffects::hypotheses(fit, hypothesis = weights) |>
    tibble::as_tibble() |>
    dplyr::transmute(outcome = outcome, window = term, estimate, std_error = std.error) |>
    dplyr::left_join(context, by = "window") |>
    dplyr::mutate(sample_n = sum(cells$n))
}
