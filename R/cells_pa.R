# Build Pennsylvania cells from the Full Voter Export. Each county file holds
# that county's last 40 elections in 40 numbered slots, and a per-county
# Election Map says which date each slot refers to. Vote method codes: AP at
# the polls, AB absentee, MB mail-in (from 2020), P provisional.

pa_fields <- c(voter_id = 1L, dob = 8L, reg_date = 9L, status = 10L)
pa_method_field <- \(k) 71L + 2L * (k - 1L)

# Registration closed 30 days before an election until Act 77 of 2019 cut it to 15.
pa_deadline_days <- \(date) ifelse(date >= as.Date("2020-01-01"), 15L, 30L)

build_pa_cells <- function(extract, con) {
  dir <- file.path(work_dir, "pa", extract)
  if (length(list.files(dir, recursive = TRUE)) == 0L) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    archive <- list.files(file.path(raw_dir, "pa", extract), pattern = "\\.tar\\.gz$", full.names = TRUE)
    utils::untar(archive, exdir = dir)
  }
  maps <- list.files(dir, pattern = "Election Map", recursive = TRUE, full.names = TRUE)
  map <- do.call(rbind, lapply(maps, \(x) {
    utils::read.delim(x,
      header = FALSE, quote = "\"", colClasses = "character",
      col.names = c("county", "slot", "description", "date")
    )
  }))
  map$election_date <- as.Date(map$date, "%m/%d/%Y")
  # Statewide elections are the dates every county carries.
  counties <- length(unique(map$county))
  statewide <- names(which(tapply(map$county, map$election_date, \(x) length(unique(x))) == counties))
  map <- map[as.character(map$election_date) %in% statewide, ]
  # County descriptions are inconsistent; statewide generals are in November and primaries in spring.
  map$election_type <- ifelse(format(map$election_date, "%m") == "11", "GEN", "PRI")
  map$deadline_days <- pa_deadline_days(map$election_date)
  map$slot <- as.integer(map$slot)
  columns <- c("county", "slot", "description", "election_date", "election_type", "deadline_days")
  DBI::dbWriteTable(con, "map", map[columns], overwrite = TRUE)

  files <- list.files(dir, pattern = " FVE ", recursive = TRUE, full.names = TRUE)
  # Counties are processed one at a time to bound memory and temporary disk;
  # each voter's whole history sits in one county's record.
  DBI::dbExecute(con, "DROP TABLE IF EXISTS county_cells")
  DBI::dbExecute(con, "DROP TABLE IF EXISTS county_rows")
  for (file in files) pa_county_cells(file, con)
  cells <- DBI::dbGetQuery(con, "
    SELECT election_date, election_type, dob, registered, settled,
           sum(n) AS n, sum(polls) AS polls, sum(mail) AS mail, sum(provisional) AS provisional,
           sum(other_code) AS other_code
    FROM county_cells GROUP BY ALL ORDER BY ALL")
  cells$voted <- cells$polls + cells$mail
  cells$cast <- cells$voted + cells$provisional
  cells$extract <- extract
  cells
}

