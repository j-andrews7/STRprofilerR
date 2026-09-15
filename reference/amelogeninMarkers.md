# Recognised amelogenin marker names

Amelogenin is a sex-determining marker rather than a polymorphic STR, so
it is excluded from similarity scoring by default. This function returns
the spellings recognised as amelogenin.

## Usage

``` r
amelogeninMarkers()
```

## Value

A character vector of recognised amelogenin marker names.

## Details

The `strprofiler` Python package identifies amelogenin by matching a
single user-supplied column name (`amel_col`, default `"AMEL"`), which
silently fails when a file uses a different spelling. This package
instead classifies every marker at ingest time and records the result in
[`markerData()`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles-accessors.md),
so `AMEL`, `Amel`, and `Amelogenin` all work without configuration.

## See also

[`classifyMarkers()`](https://j-andrews7.github.io/STRprofilerR/reference/classifyMarkers.md),
which uses this to tag markers at ingest.

## Author

Jared Andrews

## Examples

``` r
amelogeninMarkers()
#> [1] "AMEL"       "Amel"       "amel"       "AMELOGENIN" "Amelogenin"
#> [6] "amelogenin" "AMELO"     
```
