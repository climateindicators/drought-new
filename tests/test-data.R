# Regression checks on the generated data for the Drought indicator.
#
#   Rscript tests/test-data.R
#
# The checks below are shape-independent: they hold whatever the reshape in
# R/build_data.R turns each figure into. Value snapshots, which pin the actual
# numbers so a data update fails loudly instead of passing silently, are the
# TODO at the bottom.

setwd(here::here())
source("R/utils/write_stable.R")

# Keeps the dictionary check readable when a meta.yml field is absent altogether.
`%||%` <- function(a, b) if (is.null(a)) b else a

failures <- character()
check <- function(label, ok) {
  ok <- isTRUE(ok)
  cat(sprintf("  [%s] %s\n", if (ok) "PASS" else "FAIL", label))
  if (!ok) failures <<- c(failures, label)
  invisible(ok)
}

rd <- function(f) {
  readr::read_csv(file.path("data", f),
                  col_types = readr::cols(.default = readr::col_character()),
                  na = character(), progress = FALSE)
}

meta <- yaml::read_yaml("data/meta.yml")

cat("\nData dictionary\n")
check("meta.yml documents 4 dataset(s)", length(meta$datasets) == 4L)
check("meta.yml has no timestamp",
      !any(grepl("\\d{4}-\\d{2}-\\d{2}T|Sys\\.time|generated_at",
                 readLines("data/meta.yml", warn = FALSE))))

for (ds in meta$datasets) {
  df   <- rd(ds$file)
  cols <- vapply(ds$columns, function(x) x$name, character(1))
  check(sprintf("%s: meta.yml lists the columns the file actually has", ds$file),
        identical(cols, names(df)))
  check(sprintf("%s: meta.yml row count matches the file", ds$file),
        identical(as.integer(ds$rows), nrow(df)))
  check(sprintf("%s: every column has a type and a description", ds$file),
        all(vapply(ds$columns, function(x) nzchar(x$type %||% "") && nzchar(x$description %||% ""), logical(1))))
  check(sprintf("%s: source file is still present and unchanged", ds$file),
        identical(file_sha256(file.path("data-raw", ds$source_file)), ds$source_sha256))
  check(sprintf("%s: no blank rows", ds$file), nrow(df) > 0L)
}

cat("\nFile hygiene\n")
for (f in list.files("data", pattern = "[.](csv|yml)$", full.names = TRUE)) {
  check(sprintf("%s is UTF-8, LF, no BOM, no mojibake", basename(f)),
        tryCatch({ assert_clean_output(f); TRUE },
                 error = function(e) { cat("      ", conditionMessage(e), "\n"); FALSE }))
}

cat("\nValue snapshots\n")

# Values are compared as the strings the build wrote, not as numbers, because
# the source carries up to 10 significant digits and a numeric comparison would
# pass on a build that quietly rounded them.
row_str <- function(d, i) paste(unlist(d[i, ]), collapse = "|")

snapshot <- function(file, rows, first, last, lowest, highest) {
  d <- rd(file)
  v <- suppressWarnings(as.numeric(d$value))
  check(sprintf("%s: %d rows", file, rows), nrow(d) == rows)
  check(sprintf("%s: first row is %s", file, first), identical(row_str(d, 1L), first))
  check(sprintf("%s: last row is %s", file, last), identical(row_str(d, nrow(d)), last))
  check(sprintf("%s: lowest value is %s", file, lowest), identical(d$value[which.min(v)], lowest))
  check(sprintf("%s: highest value is %s", file, highest), identical(d$value[which.max(v)], highest))
}

# One row per group: key, expected row count, expected lowest and highest value.
group_span <- function(file, group, expected) {
  d <- rd(file)
  for (i in seq_len(nrow(expected))) {
    s <- d[d[[group]] == expected$key[i], ]
    v <- suppressWarnings(as.numeric(s$value))
    check(
      sprintf("%s: %s has %d rows spanning %s to %s",
              file, expected$key[i], expected$n[i], expected$lowest[i], expected$highest[i]),
      nrow(s) == expected$n[i] &&
        identical(s$value[which.min(v)], expected$lowest[i]) &&
        identical(s$value[which.max(v)], expected$highest[i])
    )
  }
}

