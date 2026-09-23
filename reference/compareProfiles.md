# Compare STR profiles end to end

Scores profiles, flags potential mixing, and summarises the hits in one
call. This is the R equivalent of the Python package's
`strprofiler compare` command, minus the file writing, which
[`writeSTRResults()`](https://j-andrews7.github.io/STRprofilerR/reference/writeSTRResults.md)
handles.

## Usage

``` r
compareProfiles(
  query,
  reference = NULL,
  useAmel = FALSE,
  excludeMarkers = NULL,
  tanThreshold = 80,
  masQThreshold = 80,
  masRThreshold = 80,
  threeAlleleThreshold = 3,
  minScore = NULL,
  minScoreType = c("tanabe", "mastersQuery", "mastersRef"),
  chunkSize = 2000L
)
```

## Arguments

- query:

  A
  [STRProfiles](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles.md)
  object holding the profiles to score.

- reference:

  A
  [STRProfiles](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles.md)
  object to score against. If `NULL`, `query` is compared against itself
  and self-pairs are dropped.

- useAmel:

  Logical scalar. Include amelogenin markers in scoring.

- excludeMarkers:

  Character vector of additional marker names to leave out of scoring.

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

- minScore:

  Optional numeric scalar. Drop pairs scoring below this on
  `minScoreType`. Applied per block, so it also bounds memory.

- minScoreType:

  Which score `minScore` applies to.

- chunkSize:

  Number of query profiles to score per block.

## Value

A
[STRComparison](https://j-andrews7.github.io/STRprofilerR/reference/STRComparison-class.md)
object.

## Details

With `reference` supplied, each query is compared against the reference
set only, never against the other queries. This is the "batch against
database" mode. With `reference = NULL`, queries are compared against
each other and self-comparisons are dropped.

Unlike `strprofiler`, this returns an object rather than writing files,
so results can be inspected, filtered, or plotted before anything is
committed to disk. Pass the result to
[`writeSTRResults()`](https://j-andrews7.github.io/STRprofilerR/reference/writeSTRResults.md)
to produce the same file set the Python CLI does.

## See also

[`scoreProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/scoreProfiles.md)
and
[`summarizeMatches()`](https://j-andrews7.github.io/STRprofilerR/reference/summarizeMatches.md)
for the individual steps,
[`writeSTRResults()`](https://j-andrews7.github.io/STRprofilerR/reference/writeSTRResults.md)
to write the output files.

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

cmp <- compareProfiles(q, ref)
cmp
#> class: STRComparison
#> queries(2): SampleA SampleB
#> references(5)
#> comparisons: 10
#> thresholds: tanabe=80 mastersQuery=80 mastersRef=80
#> useAmel: FALSE
#> flagged as mixed: 0
summary(cmp)
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

# All-against-all within a single set.
compareProfiles(ref)
#> class: STRComparison
#> queries(5): Ref_SampleA Ref_SampleB Ref_SampleC Ref_SampleD ...
#> references(5)
#> comparisons: 20
#> thresholds: tanabe=80 mastersQuery=80 mastersRef=80
#> useAmel: FALSE
#> flagged as mixed: 0
```
