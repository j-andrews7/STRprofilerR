# Summarise pairwise scores into one row per query

Condenses the pair-level output of
[`scoreProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/scoreProfiles.md)
into a per-query overview: the best hits, every hit passing each score
threshold, and an optional mixing flag and copy of the query's alleles.

## Usage

``` r
summarizeMatches(
  scores,
  profiles = NULL,
  tanThreshold = 80,
  masQThreshold = 80,
  masRThreshold = 80,
  threeAlleleThreshold = 3,
  includeAlleles = TRUE
)
```

## Arguments

- scores:

  A
  [S4Vectors::DataFrame](https://rdrr.io/pkg/S4Vectors/man/DataFrame-class.html)
  of pairwise scores from
  [`scoreProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/scoreProfiles.md).

- profiles:

  Optional
  [STRProfiles](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles.md)
  of the query profiles. When supplied, a `mixed` column and the query's
  allele columns are added.

- tanThreshold:

  Minimum Tanabe score to report in `tanabeMatches`.

- masQThreshold:

  Minimum Masters (query) score to report in `mastersQueryMatches`.

- masRThreshold:

  Minimum Masters (reference) score to report in `mastersRefMatches`.

- threeAlleleThreshold:

  Passed to
  [`flagMixedSamples()`](https://j-andrews7.github.io/STRprofilerR/reference/flagMixedSamples.md).
  Ignored when `profiles` is `NULL`.

- includeAlleles:

  Logical scalar. Append the query's allele columns. Ignored when
  `profiles` is `NULL`.

## Value

A
[S4Vectors::DataFrame](https://rdrr.io/pkg/S4Vectors/man/DataFrame-class.html)
with one row per query sample and columns `Sample`, `mixed` (optional),
`topHit`, `nextBest`, `tanabeMatches`, `mastersQueryMatches`,
`mastersRefMatches`, followed by the allele columns.

## Details

Hits are reported as `"name: score"`, joined by `"; "`, with scores
shown to two decimal places. Each of the three match columns is ordered
by its own score, descending. `topHit` and `nextBest` use the Tanabe
score.

If `scores` was filtered (via the `minScore` argument of
[`scoreProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/scoreProfiles.md)),
the summary reflects only the pairs that survived.

### Divergences from the Python package

`strprofiler` reads the top two hits positionally out of a table whose
first row is the query itself, reporting an empty string when a query
has fewer than two comparisons (through 0.4.2 it raised an
`IndexError`). Here a query with no comparisons gets `NA` for both, and
one with a single comparison gets `NA` for `nextBest`.

`strprofiler` orders all three match columns by Tanabe score, so the
Masters columns come out in an order unrelated to their own values. Each
column is sorted on its own score here.

## See also

[`scoreProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/scoreProfiles.md)
to produce `scores`,
[`compareProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/compareProfiles.md)
to do both in one call.

## Author

Jared Andrews

## Examples

``` r
q <- readSTRProfiles(
    system.file("extdata", "ExampleSTR_long.csv", package = "STRprofilerR"),
    sampleCol = "Sample Name"
)
#> Warning: NAs introduced by coercion
ref <- readSTRProfiles(
    system.file("extdata", "ExampleSTR_database.csv", package = "STRprofilerR"),
    sampleCol = "Sample Name"
)
#> Warning: NAs introduced by coercion

scores <- scoreProfiles(q, ref)
summarizeMatches(scores, q)
#> DataFrame with 2 rows and 13 columns
#>              Sample     mixed              topHit           nextBest
#>         <character> <logical>         <character>        <character>
#> SampleA     SampleA     FALSE Ref_SampleA: 100.00 Ref_SampleB: 88.89
#> SampleB     SampleB     FALSE Ref_SampleB: 100.00 Ref_SampleA: 88.89
#>                  tanabeMatches    mastersQueryMatches      mastersRefMatches
#>                    <character>            <character>            <character>
#> SampleA Ref_SampleA: 100.00;.. Ref_SampleA: 100.00;.. Ref_SampleA: 100.00;..
#> SampleB Ref_SampleB: 100.00;.. Ref_SampleB: 100.00;.. Ref_SampleB: 100.00;..
#>             marker1     marker2     marker4      PentaD      PentaE        AMEL
#>         <character> <character> <character> <character> <character> <character>
#> SampleA       12,14          12          13        9,10       12,14           X
#> SampleB       12,14     11.3,12       13,15        9,10       12,14           X

# Scores only, without the mixing flag or alleles.
summarizeMatches(scores)
#> DataFrame with 2 rows and 6 columns
#>              Sample              topHit           nextBest
#>         <character>         <character>        <character>
#> SampleA     SampleA Ref_SampleA: 100.00 Ref_SampleB: 88.89
#> SampleB     SampleB Ref_SampleB: 100.00 Ref_SampleA: 88.89
#>                  tanabeMatches    mastersQueryMatches      mastersRefMatches
#>                    <character>            <character>            <character>
#> SampleA Ref_SampleA: 100.00;.. Ref_SampleA: 100.00;.. Ref_SampleA: 100.00;..
#> SampleB Ref_SampleB: 100.00;.. Ref_SampleB: 100.00;.. Ref_SampleB: 100.00;..
```
