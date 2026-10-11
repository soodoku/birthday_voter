# Build Florida cells from one voter-file extract: for every statewide
# election, every registrant in the extract is counted by exact date of
# birth, whether they were registered by the books-closing deadline, and what
# the history file records for them. Nonvoters are kept in the denominator
# whatever voting method other people used; the notebook this replaces
# dropped early and mail voters but kept nonvoters, which made its "turnout"
# a conditional rate.

fl_detail_columns <- c(
  "county_code", "voter_id", "name_last", "name_suffix", "name_first", "name_middle", "exemption",
  "res_addr_1", "res_addr_2", "res_city", "res_state", "res_zip", "mail_addr_1", "mail_addr_2", "mail_addr_3",
  "mail_city", "mail_state", "mail_zip", "mail_country", "gender", "race", "birth_date", "registration_date",
  "party", "precinct", "precinct_group", "precinct_split", "precinct_suffix", "voter_status",
  "congressional_district", "house_district", "senate_district", "county_commission_district",
  "school_board_district", "area_code", "phone", "phone_ext", "email"
)
fl_history_columns <- c("county_code", "voter_id", "election_date", "election_type", "history_code")

# Lower rank wins when a voter has more than one record for an election.
fl_code_rank <- c(Y = 1L, E = 1L, A = 1L, P = 2L, B = 2L, N = 3L)

duckdb_columns <- function(names) {
  paste0("{", paste0("'", names, "': 'VARCHAR'", collapse = ", "), "}")
}

extract_7z <- function(archive, dest) {
  if (dir.exists(dest) && length(list.files(dest, recursive = TRUE)) > 0L) {
    return(invisible(dest))
  }
  dir.create(dest, recursive = TRUE, showWarnings = FALSE)
  status <- system2("7z", c("x", "-y", paste0("-o", shQuote(dest)), shQuote(archive)), stdout = FALSE)
  if (status != 0L) stop("7z failed on ", archive)
  # The 2022 archives wrap a zip file rather than the text files themselves.
  for (inner in list.files(dest, pattern = "\\.zip$", recursive = TRUE, full.names = TRUE)) {
    status <- system2("7z", c("x", "-y", paste0("-o", shQuote(dirname(inner))), shQuote(inner)), stdout = FALSE)
    if (status != 0L) stop("7z failed on ", inner)
    file.remove(inner)
  }
  invisible(dest)
}

