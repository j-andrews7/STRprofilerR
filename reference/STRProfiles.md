# Build STRProfiles from a data.frame

Constructs a STRProfiles object from a wide `data.frame` already in
memory: one row per sample, one column per marker, alleles as
comma-separated strings. This is the inverse of
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) on a
`STRProfiles` object.

## Usage

``` r
STRProfiles(
  x,
  sampleCol = "Sample",
  pentaFix = TRUE,
  metadataCols = c("Center", "Passage"),
  extraAliases = NULL,
  keepCalls = c("X", "Y")
)
```

## Arguments

- x:

  A `data.frame` with a sample identifier column and one column per
  marker.

- sampleCol:

  Name of the sample identifier column.

- pentaFix:

  Logical scalar. Harmonise the common Penta marker spellings via
  [`markerAliases()`](https://j-andrews7.github.io/STRprofilerR/reference/markerAliases.md).

- metadataCols:

  Character vector of non-marker column names to route into
  [`sampleData()`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles-accessors.md).
  Columns not present in the input are ignored.

- extraAliases:

  Named character vector of additional marker aliases, passed to
  [`harmonizeMarkers()`](https://j-andrews7.github.io/STRprofilerR/reference/markerAliases.md).

- keepCalls:

  Character vector of non-numeric calls that count as alleles, passed to
  [`cleanAlleles()`](https://j-andrews7.github.io/STRprofilerR/reference/cleanAlleles.md)
  and honoured at amelogenin markers only. Defaults to the sex markers
  `X` and `Y`. Every other non-numeric call is an uncallable peak or
  free text, and the per-sample count discarded is recorded in
  [`sampleData()`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles-accessors.md)
  as `nDroppedCalls`.

## Value

A STRProfiles object.

## See also

[`readSTRProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/readSTRProfiles.md)
to read from disk instead.

## Author

Jared Andrews

## Examples

``` r
df <- data.frame(
    Sample = c("Line1", "Line2"),
    AMEL = c("X,Y", "X"),
    vWA = c("16,18", "17"),
    "Penta D" = c("9,10", ""),
    check.names = FALSE
)
p <- STRProfiles(df)
#> Warning: NAs introduced by coercion
p
#> class: STRProfiles
#> samples(2): Line1 Line2
#> markers(3): AMEL vWA PentaD
#> sampleData(1): nDroppedCalls
#> markerClass: amelogenin(1) autosomal(2)
alleles(p)[["PentaD"]]
#> CharacterList of length 2
#> [[1]] 9 10
#> [[2]] character(0)

# Round-trips through as.data.frame().
identical(as.data.frame(STRProfiles(as.data.frame(p))), as.data.frame(p))
#> Warning: NAs introduced by coercion
#> [1] TRUE
```
