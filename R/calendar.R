# Calendar arithmetic for birthdays and elections. Everything that turns a
# date of birth into an age or a distance from a birthday goes through here;
# the notebook this replaces used days / 365, which ages people up to four
# days early, right where the treatment sits.

is_leap_year <- function(year) (year %% 4L == 0L & year %% 100L != 0L) | year %% 400L == 0L

# A 29 February birthday falls on 1 March in common years.
birthday_in_year <- function(dob, year) {
  lt <- as.POSIXlt(dob)
  month <- lt$mon + 1L
  day <- lt$mday
  leap_day <- !is.na(month) & month == 2L & day == 29L & !is_leap_year(year)
  month[leap_day] <- 3L
  day[leap_day] <- 1L
  as.Date(ISOdate(year, month, day))
}

age_on <- function(dob, date) {
  year <- as.POSIXlt(date)$year + 1900L
  age <- year - (as.POSIXlt(dob)$year + 1900L)
  as.integer(age - (birthday_in_year(dob, year) > date))
}

# Signed days from `date` to the nearest birthday; positive when the birthday
# comes after the date. Ties at half a year resolve to the earlier birthday.
days_to_birthday <- function(dob, date) {
  year <- as.POSIXlt(date)$year + 1900L
  gaps <- vapply(-1:1, \(k) as.integer(birthday_in_year(dob, year + k) - date), integer(length(dob)))
  gaps <- matrix(gaps, ncol = 3L)
  pick <- max.col(-abs(gaps), ties.method = "first")
  gaps[cbind(seq_len(nrow(gaps)), pick)]
}
