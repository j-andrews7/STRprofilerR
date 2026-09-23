# Agent Instructions for STRprofilerR

## Repository Overview

**STRprofilerR** is a port to an R package of the [strprofiler Python package](https://github.com/j-andrews7/STRprofiler).

**Stack**: R 4.6.1+, Shiny, roxygen2 | **Version**: 0.99.1 (dev) | **License**: MIT

## Repository Structure

Targets Bioconductor, so it follows their [contribution guidelines](https://contributions.bioconductor.org/).

```
R/AllClasses.R            STRProfiles + STRComparison S4 classes and validity
R/AllGenerics.R           setGeneric() for every accessor
R/methods-*.R             show, dim, [, $, c, coercion, accessors
R/ingest.R                readSTRProfiles(), STRProfiles(), cleanAlleles()
R/markers.R               markerAliases(), classifyMarkers(), amelogeninMarkers()
R/score.R                 scoreProfiles(), scoreQuery()
R/mixing.R                flagMixedSamples()
R/summarize.R             summarizeMatches()
R/compare.R               compareProfiles() -- the top-level orchestrator
R/report.R                writeSTRResults(), strHTMLTable()
R/clastr.R                CLASTR REST client + JSON parser
exec/strprofiler.R        Rapp CLI (compare / clastr / app)
inst/extdata/             example profiles, databases, a recorded CLASTR response
```

Alleles are stored **pre-split**: each column of the `alleles` slot is a
`CharacterList`. Scoring is vectorised as sparse matrix products (see the
`@details` of `scoreProfiles`), not a loop over pairs -- if you change scoring,
the naive cross-check in `tests/testthat/test-scoring.R` is what guards it.

Deliberate divergences from the Python package are enumerated in `NEWS.md`,
checked against [strprofiler 0.5.0](https://github.com/j-andrews7/STRprofiler/releases/tag/v0.5.0).
Keep that list current when behaviour changes on either side -- an upstream
release can close a divergence or open a new one, and the same claims are
repeated in `README.md`, the `@details` of the affected functions, and a few
test comments.

The Shiny application has **not** been ported; `strprofiler app` says so. It should also cite the [publication](https://pubmed.ncbi.nlm.nih.gov/39589865/) appropriately.

## Build and Validation

### Prerequisites
Use **R 4.6.1** for development/build/test: C:\Program Files\R\R-4.6.1\bin\x64\R.exe

Note `shiny::testServer()` cannot drive a plotly output, so anything downstream of a rendered figure (download handlers, client-side capture) needs a real browser to verify. `chromote` is available for that.

### The Rapp CLI

`exec/strprofiler.R` is a [Rapp](https://github.com/r-lib/Rapp) app. Three things
that are easy to get wrong:

- A bare `x <- NULL` at the top level of a `switch()` branch declares a
  **positional argument**, not a local. Assign from a call or an `if/else`
  instead.
- Option flags are derived verbatim from the variable name. snake_case names
  display as kebab-case in `--help` but also accept the underscore spelling, so
  `sample_col` gives both `--sample-col` and `--sample_col`. camelCase names are
  left alone and give an awkward `--sampleCol`. Use snake_case.
- `exec/` is not under `inst/`, so `system.file("exec", ...)` only resolves once
  the package is installed -- tests fall back to a relative path.

Drive it in development with `Rapp::run("exec/strprofiler.R", c("compare", "--help"))`;
`library(STRprofilerR)` at the top means the package must be installed first.

### Key R Commands
```r
# ALWAYS run after changing roxygen2 comments or function signatures
devtools::document()          # Updates NAMESPACE and .Rd files

# Development
devtools::load_all()          # Load package for testing
devtools::check()             # Run R CMD check
lintr::lint_package()         # Lint code (120 char lines, 4-space indent)

# Building
devtools::build()             # Create .tar.gz
pkgdown::build_site()         # Build documentation website

# Testing
devtools::test()               # Run testthat test suite
```

### Build Commands (Shell)
```bash
R CMD build STRprofilerR                                    # Build package
R CMD check --no-build-vignettes STRprofilerR_*.tar.gz     # Quick check
```

## CI/CD

- **R-CMD-check.yaml** - Runs `R CMD check` on push/PR to main/master.
- **pkgdown.yaml** - Triggers on push/PR to main/master, releases, or manual dispatch. Builds docs website and deploys to gh-pages. Uses `use-public-rspm: true` for fast binary installs on Ubuntu.

## Coding Conventions

### Documentation Requirements
- All exports need complete roxygen2 docs with `@param`, `@return`, `@export`, `@author`, `@examples`
- Reference original plot parameters where applicable
- Document missing/broken plotly functionality explicitly
- Add self-contained, clear examples for functions wherever possible
- Update vignettes when adding new features, or changing existing functionality
- Update `NEWS.md` with new features, bug fixes, etc. Be succinct, most entries should only be a line or two. Minute details need not be added, only key info/rationale. New features, modules, or changes to a development version (i.e. any version with odd minor release version, e.g. 1.1.0) should just be kept up to date rather than appended to given they've not yet been released and changes to them are expected.

### Code Style
4-space indent, 120 char max line, tidyverse style guide, roxygen markdown enabled.
You do not need to specifically lint.

### Dependencies

Anything in Suggests must be reached through `requireNamespace(..., quietly = TRUE)` with a working fallback, and any `@examples` touching one must be wrapped in that check — a check machine may not have the Bioconductor packages.

## Common Issues

| Issue | Solution |
|-------|----------|
| "object not exported by namespace" | Run `devtools::document()` to regenerate NAMESPACE |
| "Non-standard file/directory" in check | Add to .Rbuildignore with regex pattern |
| Vignette build errors | Install: `install.packages(c("knitr", "rmarkdown"))` |

## Critical Rules

1. **NEVER edit NAMESPACE manually** - always use `devtools::document()`
2. **ALWAYS run `devtools::document()`** after changing roxygen2 comments or signatures
3. **Run `devtools::test()`** after changes to verify the testthat test suite passes; also test modules interactively via example apps
4. **Ask user to validate** - rather than trying to run apps yourself continually, just ask user to validate specific changes to save time and tokens

## Best Practices

- Avoid `sapply` usage, it is unsafe in package code.
- Use the r-lsp plugin if available rather than grep and such where possible.

These instructions are a starting point, not an authority — verify against the code before relying on any specific claim here, and correct this file when you find it stale.
