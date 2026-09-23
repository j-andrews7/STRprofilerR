# Read STR profiles from file

Reads one or more STR profile files, in either wide or long layout, into
a single
[STRProfiles](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles.md)
object.

## Usage

``` r
readSTRProfiles(
  files,
  sampleCol = "Sample",
  markerCol = "Marker",
  sampleMap = NULL,
  pentaFix = TRUE,
  metadataCols = c("Center", "Passage"),
  format = c("auto", "wide", "long"),
  extraAliases = NULL,
  keepCalls = c("X", "Y")
)
```

## Arguments

- files:

  Character vector of paths. Supported extensions are `csv`, `tsv`,
  `txt` (tab-separated), and `xlsx` (first sheet; needs `readxl`).

- sampleCol:

  Name of the sample identifier column.

- markerCol:

  Name of the marker identifier column. Used only for wide files.

- sampleMap:

  Optional sample renaming table: either a path to a headerless
  two-column CSV, or a `data.frame`/`matrix` with at least two columns.
  The first column holds names as they appear in the input, the second
  the names to use instead.

- pentaFix:

  Logical scalar. Harmonise the common Penta marker spellings via
  [`markerAliases()`](https://j-andrews7.github.io/STRprofilerR/reference/markerAliases.md).

- metadataCols:

  Character vector of non-marker column names to route into
  [`sampleData()`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles-accessors.md).
  Columns not present in the input are ignored.

- format:

  One of `"auto"`, `"wide"`, or `"long"`. Applied to every file.

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

A
[STRProfiles](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles.md)
object.

## Details

### Layouts

**Long** files carry one row per sample, with every column other than
the sample column (and any `metadataCols`) treated as a marker:

    Sample,  D1S1656, DYS391, AMEL
    Line1,   "12,14", 12,     X

**Wide** files carry one row per sample/marker pair, with the alleles
spread across several columns. Any column whose name contains `Allele`
is collected; size and height columns are ignored:

    Sample, Marker,  Allele 1, Size 1, Allele 2
    Line1,  D3S1358, 16,       128.29, 18

With `format = "auto"` a file is read as wide when it has a `markerCol`
column *and* at least one column containing `Allele`, and long
otherwise.

### Combining files

Files may mix layouts and formats. Markers are unioned across files,
with samples missing a marker recorded as untyped rather than as an
empty allele. Sample names must be unique across all files.

### Divergences from the Python package

`metadataCols` are held in
[`sampleData()`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles-accessors.md)
rather than alongside the markers. `strprofiler` 0.5.0 carries them in
the profile and skips them at scoring and mixing time, so a custom
metadata column has to be declared to each of those functions rather
than once at ingest. (Through 0.4.2 it had no such argument, and two
samples sharing a `Center` of `"JAX"` scored as sharing a marker.)

Row order follows the input files. `strprofiler` returns wide-format
samples in sorted order because it groups with `pandas`.

All columns are read as text, so alleles are never coerced to numbers
and back. This removes a class of bug that `strprofiler` patched twice
through 0.4.2 (alleles ending in zero being truncated, for example `10`
becoming `1`); 0.5.0 instead parses every call and renders it back.

## See also

[`STRProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles.md)
to build one from an in-memory `data.frame`,
[`scoreProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/scoreProfiles.md)
to compare the result.

## Author

Jared Andrews

## Examples

``` r
long <- system.file("extdata", "ExampleSTR_long.csv", package = "STRprofilerR")
p <- readSTRProfiles(long, sampleCol = "Sample Name")
p
#> class: STRProfiles
#> samples(2): SampleA SampleB
#> markers(6): marker1 marker2 marker4 PentaD PentaE AMEL
#> sampleData(1): nDroppedCalls
#> markerClass: amelogenin(1) autosomal(5)
#> source(1): ExampleSTR_long.csv

# Penta spellings are harmonised by default.
markers(p)
#> [1] "marker1" "marker2" "marker4" "PentaD"  "PentaE"  "AMEL"   
markers(readSTRProfiles(long, sampleCol = "Sample Name", pentaFix = FALSE))
#> [1] "marker1" "marker2" "marker4" "Penta D" "Penta E" "AMEL"   

# A database file with Center and Passage metadata.
db <- system.file("extdata", "main_database.csv", package = "STRprofilerR")
ref <- readSTRProfiles(db)
sampleData(ref)[1:3, ]
#> DataFrame with 3 rows and 3 columns
#>                 Center     Passage nDroppedCalls
#>            <character> <character>     <integer>
#> J000077451         JAX          P0             0
#> J000077591         JAX          P0             0
#> J000077608         JAX          P0             0

# Rename samples on the way in.
smap <- system.file("extdata", "SampleMap_exp.csv", package = "STRprofilerR")
xlsx <- system.file("extdata", "ExampleSTR.xlsx", package = "STRprofilerR")
if (requireNamespace("readxl", quietly = TRUE)) {
    rownames(readSTRProfiles(xlsx, sampleCol = "Sample Name", sampleMap = smap))
}
#> [1] "Sample1"  "Sample33"
```
