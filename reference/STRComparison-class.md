# STRComparison: the result of comparing STR profiles

An S4 container returned by
[`compareProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/compareProfiles.md),
holding every pairwise score alongside a per-query summary and the
parameters used to produce them.

## Value

An object of class `STRComparison`.

## Slots

- `scores`:

  A
  [S4Vectors::DataFrame](https://rdrr.io/pkg/S4Vectors/man/DataFrame-class.html)
  with one row per query/reference pair.

- `summary`:

  A
  [S4Vectors::DataFrame](https://rdrr.io/pkg/S4Vectors/man/DataFrame-class.html)
  with one row per query sample.

- `query`:

  The query
  [STRProfiles](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles.md).

- `reference`:

  The reference
  [STRProfiles](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles.md).
  Identical to `query` for an all-against-all comparison.

- `params`:

  A list of the scoring and threshold parameters used.

## See also

[`compareProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/compareProfiles.md)
to build one,
[`writeSTRResults()`](https://j-andrews7.github.io/STRprofilerR/reference/writeSTRResults.md)
to write it out.

## Author

Jared Andrews

## Examples

``` r
f <- system.file("extdata", "ExampleSTR_long.csv", package = "STRprofilerR")
db <- system.file("extdata", "ExampleSTR_database.csv", package = "STRprofilerR")
cmp <- compareProfiles(
    readSTRProfiles(f, sampleCol = "Sample Name"),
    readSTRProfiles(db, sampleCol = "Sample Name")
)
cmp
#> class: STRComparison
#> queries(2): SampleA SampleB
#> references(5)
#> comparisons: 10
#> thresholds: tanabe=80 mastersQuery=80 mastersRef=80
#> useAmel: FALSE
#> flagged as mixed: 0
```