pa_county_cells <- function(file, con) {
  columns <- paste0("{", paste0("'c", 1:154, "': 'VARCHAR'", collapse = ", "), "}")
  slot_fields <- pa_method_field(1:40)
  slots <- paste0("c", slot_fields, collapse = ", ")
  # Some fields contain stray quote characters; every line has exactly 154
  # tab-separated fields, so quotes are stripped per field instead of parsed.
  unquote <- \(k) sprintf("trim(c%d, '\"')", k)
  DBI::dbExecute(con, sprintf(
    "CREATE OR REPLACE TEMP TABLE voters AS
     SELECT %s AS voter_id, try_strptime(%s, '%%m/%%d/%%Y')::DATE AS dob,
            try_strptime(%s, '%%m/%%d/%%Y')::DATE AS reg_date, %s AS status, %s AS county, %s
     FROM read_csv(%s, delim = '\t', quote = '', escape = '', header = false, columns = %s)",
    unquote(pa_fields[["voter_id"]]), unquote(pa_fields[["dob"]]), unquote(pa_fields[["reg_date"]]),
    unquote(pa_fields[["status"]]), unquote(152L),
    paste0(vapply(slot_fields, unquote, ""), " AS c", slot_fields, collapse = ", "),
    DBI::dbQuoteString(con, file), columns
  ))
  # REGISTRATION_DATE may be a re-registration; as in Ohio, someone counts as
  # registered if the date clears the deadline or they had voted before.
  DBI::dbExecute(con, sprintf(
    "CREATE TABLE IF NOT EXISTS county_cells AS SELECT * FROM (SELECT NULL::DATE AS election_date, NULL::VARCHAR AS
       election_type, NULL::DATE AS dob, NULL::BOOLEAN AS registered, NULL::BOOLEAN AS settled, 0::BIGINT AS n,
       0::BIGINT AS polls, 0::BIGINT AS mail, 0::BIGINT AS provisional, 0::BIGINT AS other_code) WHERE false"
  ))
  DBI::dbExecute(con, sprintf(
    "INSERT INTO county_cells
     WITH long AS (UNPIVOT (SELECT voter_id, dob, reg_date, county, %s FROM voters)
                   ON %s INTO NAME slot_column VALUE method),
     slots AS (
       SELECT l.voter_id, l.dob, l.reg_date, m.election_date, m.election_type, m.deadline_days, l.method
       FROM long l
       JOIN map m ON upper(m.county) = upper(l.county)
                 AND m.slot = (CAST(substr(l.slot_column, 2) AS INTEGER) - 69) // 2),
     -- A few counties list one date in two slots; keep one record per voter and election.
     votes AS (
       SELECT voter_id, dob, reg_date, election_date, election_type, deadline_days,
              arg_min(method, CASE WHEN method IN ('AP', 'AB', 'MB') THEN 1 WHEN method = 'P' THEN 2
                                   WHEN method = '' THEN 4 ELSE 3 END) AS method
       FROM slots GROUP BY ALL),
     history AS (
       SELECT *, coalesce(bool_or(method IN ('AP', 'AB', 'MB', 'P')) OVER (
                   PARTITION BY voter_id ORDER BY election_date
                   ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), false) AS voted_before
       FROM votes)
     SELECT election_date, election_type, dob,
            reg_date <= election_date - deadline_days OR voted_before AS registered,
            reg_date <= election_date - 365 AS settled,
            count(*) AS n,
            count(*) FILTER (WHERE method = 'AP') AS polls,
            count(*) FILTER (WHERE method IN ('AB', 'MB')) AS mail,
            count(*) FILTER (WHERE method = 'P') AS provisional,
            count(*) FILTER (WHERE method NOT IN ('', 'AP', 'AB', 'MB', 'P')) AS other_code
     FROM history
     WHERE dob IS NOT NULL AND reg_date IS NOT NULL
     GROUP BY ALL", slots, slots
  ))
  DBI::dbExecute(con, sprintf("
    CREATE TABLE IF NOT EXISTS county_rows (file VARCHAR, rows BIGINT, missing_dob BIGINT, missing_reg_date BIGINT,
                                            inactive BIGINT)"))
  DBI::dbExecute(con, sprintf("
    INSERT INTO county_rows
    SELECT %s, count(*), count(*) FILTER (WHERE dob IS NULL), count(*) FILTER (WHERE reg_date IS NULL),
           count(*) FILTER (WHERE status = 'I')
    FROM voters", DBI::dbQuoteString(con, basename(file))))
  invisible(NULL)
}

pa_diagnostics <- function(con) {
  list(
    detail = DBI::dbGetQuery(con, "
      SELECT sum(rows) AS rows, sum(missing_dob) AS missing_dob, sum(missing_reg_date) AS missing_reg_date,
             sum(inactive) AS inactive FROM county_rows"),
    rows_by_file = DBI::dbGetQuery(con, "SELECT file, rows FROM county_rows ORDER BY file"),
    elections = DBI::dbGetQuery(con, "SELECT DISTINCT election_date, election_type FROM map ORDER BY ALL"),
    duplicate_slots = DBI::dbGetQuery(con, "
      SELECT county, slot, description, election_date FROM map
      QUALIFY count(*) OVER (PARTITION BY county, election_date) > 1 ORDER BY ALL")
  )
}
