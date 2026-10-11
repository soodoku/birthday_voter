d <- as.Date

test_that("age is completed calendar years, not days / 365", {
  # The notebook's days / 365 rule calls this person 18; they are 17.
  expect_equal(age_on(d("2000-11-08"), d("2018-11-06")), 17L)
  expect_equal(age_on(d("2000-11-06"), d("2018-11-06")), 18L)
  expect_equal(age_on(d("2000-11-05"), d("2018-11-06")), 18L)
  expect_equal(age_on(d("1932-08-28"), d("2006-09-05")), 74L)
})

test_that("leap-day births come of age on 1 March in common years", {
  expect_equal(age_on(d("2000-02-29"), d("2018-02-28")), 17L)
  expect_equal(age_on(d("2000-02-29"), d("2018-03-01")), 18L)
  expect_equal(age_on(d("2000-02-29"), d("2016-02-29")), 16L)
})

test_that("days to birthday is signed and positive when the birthday follows the election", {
  expect_equal(days_to_birthday(d("1952-11-04"), d("2014-11-04")), 0L)
  expect_equal(days_to_birthday(d("1990-11-10"), d("2012-11-06")), 4L)
  expect_equal(days_to_birthday(d("1990-11-01"), d("2012-11-06")), -5L)
})

test_that("days to birthday wraps around the new year to the nearest birthday", {
  expect_equal(days_to_birthday(d("1980-01-02"), d("2016-12-31")), 2L)
  expect_equal(days_to_birthday(d("1980-12-30"), d("2017-01-01")), -2L)
  expect_true(all(abs(days_to_birthday(d("1980-05-15") + 0:365, d("2014-11-04"))) <= 183L))
})

test_that("leap-day births are never coded as an election-day birthday in common years", {
  expect_equal(days_to_birthday(d("1960-02-29"), d("2014-03-01")), 0L)
  expect_equal(days_to_birthday(d("1960-02-29"), d("2016-02-29")), 0L)
  expect_equal(days_to_birthday(d("1960-02-29"), d("2016-03-01")), -1L)
})

test_that("functions are vectorised and propagate missing dates", {
  out <- age_on(d(c("2000-01-01", NA)), d("2018-01-01"))
  expect_equal(out, c(18L, NA_integer_))
  expect_equal(days_to_birthday(d(NA), d("2018-01-01")), NA_integer_)
})