build_fl_cells <- function(extract, elections, deadline_days, con) {
  src <- file.path(raw_dir, "fl", extract)
  archives <- list.files(src, pattern = "\\.7z$", full.names = TRUE)
  detail_dir <- extract_7z(grep("Detail", archives, value = TRUE), file.path(work_dir, "fl", extract, "detail"))
  history_dir <- extract_7z(grep("History", archives, value = TRUE), file.path(work_dir, "fl", extract, "history"))
  glob <- \(dir) file.path(dir, "**", "*.txt")

  DBI::dbExecute(con, sprintf(
    "CREATE OR REPLACE TABLE detail_raw AS SELECT * FROM read_csv(%s, delim = '\t', header = false,
       quote = '', escape = '', columns = %s, filename = true)",
    DBI::dbQuoteString(con, glob(detail_dir)), duckdb_columns(fl_detail_columns)
  ))
  DBI::dbExecute(con, sprintf(
    "CREATE OR REPLACE TABLE history_raw AS SELECT * FROM read_csv(%s, delim = '\t', header = false,
       quote = '', escape = '', columns = %s, filename = true)",
    DBI::dbQuoteString(con, glob(history_dir)), duckdb_columns(fl_history_columns)
  ))
  DBI::dbWriteTable(con, "elections", elections, overwrite = TRUE)
  DBI::dbWriteTable(con, "code_rank", data.frame(code = names(fl_code_rank), rank = fl_code_rank), overwrite = TRUE)

  DBI::dbExecute(con, "
    CREATE OR REPLACE TABLE detail AS
    SELECT trim(voter_id, ' \t\r') AS voter_id,
           try_strptime(trim(birth_date, ' \t\r'), '%m/%d/%Y')::DATE AS dob,
           try_strptime(trim(registration_date, ' \t\r'), '%m/%d/%Y')::DATE AS reg_date,
           trim(voter_status, ' \t\r') AS voter_status
    FROM detail_raw")
  # One record per voter and election: a counted ballot over an uncounted one over a recorded non-vote,
  # ties broken by code. An aggregate rather than a window, so DuckDB can spill it to disk.
  DBI::dbExecute(con, "
    CREATE OR REPLACE TABLE history AS
    SELECT h.voter_id, h.election_date, h.election_type, arg_min(h.code, r.rank * 1000 + ascii(h.code)) AS code
    FROM (
      SELECT trim(voter_id, ' \t\r') AS voter_id,
             try_strptime(trim(election_date, ' \t\r'), '%m/%d/%Y')::DATE AS election_date,
             trim(election_type, ' \t\r') AS election_type,
             trim(history_code, ' \t\r') AS code
      FROM history_raw) h
    JOIN code_rank r USING (code)
    GROUP BY ALL")
  # One election at a time, so the voter-by-election join never has to hold every election at once.
  DBI::dbExecute(con, "DROP TABLE IF EXISTS election_cells")
  for (k in seq_len(nrow(elections))) {
    DBI::dbExecute(con, sprintf(
      "%s election_cells %s
       SELECT e.election_date, e.election_type, d.dob,
              d.reg_date <= e.election_date - INTERVAL %d DAY AS registered,
              count(*) AS n,
              count(*) FILTER (WHERE h.code = 'Y') AS polls,
              count(*) FILTER (WHERE h.code = 'E') AS early,
              count(*) FILTER (WHERE h.code = 'A') AS mail,
              count(*) FILTER (WHERE h.code = 'P') AS provisional_rejected,
              count(*) FILTER (WHERE h.code = 'B') AS mail_rejected,
              count(*) FILTER (WHERE h.code = 'N') AS recorded_nonvote
       FROM detail d
       CROSS JOIN (SELECT * FROM elections WHERE election_date = DATE '%s' AND election_type = '%s') e
       LEFT JOIN history h ON h.voter_id = d.voter_id AND h.election_date = e.election_date
                          AND h.election_type = e.election_type
       WHERE d.dob IS NOT NULL AND d.reg_date IS NOT NULL
       GROUP BY ALL",
      if (k == 1L) "CREATE TABLE" else "INSERT INTO", if (k == 1L) "AS" else "", deadline_days,
      format(elections$election_date[k]), elections$election_type[k]
    ))
  }
  cells <- DBI::dbGetQuery(con, "SELECT * FROM election_cells ORDER BY ALL")
  cells$extract <- extract
  cells
}

# Counts that do not depend on the detail join, for reconciliation with the
# notebook and with official returns.
fl_diagnostics <- function(con) {
  list(
    detail = DBI::dbGetQuery(con, "
      SELECT count(*) AS rows, count(DISTINCT voter_id) AS voters,
             count(*) FILTER (WHERE dob IS NULL) AS missing_dob,
             count(*) FILTER (WHERE reg_date IS NULL) AS missing_reg_date,
             count(*) FILTER (WHERE voter_status = 'PRE') AS preregistered
      FROM detail"),
    history_codes_raw = DBI::dbGetQuery(con, "
      SELECT trim(history_code, ' \t\r') AS code, count(*) AS rows FROM history_raw GROUP BY ALL ORDER BY ALL"),
    history_by_election = DBI::dbGetQuery(con, "
      SELECT election_date, election_type, code, count(*) AS records,
             count(*) FILTER (WHERE voter_id NOT IN (SELECT voter_id FROM detail)) AS not_in_detail
      FROM history GROUP BY ALL ORDER BY ALL"),
    top_birthdays = DBI::dbGetQuery(con, "
      SELECT dob, count(*) AS voters FROM detail WHERE dob IS NOT NULL
      GROUP BY dob ORDER BY voters DESC LIMIT 25")
  )
}
