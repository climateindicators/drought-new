# Build tidy long-format data for the Drought indicator.
#
#   Rscript R/build_data.R
#
# Reads EPA's published figure CSVs in data-raw/ and writes data/*.csv plus
# data/meta.yml. Rerunning with unchanged inputs produces byte-identical output.
# Nothing here touches the network.
#
# TO UPDATE THE DATA: drop replacement CSVs into data-raw/ and rerun. Headers
# are asserted, not assumed, so a renamed or reordered column stops the build.

suppressPackageStartupMessages({
  library(dplyr)
})

root <- here::here()
source(file.path(root, "R/utils/epa_csv.R"))
source(file.path(root, "R/utils/write_stable.R"))

raw_dir <- file.path(root, "data-raw")
out_dir <- file.path(root, "data")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# Every reshape below sorts with order() against an integer or a match() index
# rather than with arrange() on a character column, because character sorting is
# locale-dependent and the output has to be byte-identical on every machine.

# ---- Indicator constants -----------------------------------------------------

INDICATOR <- list(
  name                    = "Drought",
  slug                    = "drought",
  publisher               = "U.S. Environmental Protection Agency",
  source_page             = "https://19january2025snapshot.epa.gov/climate-indicators/climate-change-indicators-drought/index.html",
  technical_documentation = "https://19january2025snapshot.epa.gov/system/files/documents/2024-06/drought_documentation.pdf",
  rights                  = "Public domain, work of the U.S. Government (17 U.S.C. 105)"
)

col <- function(name, type, description) {
  list(name = name, type = type, description = description)
}

# ---- Figure 1: Average Drought Conditions in the Contiguous 48 States According to the Palmer Index, 1895–2023 ----

f1_path <- file.path(raw_dir, "drought_fig-1.csv")
f1_meta <- read_epa_preamble(f1_path)
f1_raw  <- read_epa_csv(f1_path)

# The two series, keyed for code and labelled with EPA's own column header, so a
# chart legend cannot drift from the published file. Vector order is also the
# output row order.
F1_SERIES <- c(annual = "Annual average", nine_year = "9-yr average")

assert_headers(
  f1_raw,
  id_cols          = "Year",
  expected_headers = unname(F1_SERIES),
  what             = "drought_fig-1.csv"
)

f1 <- f1_raw |>
  tidyr::pivot_longer(
    cols      = all_of(unname(F1_SERIES)),
    names_to  = "series_label",
    values_to = "value"
  ) |>
  transmute(
    year         = Year,
    series       = names(F1_SERIES)[match(series_label, F1_SERIES)],
    series_label = series_label,
    value        = value
  )
f1 <- f1[order(match(f1$series, names(F1_SERIES)), as.integer(f1$year)), ]

assert_conservation(f1_raw, unname(F1_SERIES), nrow(f1), "drought_fig-1.csv")

write_csv_stable(f1, file.path(out_dir, "drought_palmer_index.csv"))

# ---- Figure 2: Average Drought Conditions Across the Contiguous 48 States According to the SPEI, 1900–2023 ----

f2_path <- file.path(raw_dir, "drought_fig-2.csv")
f2_meta <- read_epa_preamble(f2_path)
f2_raw  <- read_epa_csv(f2_path)

F2_VALUE <- "Five-year SPEI value"

assert_headers(
  f2_raw,
  id_cols          = "Year",
  expected_headers = F2_VALUE,
  what             = "drought_fig-2.csv"
)

# One series, so there is no series column to carry: year and value is the whole
# shape.
f2 <- f2_raw |>
  transmute(year = Year, value = .data[[F2_VALUE]])
f2 <- f2[order(as.integer(f2$year)), ]

assert_conservation(f2_raw, F2_VALUE, nrow(f2), "drought_fig-2.csv")

write_csv_stable(f2, file.path(out_dir, "drought_spei_national.csv"))

# ---- Figure 3: Average Change in Drought (Five-Year SPEI) in the Contiguous 48 States, 1900–2023 ----

f3_path <- file.path(raw_dir, "drought_fig-3.csv")
f3_meta <- read_epa_preamble(f3_path)
f3_raw  <- read_epa_csv(f3_path)

