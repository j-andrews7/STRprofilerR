# Score STR profiles against each other

Computes the Tanabe and both Masters similarity scores for every
query/reference pair.

## Usage

``` r
scoreProfiles(
  query,
  reference = NULL,
  useAmel = FALSE,
  excludeMarkers = NULL,
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

- minScore:

  Optional numeric scalar. Drop pairs scoring below this on
  `minScoreType`. Applied per block, so it also bounds memory.

- minScoreType:

  Which score `minScore` applies to.

- chunkSize:

  Number of query profiles to score per block.

## Value

A
[S4Vectors::DataFrame](https://rdrr.io/pkg/S4Vectors/man/DataFrame-class.html)
with one row per scored pair and columns `query`, `reference`,
`nSharedMarkers`, `nSharedAlleles`, `nQueryAlleles`,
`nReferenceAlleles`, `tanabeScore`, `mastersQueryScore`, and
`mastersRefScore`. Rows are ordered by query (input order), then by
Tanabe score descending.

## Details

### The scores

Let \\M\\ be the markers at which *both* profiles were typed (markers
with no alleles in either profile are ignored), \\s\\ the number of
alleles shared across those markers, and \\q\\ and \\r\\ the number of
alleles the query and reference carry across those same markers. Then:

\$\$\textrm{Tanabe} = 100 \times \frac{2s}{q + r}\$\$
\$\$\textrm{Masters (query)} = 100 \times \frac{s}{q}\$\$
\$\$\textrm{Masters (reference)} = 100 \times \frac{s}{r}\$\$

Tanabe is the Sorenson-Dice coefficient and is symmetric. The two
Masters scores are not: Masters (query) asks how much of the query is
explained by the reference, which is the question to ask when the query
may be a contaminated or drifted derivative of a known line.

Amelogenin is a sex marker rather than a polymorphic STR, so it is
excluded by default; set `useAmel = TRUE` to include it.

### Implementation

Scoring is expressed as four sparse matrix products rather than a loop
over pairs, which is what makes whole-database comparison practical.
With \\Q_A\\/\\R_A\\ the binary sample-by-(marker, allele) incidence
matrices, \\Q_M\\/\\R_M\\ the binary sample-by-marker "typed" matrices,
and \\Q_C\\/\\R_C\\ the sample-by-marker allele counts:

    s <- QA %*% t(RA)    # shared alleles
    q <- QC %*% t(RM)    # query alleles,     over shared markers only
    r <- QM %*% t(RC)    # reference alleles, over shared markers only

An allele can only be shared at a marker where both profiles were typed,
so the restriction to shared markers falls out of the products.

Results are computed in blocks of `chunkSize` queries so that comparing
a large batch against a large database does not need the full
query-by-reference matrix in memory at once.

### Divergence from the Python package

A pair with no markers in common gives a zero denominator. `strprofiler`
raises `ZeroDivisionError` (which its Shiny app catches and reports as
`FALSE`); this function returns `NA` for the affected scores and warns
once with a count.

## References

Tanabe H, et al. (1999). Cell line individualization by STR multiplex
system in the cell bank found cross-contamination between ECV304 and
EA.hy926. *Tissue Culture Research Communications* 18:329-338.
[doi:10.11418/jtca1981.18.4_329](https://doi.org/10.11418/jtca1981.18.4_329)

Masters JR, et al. (2001). Short tandem repeat profiling provides an
international reference standard for human cell lines. *PNAS*
98(14):8012-8017.
[doi:10.1073/pnas.121616198](https://doi.org/10.1073/pnas.121616198)

## See also

[`compareProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/compareProfiles.md)
for scoring plus a per-sample summary,
[`summarizeMatches()`](https://j-andrews7.github.io/STRprofilerR/reference/summarizeMatches.md)
to condense the output.

## Author

Jared Andrews

## Examples

``` r
q <- readSTRProfiles(
    system.file("extdata", "ExampleSTR_long.csv", package = "STRprofilerR"),
    sampleCol = "Sample Name"
)
ref <- readSTRProfiles(
    system.file("extdata", "ExampleSTR_database.csv", package = "STRprofilerR"),
    sampleCol = "Sample Name"
)

scores <- scoreProfiles(q, ref)
head(as.data.frame(scores))
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

# All-against-all within one set.
scoreProfiles(ref)[1:3, ]
#> DataFrame with 3 rows and 9 columns
#>         query   reference nSharedMarkers nSharedAlleles nQueryAlleles
#>   <character> <character>      <integer>      <integer>     <integer>
#> 1 Ref_SampleA Ref_SampleB              5              8             8
#> 2 Ref_SampleA Ref_SampleC              5              4             8
#> 3 Ref_SampleA Ref_SampleE              5              3             8
#>   nReferenceAlleles tanabeScore mastersQueryScore mastersRefScore
#>           <integer>   <numeric>         <numeric>       <numeric>
#> 1                10     88.8889             100.0         80.0000
#> 2                 8     50.0000              50.0         50.0000
#> 3                 7     40.0000              37.5         42.8571

# Keep only strong Tanabe hits.
scoreProfiles(q, ref, minScore = 90)
#> DataFrame with 2 rows and 9 columns
#>         query   reference nSharedMarkers nSharedAlleles nQueryAlleles
#>   <character> <character>      <integer>      <integer>     <integer>
#> 1     SampleA Ref_SampleA              5              8             8
#> 2     SampleB Ref_SampleB              5             10            10
#>   nReferenceAlleles tanabeScore mastersQueryScore mastersRefScore
#>           <integer>   <numeric>         <numeric>       <numeric>
#> 1                 8         100               100             100
#> 2                10         100               100             100
```
