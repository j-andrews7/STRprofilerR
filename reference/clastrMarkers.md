# Marker names accepted by the CLASTR API

The controlled vocabulary of marker names the Cellosaurus CLASTR
similarity search accepts, and a helper for checking a profile against
it.

## Usage

``` r
clastrMarkers()

validateClastrMarkers(markers)
```

## Arguments

- markers:

  Character vector of marker names to check.

## Value

`clastrMarkers()` returns the accepted marker names.

`validateClastrMarkers()` returns the subset of `markers` that CLASTR
does not recognise, as a character vector, empty if all are valid.

## Details

CLASTR silently ignores markers it does not recognise, so a profile
using a local marker spelling can be scored on far fewer markers than
intended without any warning. Check first with
`validateClastrMarkers()`.

Note that CLASTR wants the *spaced* Penta spellings (`Penta D`), which
is the opposite of this package's internal convention;
[`clastrQuery()`](https://j-andrews7.github.io/STRprofilerR/reference/clastrQuery.md)
converts them for you via
[`harmonizeMarkers()`](https://j-andrews7.github.io/STRprofilerR/reference/markerAliases.md)
with `reverse = TRUE`.

## References

Robin T, Capes-Davis A, Bairoch A (2020). CLASTR: The Cellosaurus STR
similarity search tool - A precious help for cell line authentication.
*International Journal of Cancer* 146(5):1299-1306.
[doi:10.1002/ijc.32639](https://doi.org/10.1002/ijc.32639)

## See also

[`clastrQuery()`](https://j-andrews7.github.io/STRprofilerR/reference/clastrQuery.md),
which validates automatically before querying.

## Author

Jared Andrews

## Examples

``` r
head(clastrMarkers())
#> [1] "Amel"       "Amelogenin" "CSF1PO"     "D2S1338"    "D3S1358"   
#> [6] "D5S818"    

validateClastrMarkers(c("Amelogenin", "vWA", "marker1", "NotAMarker"))
#> [1] "marker1"    "NotAMarker"
```
