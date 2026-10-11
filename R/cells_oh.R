# Build Ohio cells from the statewide voter file. Each election is a column;
# any entry (a party letter, or X for a ballot without a party) means the
# person voted, and the file does not say how.

oh_elections <- function(columns) {
  hist <- grep("^(GENERAL|PRIMARY)-[0-9]{2}/[0-9]{2}/[0-9]{4}$", columns, value = TRUE)
  type <- sub("-.*", "", hist)
  date <- as.Date(sub(".*-", "", hist), "%m/%d/%Y")
  month <- as.integer(format(date, "%m"))
  year <- as.integer(format(date, "%Y"))
  # November generals every year (statewide issues in odd years); March or May primaries in even years.
  keep <- (type == "GENERAL" & month == 11L & as.integer(format(date, "%d")) <= 8L) |
    (type == "PRIMARY" & year %% 2L == 0L & month %in% c(3L, 5L))
  data.frame(
    source_column = hist[keep], election_date = date[keep],
    election_type = ifelse(type[keep] == "GENERAL", "GEN", "PRI")
  )
}

# Fields contain stray quote characters, so a CSV parser misreads some rows.
# Every line has exactly 100 fields when split on the "," separator, so lines
# are read whole and split on it.
build_oh_cells <- function(extract, deadline_days, con) {
  files <- list.files(file.path(raw_dir, "oh", extract), pattern = "\\.txt\\.gz$", full.names = TRUE)
  header <- strsplit(gsub('^"|"$', "", readLines(gzfile(files[1]), n = 1L)), '","', fixed = TRUE)[[1]]
  elections <- oh_elections(header)
  field <- \(name) sprintf("f[%d]", match(name, header))
  DBI::dbExecute(con, sprintf(
    "CREATE OR REPLACE TABLE lines AS
     SELECT filename, string_split(regexp_replace(regexp_replace(line, '^\"', ''), '\"\\r?$', ''), '\",\"') AS f
     FROM read_csv([%s], header = true, columns = {'line': 'VARCHAR'}, delim = chr(1), quote = '',
                   escape = '', filename = true)",
    paste(DBI::dbQuoteString(con, files), collapse = ", ")
  ))
  DBI::dbExecute(con, sprintf(
    "CREATE OR REPLACE TABLE voters AS
     SELECT %s AS voter_id, try_strptime(%s, '%%Y-%%m-%%d')::DATE AS dob,
            try_strptime(%s, '%%Y-%%m-%%d')::DATE AS reg_date, filename, len(f) AS fields, %s
     FROM lines",
    field("SOS_VOTERID"), field("DATE_OF_BIRTH"), field("REGISTRATION_DATE"),
    paste0(vapply(elections$source_column, field, ""), " AS ",
      DBI::dbQuoteIdentifier(con, elections$source_column),
      collapse = ", "
    )
  ))
  DBI::dbWriteTable(con, "elections", elections, overwrite = TRUE)
  # REGISTRATION_DATE is the latest registration, so up to a third of past
  # votes predate it. Someone counts as registered for an election if the
  # date clears the deadline or they had voted in an earlier election; the
  # vote in the election itself never decides who is counted. `settled`
  # marks people whose latest registration was at least a year before the
  # election, so no registration change (often made when a driver's licence
  # is renewed, on the birthday) fell in the run-up to it.
  cells <- DBI::dbGetQuery(con, sprintf(
    "WITH long AS (UNPIVOT (SELECT voter_id, dob, reg_date, %s FROM voters) ON %s INTO NAME source_column VALUE ballot),
     votes AS (SELECT v.voter_id, v.dob, v.reg_date, e.election_date, e.election_type, trim(v.ballot) <> '' AS voted
               FROM long v JOIN elections e USING (source_column)),
     history AS (SELECT *, coalesce(bool_or(voted) OVER (PARTITION BY voter_id ORDER BY election_date
                          ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), false) AS voted_before
                 FROM votes)
     SELECT election_date, election_type, dob,
            reg_date <= election_date - INTERVAL %d DAY OR voted_before AS registered,
            reg_date <= election_date - INTERVAL 365 DAY AS settled,
            count(*) AS n, count(*) FILTER (WHERE voted) AS voted
     FROM history
     WHERE dob IS NOT NULL AND reg_date IS NOT NULL
     GROUP BY ALL ORDER BY ALL",
    paste(DBI::dbQuoteIdentifier(con, elections$source_column), collapse = ", "),
    paste(DBI::dbQuoteIdentifier(con, elections$source_column), collapse = ", "), deadline_days
  ))
  cells$extract <- extract
  cells
}

oh_diagnostics <- function(con) {
  list(
    detail = DBI::dbGetQuery(con, "
      SELECT count(*) AS rows, count(DISTINCT voter_id) AS voters,
             count(*) FILTER (WHERE dob IS NULL) AS missing_dob,
             count(*) FILTER (WHERE reg_date IS NULL) AS missing_reg_date,
             count(*) FILTER (WHERE NOT regexp_full_match(voter_id, 'OH[0-9]{10}')) AS malformed_id,
             count(*) FILTER (WHERE fields <> 100) AS wrong_field_count
      FROM voters"),
    rows_by_file = DBI::dbGetQuery(con, "
      SELECT regexp_extract(filename, '[^/]+$') AS file, count(*) AS rows FROM voters GROUP BY ALL ORDER BY ALL"),
    top_birthdays = DBI::dbGetQuery(con, "
      SELECT dob, count(*) AS voters FROM voters WHERE dob IS NOT NULL
      GROUP BY dob ORDER BY voters DESC LIMIT 25"),
    # Licences expire on birthdays and renewing one can update a registration, so registration dates
    # bunch near birthdays. Days from the birthday in the registration year to the registration date.
    registration_by_birthday = DBI::dbGetQuery(con, "
      WITH gaps AS (
        SELECT reg_date - make_date(year(reg_date), month(dob),
                                    CASE WHEN month(dob) = 2 AND day(dob) = 29 THEN 28 ELSE day(dob) END) AS gap
        FROM voters WHERE dob IS NOT NULL AND reg_date IS NOT NULL AND year(dob) > 1900)
      SELECT CASE WHEN gap > 182 THEN gap - 365 WHEN gap < -182 THEN gap + 365 ELSE gap END AS days_from_birthday,
             count(*) AS registrations
      FROM gaps GROUP BY 1 ORDER BY 1")
  )
}
