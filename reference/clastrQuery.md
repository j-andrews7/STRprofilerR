# Query the Cellosaurus knowledge base via CLASTR

Searches the human cell line profiles in
[Cellosaurus](https://www.cellosaurus.org) for matches to one or more
STR profiles, using the [CLASTR REST
API](https://www.cellosaurus.org/str-search/help.html).

## Usage

``` r
clastrQuery(
  x,
  algorithm = c("tanabe", "mastersQuery", "mastersRef"),
  scoringMode = c("nonEmpty", "query", "reference"),
  scoreFilter = 80,
  minMarkers = 8,
  maxResults = 200,
  includeAmelogenin = FALSE,
  url = "https://www.cellosaurus.org/str-search/api/query/"
)
```

## Arguments

- x:

  A
  [STRProfiles](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles.md)
  object, or a named character vector giving one profile's markers and
  comma-separated alleles.

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

A
[S4Vectors::DataFrame](https://rdrr.io/pkg/S4Vectors/man/DataFrame-class.html)
with one row per returned profile and columns `query`, `accession`,
`name`, `species`, `score`, `accessionLink`, `problem`, followed by one
column per marker. Zero rows if nothing matched.

## Details

Each profile is submitted separately and the JSON responses are parsed
into one tidy table, with a `query` column naming the profile each row
answers. A result carrying two profiles (CLASTR returns at most two) is
reported as two rows, with `" (Best)"` and `" (Worst)"` appended to the
accession, as the Python package does.

Marker names are converted to CLASTR's spellings on the way out and back
to this package's on the way in, so `PentaD` round-trips correctly.
Markers CLASTR does not recognise are reported with a warning and
ignored by the search; check ahead of time with
[`validateClastrMarkers()`](https://j-andrews7.github.io/STRprofilerR/reference/clastrMarkers.md).

This function needs network access, and **is for research use only**.

### Divergences from the Python package

The response is parsed directly from the nested JSON rather than through
a flatten-and-pivot chain over generated column names. `algorithm = 3`
is sent for Masters (reference) in batch mode, as `strprofiler` does
from 0.5.0; through 0.4.2 it sent `2`, which silently runs a Masters
(query) search.

## References

Bairoch A (2018). The Cellosaurus, a cell-line knowledge resource.
*Journal of Biomolecular Techniques* 29(2):25-38.
[doi:10.7171/jbt.18-2902-002](https://doi.org/10.7171/jbt.18-2902-002)

Robin T, Capes-Davis A, Bairoch A (2020). CLASTR: The Cellosaurus STR
similarity search tool. *International Journal of Cancer*
146(5):1299-1306.
[doi:10.1002/ijc.32639](https://doi.org/10.1002/ijc.32639)

## See also

[`clastrBatchQuery()`](https://j-andrews7.github.io/STRprofilerR/reference/clastrBatchQuery.md)
for CLASTR's own multi-sheet XLSX output,
[`compareProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/compareProfiles.md)
to compare against a local database instead.

## Author

Jared Andrews

## Examples

``` r
if (FALSE) { # interactive() && requireNamespace("curl", quietly = TRUE) && curl::has_internet()
profile <- c(
    Amelogenin = "X", CSF1PO = "13,14", D5S818 = "13", D7S820 = "8,9",
    D13S317 = "12", FGA = "24", TH01 = "8", TPOX = "11", vWA = "16"
)

hits <- clastrQuery(profile, scoreFilter = 80)
as.data.frame(hits)[, c("accession", "name", "score")]
}
```
