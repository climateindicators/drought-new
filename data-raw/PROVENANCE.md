# Provenance

Every file in this directory is reproduced unmodified from EPA's published
indicator page and its per-figure data downloads. To update the data, replace the
file and rerun `Rscript R/build_data.R`.

## Indicator page

- `source-page.html`  \
  <https://19january2025snapshot.epa.gov/climate-indicators/climate-change-indicators-drought/index.html>  \
  sha256 `62571b38f0752336d68621fe7eafca2a5f65677402244c8328db2879259b4646`

Technical documentation: <https://19january2025snapshot.epa.gov/system/files/documents/2024-06/drought_documentation.pdf>

## Figure data

- `drought_fig-1.csv`  \
  <https://19january2025snapshot.epa.gov/system/files/other-files/2024-05/drought_fig-1.csv>  \
  sha256 `a17f2c8f7709336083bc9834c6d519ab289ae7c01fc7ea99e21583e4e1c336c9`  \
  encoding windows-1252, 129 data rows, columns: `Year`, `Annual average`, `9-yr average`  \
  title: Figure 1. Average Drought Conditions in the Contiguous 48 States According to the Palmer Index, 1895–2023  \
  data source: NOAA, 2024; web update: June 2024; units: Palmer Drought Severity Index

- `drought_fig-2.csv`  \
  <https://19january2025snapshot.epa.gov/system/files/other-files/2024-05/drought_fig-2.csv>  \
  sha256 `5e4a2b0a42b2fbd909acb7b062bca21b9a51014e20f9eba70426cc242a8c2d47`  \
  encoding UTF-8-BOM, 124 data rows, columns: `Year`, `Five-year SPEI value`  \
  title: Figure 2. Average Drought Conditions Across the Contiguous 48 States According to the SPEI, 1900–2023  \
  data source: WestWide Drought Tracker, 2024; web update: June 2024; units: SPEI value

- `drought_fig-3.csv`  \
  <https://19january2025snapshot.epa.gov/system/files/other-files/2024-05/drought_fig-3.csv>  \
  sha256 `9812ae4ff2fc1f8bb2be92aec479bc18ef8dd97901f640a379a8ce589802ec17`  \
  encoding UTF-8-BOM, 344 data rows, columns: `Climate division`, `Change in five-year SPEI value`  \
  title: Figure 3. Average Change in Drought (Five-Year SPEI) in the Contiguous 48 States, 1900–2023  \
  data source: WestWide Drought Tracker, 2024; web update: June 2024; units: SPEI value

- `drought_fig-4.csv`  \
  <https://19january2025snapshot.epa.gov/system/files/other-files/2024-05/drought_fig-4.csv>  \
  sha256 `c7977c0f53f1f33f821515d546c18203f5493cbb14fafc64c00f088125312557`  \
  encoding UTF-8, 1252 data rows, columns: `Month`, `Day`, `Year`, `D4 Exceptional drought`, `D3 Extreme drought`, `D2 Severe drought`, `D1 Moderate drought`, `D0 Abnormally dry`  \
  title: Figure 4. U.S. Lands Under Drought Conditions, 2000-2023  \
  data source: National Drought Mitigation Center, 2024; web update: June 2024; units: Percent of U.S. land area
