test_that("cell-weighted regression reproduces the person-level estimate and clustered SE", {
  set.seed(1)
  people <- expand.grid(
    md = sprintf("m%02d", 1:40), type = c("GEN", "PRI"), election = paste0("e", 1:6),
    by = 1950:1955, rep = 1:15, stringsAsFactors = FALSE
  )
  day <- as.integer(substr(people$md, 2, 3)) + as.integer(substr(people$election, 2, 2))
  people$treat <- as.integer(day %% 9 == 0)
  people$y <- rbinom(nrow(people), 1, 0.3 + 0.05 * people$treat + 0.01 * (people$by - 1950))
  cells <- aggregate(cbind(y, n = 1) ~ md + type + election + by + treat, people, sum)
  cells$share <- cells$y / cells$n
  person <- fixest::feols(y ~ treat | md^type + election^by, people, cluster = ~md, ssc = cell_ssc)
  cell <- fixest::feols(share ~ treat | md^type + election^by, cells, weights = ~n, cluster = ~md, ssc = cell_ssc)
  expect_equal(unname(coef(cell)), unname(coef(person)), tolerance = 1e-10)
  expect_equal(unname(fixest::se(cell)), unname(fixest::se(person)), tolerance = 1e-8)
})

test_that("cohort rules never split a birth year by birthday", {
  dob <- as.Date(c("1998-01-01", "1998-12-31", "1997-12-31", "1996-06-01", "1916-12-31", "1917-01-01"))
  cells <- data.frame(
    election_date = as.Date("2016-11-08"), election_type = "GEN", dob = dob, registered = TRUE,
    n = 10, polls = 1, early = 1, mail = 1, provisional_rejected = 0, mail_rejected = 0
  )
  elections <- data.frame(
    state = "FL", election_date = as.Date("2016-11-08"), election_type = "GEN", cycle = "presidential"
  )
  out <- prepare_cells(cells, elections, "FL")
  # 1998 cohort: youngest turns 18 after the election, so all of 1998 goes.
  # 1997 cohort: youngest turned 18 on 2015-12-31, long before the deadline.
  # 1916 cohort: oldest is 100 on Election Day.
  expect_equal(sort(unique(out$birth_year)), c(1917L, 1996L, 1997L))
})
