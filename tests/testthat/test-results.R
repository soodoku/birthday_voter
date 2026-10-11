test_that("cells reproduce the counts the original notebook printed", {
  detail <- readr::read_csv(file.path(cells_dir, "fl_2017_detail.csv"), show_col_types = FALSE)
  expect_equal(detail$rows, 13710358)
  expect_equal(detail$rows - detail$missing_dob, 13654118)
  codes <- readr::read_csv(file.path(cells_dir, "fl_2017_history_codes_raw.csv"), show_col_types = FALSE)
  expect_equal(sum(codes$rows), 72770189)
  history <- readr::read_csv(file.path(cells_dir, "fl_2017_history_by_election.csv"), show_col_types = FALSE)
  votes <- history[history$code %in% c("Y", "E", "A") & history$election_type %in% c("GEN", "PRI"), ]
  totals <- stats::aggregate(records ~ election_date + election_type, votes, sum)
  expect_equal(sum(totals$records[totals$records > 1e6]), 51077533)
})

test_that("every registrant appears once per election and the modes add up", {
  cells <- readr::read_csv(file.path(cells_dir, "fl_2017.csv.gz"), show_col_types = FALSE)
  per_election <- stats::aggregate(n ~ election_date + election_type, cells, sum)
  expect_true(all(per_election$n == 13654118))
  counted <- cells$polls + cells$early + cells$mail + cells$provisional_rejected + cells$mail_rejected +
    cells$recorded_nonvote
  expect_true(all(counted <= cells$n))
})

test_that("the event study covers every day and Florida's methods add up to turnout", {
  event <- read_tab("event.csv")
  florida <- event[event$scope == "FL", c("outcome", "shift", "estimate")]
  wide <- tidyr::pivot_wider(florida, names_from = outcome, values_from = estimate)
  expect_equal(sort(wide$shift), -event_window:event_window)
  expect_equal(wide$voted, wide$polls + wide$early + wide$mail, tolerance = 1e-10)
  expect_setequal(unique(event$scope), c("FL", "OH", "PA", "Pooled"))
})

test_that("summary estimates are the averages of the daily estimates", {
  event <- read_tab("event.csv")
  summary <- read_tab("summary.csv")
  for (scope_ in unique(summary$scope)) {
    daily <- event[event$scope == scope_ & event$outcome == "voted", ]
    week <- summary[summary$scope == scope_ & summary$outcome == "voted" & summary$window == "week_before", ]
    expect_equal(week$estimate, mean(daily$estimate[daily$shift %in% -7:-1]), tolerance = 1e-10)
  }
})

test_that("the manuscript takes its numbers from macros", {
  tex <- readLines(project_file("ms", "main.tex"))
  body <- tex[seq(grep("begin\\{abstract\\}", tex), grep("bibliographystyle", tex))]
  body <- gsub("\\\\cite[a-z]*\\{[^}]*\\}|\\\\ref\\{[^}]*\\}|\\\\label\\{[^}]*\\}|\\{[a-z]+\\.pdf\\}", "", body)
  # Calendar facts, legal deadlines, file coverage, and design constants; every estimate is a macro.
  allowed <- c(
    "2000", "2006", "2009", "2016", "2017", "2018", "2020", "2022", "2024",
    "0", "1", "2", "4", "8", "23", "18", "30", "40", "60", "95", "100", "365", "366"
  )
  numbers <- unlist(regmatches(body, gregexpr("[0-9][0-9,.]*", body)))
  expect_equal(setdiff(sub("[.,]$", "", numbers), allowed), character(0))
})