F3_KEY   <- "Climate division"
F3_VALUE <- "Change in five-year SPEI value"

assert_headers(
  f3_raw,
  id_cols          = F3_KEY,
  expected_headers = F3_VALUE,
  what             = "drought_fig-3.csv"
)

# EPA identifies each NOAA climate division as "<division name>_<state code>",
# and several division names carry spaces but none carries an underscore, so the
# final underscore is the split point. The state code is the only part anything
# downstream can group by, which is why it becomes a column of its own rather
# than being parsed out of the key again at draw time.
if (any(!grepl("^.+_[A-Z]{2}$", f3_raw[[F3_KEY]]))) {
  stop(
    "drought_fig-3.csv: climate division keys are no longer '<name>_<state>':\n  ",
    paste(utils::head(grep("^.+_[A-Z]{2}$", f3_raw[[F3_KEY]], invert = TRUE, value = TRUE), 5),
          collapse = "\n  "),
    call. = FALSE
  )
}

f3 <- f3_raw |>
  transmute(
    climate_division = .data[[F3_KEY]],
    division         = sub("_[A-Z]{2}$", "", .data[[F3_KEY]]),
    state            = sub("^.*_", "", .data[[F3_KEY]]),
    value            = .data[[F3_VALUE]]
  )

# Row order is EPA's own, which is alphabetical by key.
stopifnot(
  "drought_fig-3.csv: a climate division key appears twice" = !anyDuplicated(f3$climate_division),
  "drought_fig-3.csv: a state code is not a contiguous-48 postal code" =
    all(f3$state %in% setdiff(state.abb, c("AK", "HI")))
)

assert_conservation(f3_raw, F3_VALUE, nrow(f3), "drought_fig-3.csv")

write_csv_stable(f3, file.path(out_dir, "drought_spei_change.csv"))

# ---- Figure 4: U.S. Lands Under Drought Conditions, 2000-2023 ----

f4_path <- file.path(raw_dir, "drought_fig-4.csv")
f4_meta <- read_epa_preamble(f4_path)
f4_raw  <- read_epa_csv(f4_path)

# D0 through D4, keyed for code and labelled with EPA's own column header. Given
# in increasing severity, which is both the output row order and the order a
# stacked chart reads in; EPA's file has them in the opposite order.
F4_SERIES <- c(
  D0 = "D0 Abnormally dry",
  D1 = "D1 Moderate drought",
  D2 = "D2 Severe drought",
  D3 = "D3 Extreme drought",
  D4 = "D4 Exceptional drought"
)

assert_headers(
  f4_raw,
  id_cols          = c("Month", "Day", "Year"),
  expected_headers = unname(F4_SERIES),
  what             = "drought_fig-4.csv"
)

# The five classes partition the dry area rather than nesting: their sum is the
# share of the country that was at least abnormally dry, which runs 8.5 to 72.4
# percent over 2000-2023 and matches the range EPA's Key Points quote. Reading
# them as cumulative would put that share at 36.6 percent at most.
f4 <- f4_raw |>
  tidyr::pivot_longer(
    cols      = all_of(unname(F4_SERIES)),
    names_to  = "category_label",
    values_to = "value"
  ) |>
  transmute(
    date           = sprintf("%04d-%02d-%02d", as.integer(Year), as.integer(Month), as.integer(Day)),
    category       = names(F4_SERIES)[match(category_label, F4_SERIES)],
    category_label = category_label,
    value          = value
  )
f4 <- f4[order(match(f4$category, names(F4_SERIES)), as.Date(f4$date)), ]

stopifnot(
  "drought_fig-4.csv: a Month/Day/Year triple appears twice" =
    !anyDuplicated(paste(f4$date, f4$category)),
  "drought_fig-4.csv: a date did not format as ISO 8601" =
    all(grepl("^\\d{4}-\\d{2}-\\d{2}$", f4$date))
)

assert_conservation(f4_raw, unname(F4_SERIES), nrow(f4), "drought_fig-4.csv")

write_csv_stable(f4, file.path(out_dir, "drought_monitor_area.csv"))

