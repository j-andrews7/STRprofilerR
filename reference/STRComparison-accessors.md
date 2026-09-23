# Accessors for STRComparison objects

Extract the parts of the
[STRComparison](https://j-andrews7.github.io/STRprofilerR/reference/STRComparison-class.md)
object returned by
[`compareProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/compareProfiles.md).

## Usage

``` r
scores(x, ...)

params(x, ...)

queryProfiles(x, ...)

referenceProfiles(x, ...)

# S4 method for class 'STRComparison'
scores(x, ...)

# S4 method for class 'STRComparison'
params(x, ...)

# S4 method for class 'STRComparison'
queryProfiles(x, ...)

# S4 method for class 'STRComparison'
referenceProfiles(x, ...)

# S4 method for class 'STRComparison'
summary(object, ...)

# S4 method for class 'STRComparison'
show(object)
```

## Arguments

- x, object:

  A
  [STRComparison](https://j-andrews7.github.io/STRprofilerR/reference/STRComparison-class.md)
  object.

- ...:

  Ignored.

## Value

`scores()` returns the pair-level
[S4Vectors::DataFrame](https://rdrr.io/pkg/S4Vectors/man/DataFrame-class.html),
[`summary()`](https://rdrr.io/r/base/summary.html) the per-query one,
`queryProfiles()` and `referenceProfiles()` the
[STRProfiles](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles.md)
that were compared, and `params()` a list of the scoring and threshold
settings used.

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
head(as.data.frame(scores(cmp)))
#>     query   reference nSharedMarkers nSharedAlleles nQueryAlleles
#> 1 SampleA Ref_SampleA              5              8             8
#> 2 SampleA Ref_SampleB              5              8             8
#> 3 SampleA Ref_SampleC              5              4             8
#> 4 SampleA Ref_SampleE              5              3             8
#> 5 SampleA Ref_SampleD              5              2             8
#> 6 SampleB Ref_SampleB              5             10            10
#>   nReferenceAlleles tanabeScore mastersQueryScore mastersRefScore
#> 1                 8   100.00000             100.0       100.00000
#> 2                10    88.88889             100.0        80.00000
#> 3                 8    50.00000              50.0        50.00000
#> 4                 7    40.00000              37.5        42.85714
#> 5                 8    25.00000              25.0        25.00000
#> 6                10   100.00000             100.0       100.00000
params(cmp)$tanThreshold
#> [1] 80
```
