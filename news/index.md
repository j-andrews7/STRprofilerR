# Changelog

## STRprofilerR 0.99.1

- Changes from Bioconductor review:
  - New `pdxSTRProfiles` dataset: the JAX/PDMR reference database,
    ready-read for
    [`compareProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/compareProfiles.md)
    and the default of
    [`STRprofilerApp()`](https://j-andrews7.github.io/STRprofilerR/reference/STRprofilerApp.md).
  - `inst/scripts/` documents the source, generation, and license of
    every file in `inst/extdata/` and `data/`.
  - The example `app.R` for hosting the application moved from `deploy/`
    to `inst/app/app.R`.
  - New vignette section on using STRprofilerR in a larger workflow,
    alongside `SummarizedExperiment` and in pipelines.

## STRprofilerR 0.99.0

- Submitted to Bioconductor.
