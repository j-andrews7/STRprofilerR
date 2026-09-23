# Flag potentially mixed samples

Flags samples showing signs of mixing or contamination, based on how
many markers carry more alleles than a single diploid genome can
explain.

## Usage

``` r
flagMixedSamples(x, threeAlleleThreshold = 3)
```

## Arguments

- x:

  A
  [STRProfiles](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles.md)
  object.

- threeAlleleThreshold:

  Number of markers with more than two alleles tolerated before a sample
  is flagged.

## Value

A named logical vector, one element per sample.

## Details

A marker is counted when it has **more than two** alleles. A sample is
flagged when the number of such markers is **strictly greater than**
`threeAlleleThreshold`. With the default of 3, a sample needs four or
more three-allele markers before it is flagged.

This is a screening heuristic, not a test. A flagged sample warrants a
look at its electropherogram; an unflagged one is not evidence of
purity.

## See also

[`compareProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/compareProfiles.md),
which reports this alongside the scores.

## Author

Jared Andrews

## Examples

``` r
p <- readSTRProfiles(
    system.file("extdata", "Example_Batch_File.csv", package = "STRprofilerR")
)
#> Warning: NAs introduced by coercion

flagMixedSamples(p)
#> Sample_A Sample_B Sample_C 
#>    FALSE    FALSE    FALSE 

# A stricter threshold flags fewer samples.
flagMixedSamples(p, threeAlleleThreshold = 5)
#> Sample_A Sample_B Sample_C 
#>    FALSE    FALSE    FALSE 
```
