# Download restricted Dataverse files by id and verify them against the MD5
# that Dataverse publishes, so a truncated or substituted file fails here
# rather than surfacing as odd counts downstream.

dataverse_token <- function() {
  token <- Sys.getenv("DATAVERSE_API_TOKEN")
  if (nzchar(token)) {
    return(token)
  }
  if (!file.exists(dataverse_token_file)) stop("No Dataverse token in DATAVERSE_API_TOKEN or ", dataverse_token_file)
  trimws(readLines(dataverse_token_file, warn = FALSE)[1])
}

file_md5 <- function(path) unname(tools::md5sum(path))

fetch_file <- function(row, dest_dir) {
  dest <- file.path(dest_dir, row$filename)
  if (file.exists(dest) && file_md5(dest) == row$md5) {
    message("present: ", row$filename)
    return(invisible(dest))
  }
  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
  partial <- paste0(dest, ".part")
  message("fetching: ", row$filename, " (", format(row$bytes, big.mark = ","), " bytes)")
  httr2::request(dataverse_server) |>
    httr2::req_url_path_append("api", "access", "datafile", row$file_id) |>
    httr2::req_url_query(format = "original") |>
    httr2::req_headers(`X-Dataverse-key` = dataverse_token(), .redact = "X-Dataverse-key") |>
    httr2::req_retry(max_tries = 3) |>
    httr2::req_timeout(3600) |>
    httr2::req_perform(path = partial)
  got <- file_md5(partial)
  if (got != row$md5) stop(row$filename, ": MD5 ", got, " does not match Dataverse's ", row$md5)
  file.rename(partial, dest)
  invisible(dest)
}

fetch_extract <- function(state, extract) {
  sources <- utils::read.csv(sources_file, colClasses = "character")
  sources$bytes <- as.numeric(sources$bytes)
  rows <- sources[sources$state == state & sources$extract == extract, ]
  if (nrow(rows) == 0L) stop("No sources for ", state, " ", extract)
  rows <- rows[order(rows$bytes), ]
  for (i in seq_len(nrow(rows))) fetch_file(rows[i, ], file.path(raw_dir, tolower(state), extract))
}
