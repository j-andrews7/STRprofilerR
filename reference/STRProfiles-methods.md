# Dimensions, subsetting, and coercion for STRProfiles

Standard R idioms for inspecting and reshaping a
[STRProfiles](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles.md)
object.

## Usage

``` r
# S4 method for class 'STRProfiles'
dim(x)

# S4 method for class 'STRProfiles'
dimnames(x)

# S4 method for class 'STRProfiles,ANY,ANY,ANY'
x[i, j, ..., drop = FALSE]

# S4 method for class 'STRProfiles'
x$name

# S4 method for class 'STRProfiles'
show(object)

# S4 method for class 'STRProfiles'
c(x, ..., recursive = FALSE)

# S4 method for class 'STRProfiles'
as.data.frame(x, row.names = NULL, optional = FALSE, ..., sampleCol = "Sample")
```

## Arguments

- x:

  A
  [STRProfiles](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles.md)
  object.

- i:

  Sample index: names, positions, or a logical vector.

- j:

  Marker index: names, positions, or a logical vector.

- drop:

  Ignored; present for compatibility with the `[` generic.

- name:

  A marker or sample annotation name.

- object:

  A
  [STRProfiles](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles.md)
  object.

- recursive:

  Ignored; present for compatibility with the
  [`c()`](https://rdrr.io/r/base/c.html) generic.

- row.names, optional, ...:

  Passed through to
  [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html).

- sampleCol:

  Name to give the sample identifier column.

## Value

[`dim()`](https://rdrr.io/r/base/dim.html) returns an integer vector of
length two; [`dimnames()`](https://rdrr.io/r/base/dimnames.html) a list
of two character vectors. `[` and [`c()`](https://rdrr.io/r/base/c.html)
return a
[STRProfiles](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles.md)
object. [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html)
returns a `data.frame`. `$` returns the named column of
[`sampleData()`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles-accessors.md).

## Details

A `STRProfiles` object is samples-by-markers, so
[`dim()`](https://rdrr.io/r/base/dim.html) reports
`c(n_samples, n_markers)` and `x[i, j]` subsets samples by `i` and
markers by `j`, both of which accept names, indices, or logical vectors.

[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) flattens
the object back to the wide layout
[`readSTRProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/readSTRProfiles.md)
accepts, with alleles collapsed to comma-separated strings, so profiles
round-trip through disk without loss. Annotations the package computes
at ingest rather than reading from the input — currently `nDroppedCalls`
— are left out, since every column emitted is read back as a marker and
a QC statistic is not one.

## Author

Jared Andrews

## Examples

``` r
f <- system.file("extdata", "ExampleSTR_database.csv", package = "STRprofilerR")
p <- readSTRProfiles(f, sampleCol = "Sample Name")
#> Warning: NAs introduced by coercion

dim(p)
#> [1] 5 6
colnames(p)
#> [1] "marker1" "marker2" "marker4" "PentaD"  "PentaE"  "AMEL"   

# Subset to three samples and drop amelogenin.
sub <- p[1:3, markerData(p)$class != "amelogenin"]
dim(sub)
#> [1] 3 5

as.data.frame(sub)
#>        Sample marker1 marker2 marker4 PentaD PentaE
#> 1 Ref_SampleA   12,14      12      13   9,10  12,14
#> 2 Ref_SampleB   12,14 11.3,12   13,15   9,10  12,14
#> 3 Ref_SampleC   10,15   11,12      10     10  12,14
```
