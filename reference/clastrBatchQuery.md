# Query CLASTR in batch and save the XLSX result

Submits several profiles to CLASTR's batch endpoint and writes the
workbook it returns, one sheet per query.

## Usage

``` r
clastrBatchQuery(
  x,
  file,
  algorithm = c("tanabe", "mastersQuery", "mastersRef"),
  scoringMode = c("nonEmpty", "query", "reference"),
  scoreFilter = 80,
  minMarkers = 8,
  maxResults = 200,
  includeAmelogenin = FALSE,
  url = "https://www.cellosaurus.org/str-search/api/batch/"
)
```

## Arguments

- x:

  A
  [STRProfiles](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles.md)
  object, or a named character vector for a single profile.

- file:

  Path to write the XLSX to.

- algorithm:

  Similarity score CLASTR should rank by.

- scoringMode:

  How CLASTR handles markers missing from one side: `"nonEmpty"` uses
  markers present in both, `"query"` all query markers, `"reference"`
  all reference markers.

- scoreFilter:

  Minimum score for a match to be returned.

- minMarkers:

  Minimum number of shared markers for a match to be returned.

- maxResults:

  Maximum number of matches to return per query.

- includeAmelogenin:

  Logical scalar. Include amelogenin in CLASTR's scoring.

- url:

  API endpoint. Exposed for testing.

## Value

Invisibly, the path written to.

## Details

The batch endpoint returns a formatted XLSX rather than JSON, so this is
the route to take when you want CLASTR's own presentation of the
results. Use
[`clastrQuery()`](https://j-andrews7.github.io/STRprofilerR/reference/clastrQuery.md)
instead when you want the hits as data to work with.

This function needs network access, and **is for research use only**.

## See also

[`clastrQuery()`](https://j-andrews7.github.io/STRprofilerR/reference/clastrQuery.md)
for parsed results.

## Author

Jared Andrews

## Examples

``` r
if (FALSE) { # interactive() && requireNamespace("curl", quietly = TRUE) && curl::has_internet()
p <- readSTRProfiles(
    system.file("extdata", "Example_clastr_input.csv", package = "STRprofilerR")
)

out <- file.path(tempdir(), "clastr.xlsx")
clastrBatchQuery(p, out)
}
```