snapshot(
  "drought_palmer_index.csv", 258L,
  "1895|annual|Annual average|-0.120833333",
  "2023|nine_year|9-yr average|-2.341337891",
  "-6.69", "5.005833333"
)
group_span("drought_palmer_index.csv", "series", data.frame(
  key     = c("annual", "nine_year"),
  n       = c(129L, 129L),
  lowest  = c("-6.69", "-3.481126302"),
  highest = c("5.005833333", "3.052405599")
))

snapshot(
  "drought_spei_national.csv", 124L,
  "1900|-0.149225487",
  "2023|0.39782823",
  "-1.206155824", "0.890627618"
)

snapshot(
  "drought_spei_change.csv", 344L,
  "ALL_RI|ALL|RI|1.765086422",
  "YELLOWSTONE DRAINAGE_WY|YELLOWSTONE DRAINAGE|WY|1.348018679",
  "-2.592166504", "2.582431282"
)

snapshot(
  "drought_monitor_area.csv", 6260L,
  "2000-01-04|D0|D0 Abnormally dry|23.1",
  "2023-12-26|D4|D4 Exceptional drought|0.97",
  "0", "36.58"
)
group_span("drought_monitor_area.csv", "category", data.frame(
  key     = c("D0", "D1", "D2", "D3", "D4"),
  n       = rep(1252L, 5),
  lowest  = c("5.97", "2.04", "0.13", "0", "0"),
  highest = c("36.58", "22.53", "24.01", "16.67", "9.99")
))

cat("\nAgreement with EPA's published Key Points\n")
# These four are the checks that would catch a reshape that reads the data
# differently than EPA's own prose does, which no row count or column name can.

d1 <- rd("drought_palmer_index.csv")
d2 <- rd("drought_spei_national.csv")
d3 <- rd("drought_spei_change.csv")
d4 <- rd("drought_monitor_area.csv")

worst_year <- function(d) d$year[which.min(suppressWarnings(as.numeric(d$value)))]
check("Figure 1 and Figure 2 both bottom out in the 1930s Dust Bowl",
      identical(worst_year(d1[d1$series == "annual", ]), "1934") &&
        identical(worst_year(d1[d1$series == "nine_year", ]), "1935") &&
        identical(worst_year(d2), "1934"))

check("Figure 3 covers all 48 contiguous states and is mostly wetter",
      length(unique(d3$state)) == 48L &&
        sum(as.numeric(d3$value) > 0) == 269L &&
        sum(as.numeric(d3$value) < 0) == 75L)

check("Figure 3's driest division is in the Southwest",
      identical(d3$climate_division[which.min(as.numeric(d3$value))], "SOUTHWEST_AZ"))

# The five Drought Monitor classes partition the dry area rather than nesting,
# so their sum is the share of the country that was at least abnormally dry.
# EPA's Key Points put that at "roughly 10 to 70 percent" and say that in the
# latter half of 2012 "more than half" of the country was in moderate or greater
# drought. Reading the classes as cumulative instead would cap the first figure
# at 36.58 and the second at 22.53, so this is what pins the reading.
total    <- tapply(as.numeric(d4$value), d4$date, sum)
moderate <- tapply(as.numeric(d4$value[d4$category != "D0"]), d4$date[d4$category != "D0"], sum)
check("Figure 4's classes sum to 8.50-72.38 percent of U.S. land area, peaking 2012-07-17",
      length(total) == 1252L &&
        identical(sprintf("%.2f", min(total)), "8.50") &&
        identical(sprintf("%.2f", max(total)), "72.38") &&
        identical(names(total)[which.max(total)], "2012-07-17"))
check("Figure 4 puts 54.78 percent in moderate or greater drought on 2012-09-25",
      identical(sprintf("%.2f", max(moderate)), "54.78") &&
        identical(names(moderate)[which.max(moderate)], "2012-09-25"))

cat("\n")
if (length(failures)) {
  cat(sprintf("%d FAILED:\n", length(failures)))
  for (f in failures) cat("  -", f, "\n")
  quit(status = 1L)
}
cat("All data checks passed.\n")
