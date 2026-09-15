# Score a single profile against a reference set

A convenience wrapper around
[`scoreProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/scoreProfiles.md)
for scoring one hand-entered profile, as an interactive session or a
query form would.

## Usage

``` r
scoreQuery(
  x,
  reference,
  sample = "Query",
  useAmel = FALSE,
  excludeMarkers = NULL,
  pentaFix = TRUE
)
```

## Arguments

- x:

  A named character vector or list mapping marker names to
  comma-separated allele calls.

- reference:

  A
  [STRProfiles](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles.md)
  object to score against.

- sample:

  Name to label the query with.

- useAmel:

  Logical scalar. Include amelogenin markers in scoring.

- excludeMarkers:

  Character vector of additional marker names to leave out of scoring.

- pentaFix:

  Logical scalar. Harmonise Penta marker spellings in `x`.

## Value

A
[S4Vectors::DataFrame](https://rdrr.io/pkg/S4Vectors/man/DataFrame-class.html)
as returned by
[`scoreProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/scoreProfiles.md).

## See also

[`scoreProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/scoreProfiles.md),
which this calls.

## Author

Jared Andrews

## Examples

``` r
ref <- readSTRProfiles(
    system.file("extdata", "ExampleSTR_database.csv", package = "STRprofilerR"),
    sampleCol = "Sample Name"
)

scoreQuery(
    c(marker1 = "12,14", marker2 = "12", marker4 = "13", AMEL = "X"),
    ref
)
#> DataFrame with 5 rows and 9 columns
#>         query   reference nSharedMarkers nSharedAlleles nQueryAlleles
#>   <character> <character>      <integer>      <integer>     <integer>
#> 1       Query Ref_SampleA              3              4             4
#> 2       Query Ref_SampleB              3              4             4
#> 3       Query Ref_SampleE              3              2             4
#> 4       Query Ref_SampleC              3              1             4
#> 5       Query Ref_SampleD              3              1             4
#>   nReferenceAlleles tanabeScore mastersQueryScore mastersRefScore
#>           <integer>   <numeric>         <numeric>       <numeric>
#> 1                 4    100.0000               100        100.0000
#> 2                 6     80.0000               100         66.6667
#> 3                 4     50.0000                50         50.0000
#> 4                 5     22.2222                25         20.0000
#> 5                 6     20.0000                25         16.6667
```
