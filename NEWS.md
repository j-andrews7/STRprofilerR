# STRprofilerR 0.99.0

First release: an R port of the
[strprofiler](https://github.com/j-andrews7/STRprofiler) Python package,
targeting Bioconductor.

## Features

* `readSTRProfiles()` reads wide and long STR files (csv, tsv, txt, xlsx) into a
  `STRProfiles` S4 object, unioning markers across files and routing `Center`,
  `Passage`, and any other `metadataCols` into `sampleData()` instead of
  treating them as markers.
* `scoreProfiles()` computes the Tanabe and both Masters scores. Scoring is
  expressed as sparse matrix products rather than a loop over pairs, which makes
  whole-database comparison practical; `chunkSize` and `minScore` bound memory
  on large runs.
* `compareProfiles()` combines scoring, mixing detection, and summarisation into
  a `STRComparison` object, which `writeSTRResults()` writes out as the file set
  the Python CLI produces.
* `clastrQuery()` and `clastrBatchQuery()` search Cellosaurus through the CLASTR
  REST API, parsing the nested JSON response directly into a tidy table.
* A command line application built on [Rapp](https://github.com/r-lib/Rapp),
  with `compare` and `clastr` subcommands mirroring the Python CLI's flags.
  Install the launcher with `Rapp::install_pkg_cli_apps("STRprofilerR")`.
* `markerAliases()` makes marker name harmonisation a user-extensible table
  rather than three hard-coded Penta cases, and `classifyMarkers()` tags
  amelogenin and Y-linked markers at ingest so amelogenin exclusion no longer
  depends on matching one configured column name.

## Deliberate differences from the Python package

* Alleles are read as text throughout, so they are never coerced to numbers and
  back. This removes the class of bug `strprofiler` patched twice, where alleles
  ending in zero were truncated (`10` becoming `1`).
* `Center` and `Passage` are sample metadata, not markers. In `strprofiler` they
  reach the scoring routine, so two samples sharing a `Center` score as sharing
  a marker.
* Empty allele tokens are dropped during cleaning. `strprofiler` leaves a
  trailing comma in place and later counts the empty string as an allele.
* Comparisons with no markers in common return `NA` scores and one collated
  warning, rather than raising `ZeroDivisionError`.
* Summaries degrade to `NA` for queries with fewer than two comparisons, where
  `strprofiler` raises an `IndexError`.
* Each of the three match columns is ordered by its own score. `strprofiler`
  orders all three by the Tanabe score.
* `clastrBatchQuery()` sends `algorithm = 3` for Masters (reference);
  `strprofiler` sends `2`, which silently runs a Masters (query) search.
* Output file names are sanitised, so a sample called `HT-29/P3` writes to
  `HT-29_P3.strprofiler.<stamp>.csv`. The name inside the file is untouched.
* HTML output is self-contained rather than loading jQuery and DataTables from a
  CDN at view time.

## Not yet ported

* The Shiny application. `strprofiler app` reports this rather than failing
  obscurely.
