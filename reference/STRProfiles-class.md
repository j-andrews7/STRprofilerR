# STRProfiles: a set of short tandem repeat profiles

An S4 container holding STR profiles for a set of samples, the markers
they were typed at, per-sample metadata, and a record of how the object
was built.

## Value

An object of class `STRProfiles`.

## Details

Alleles are stored **pre-split**: each column of the `alleles` slot is
an
[IRanges::CharacterList](https://rdrr.io/pkg/IRanges/man/AtomicList-class.html)
whose i-th element is the character vector of unique alleles called for
sample i at that marker. A sample that was not typed at a marker has a
zero-length entry.

This is the main structural departure from the `strprofiler` Python
package, which stores comma-joined strings and re-splits them on every
single pairwise comparison. Splitting once at ingest is what lets
[`scoreProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/scoreProfiles.md)
express scoring as a handful of sparse matrix products.

Build one with
[`readSTRProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/readSTRProfiles.md)
(from files) or
[`STRProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles.md)
(from a `data.frame` already in memory).

## Slots

- `alleles`:

  A
  [S4Vectors::DataFrame](https://rdrr.io/pkg/S4Vectors/man/DataFrame-class.html)
  with one row per sample and one column per marker. Every column is a
  [IRanges::CharacterList](https://rdrr.io/pkg/IRanges/man/AtomicList-class.html).

- `markerData`:

  A
  [S4Vectors::DataFrame](https://rdrr.io/pkg/S4Vectors/man/DataFrame-class.html)
  with one row per marker, row names matching `colnames(alleles)`.
  Always carries a `class` column (see
  [`classifyMarkers()`](https://j-andrews7.github.io/STRprofilerR/reference/classifyMarkers.md))
  and an `nTyped` column.

- `sampleData`:

  A
  [S4Vectors::DataFrame](https://rdrr.io/pkg/S4Vectors/man/DataFrame-class.html)
  with one row per sample, row names matching `rownames(alleles)`. Holds
  non-marker columns such as `Center` and `Passage`.

- `provenance`:

  A list recording the source files, ingest options, timestamp, and
  package version.

## See also

[`readSTRProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/readSTRProfiles.md)
to build one,
[`scoreProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/scoreProfiles.md)
to compare them.

## Author

Jared Andrews

## Examples

``` r
f <- system.file("extdata", "ExampleSTR_long.csv", package = "STRprofilerR")
p <- readSTRProfiles(f, sampleCol = "Sample Name")
p
#> class: STRProfiles
#> samples(2): SampleA SampleB
#> markers(6): marker1 marker2 marker4 PentaD PentaE AMEL
#> sampleData(0):
#> markerClass: amelogenin(1) autosomal(5)
#> source(1): ExampleSTR_long.csv
```
