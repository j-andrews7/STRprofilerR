# Classify STR markers

Tags each marker as amelogenin, Y-linked, or autosomal. The
classification is stored in the `class` column of
[`markerData()`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles-accessors.md)
and is what
[`scoreProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/scoreProfiles.md)
uses to decide which markers to drop from scoring.

## Usage

``` r
classifyMarkers(markers)
```

## Arguments

- markers:

  Character vector of marker names.

## Value

A character vector the same length as `markers`, with values
`"amelogenin"`, `"y-linked"`, or `"autosomal"`.

## Details

Y-linked markers are recognised by a `DYS` prefix (for example
`DYS391`). Everything that is neither amelogenin nor Y-linked is
reported as `"autosomal"`; the classification is a naming heuristic, not
a lookup against a curated marker panel, so unusual marker names may
need correcting by hand via `markerData(x)$class <- ...`.

## Author

Jared Andrews

## Examples

``` r
classifyMarkers(c("AMEL", "DYS391", "vWA", "PentaD"))
#> [1] "amelogenin" "y-linked"   "autosomal"  "autosomal" 
```