# ---- Data dictionary ---------------------------------------------------------

meta <- list(
  indicator = INDICATOR,
  datasets = list(
    list(
      file            = "drought_palmer_index.csv",
      figure          = "Figure 1",
      figure_title    = f1_meta$title,
      source_file     = "drought_fig-1.csv",
      source_sha256   = file_sha256(f1_path),
      source_encoding = "windows-1252",
      data_source     = f1_meta$data_source,
      web_update      = f1_meta$web_update,
      unit            = f1_meta$units,
      rows            = nrow(f1),
      columns         = list(
        col("year", "integer", "Calendar year, 1895 through 2023."),
        col("series", "string", "Series key: `annual` for the single-year average, `nine_year` for the nine-year weighted average EPA draws as the thicker line."),
        col("series_label", "string", "EPA's own column header for the series, reproduced verbatim."),
        col("value", "number", "Palmer Drought Severity Index averaged over the whole area of the contiguous 48 states. Zero is the 1931-1990 average, negative is drier, positive is wetter.")
      )
    ),
    list(
      file            = "drought_spei_national.csv",
      figure          = "Figure 2",
      figure_title    = f2_meta$title,
      source_file     = "drought_fig-2.csv",
      source_sha256   = file_sha256(f2_path),
      source_encoding = "UTF-8-BOM",
      data_source     = f2_meta$data_source,
      web_update      = f2_meta$web_update,
      unit            = f2_meta$units,
      rows            = nrow(f2),
      columns         = list(
        col("year", "integer", "Calendar year, 1900 through 2023. The value is the average of the 60 months ending in June of that year."),
        col("value", "number", "Five-year Standardized Precipitation Evapotranspiration Index averaged over the whole area of the contiguous 48 states. Negative is drier than average, positive is wetter.")
      )
    ),
    list(
      file            = "drought_spei_change.csv",
      figure          = "Figure 3",
      figure_title    = f3_meta$title,
      source_file     = "drought_fig-3.csv",
      source_sha256   = file_sha256(f3_path),
      source_encoding = "UTF-8-BOM",
      data_source     = f3_meta$data_source,
      web_update      = f3_meta$web_update,
      unit            = f3_meta$units,
      rows            = nrow(f3),
      columns         = list(
        col("climate_division", "string", "NOAA climate division, keyed as EPA publishes it: division name, underscore, two-letter state code."),
        col("division", "string", "The division-name half of `climate_division`."),
        col("state", "string", "The postal-code half of `climate_division`. All 48 contiguous states appear."),
        col("value", "number", "Total change in the five-year SPEI from 1900 to 2023, from the long-term average rate of change. Positive is increased moisture, negative is drier.")
      )
    ),
    list(
      file            = "drought_monitor_area.csv",
      figure          = "Figure 4",
      figure_title    = f4_meta$title,
      source_file     = "drought_fig-4.csv",
      source_sha256   = file_sha256(f4_path),
      source_encoding = "UTF-8",
      data_source     = f4_meta$data_source,
      web_update      = f4_meta$web_update,
      unit            = f4_meta$units,
      rows            = nrow(f4),
      columns         = list(
        col("date", "date", "The weekly U.S. Drought Monitor issue date, ISO 8601, 2000-01-04 through 2023-12-26."),
        col("category", "string", "U.S. Drought Monitor severity class, D0 through D4."),
        col("category_label", "string", "EPA's own column header for the class, reproduced verbatim."),
        col("value", "number", "Percent of U.S. land area, the 50 states plus Puerto Rico, in that class. The five classes partition the dry area, so their sum is the share that was at least abnormally dry.")
      )
    )
  )
)

write_yaml_stable(meta, file.path(out_dir, "meta.yml"))

# ---- Verify what was written -------------------------------------------------

written <- list.files(out_dir, pattern = "[.](csv|yml)$", full.names = TRUE)
invisible(lapply(written, assert_clean_output))

cat("\nWrote:\n")
for (p in written) {
  cat(sprintf("  %-34s %8d bytes  %s\n", basename(p), file.size(p), substr(file_sha256(p), 1, 12)))
}
