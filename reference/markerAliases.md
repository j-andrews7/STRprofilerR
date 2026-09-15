# Marker name harmonisation

STR marker names are spelled inconsistently across instruments, vendors,
and databases. `markerAliases()` returns the alias table used to
harmonise them, and `harmonizeMarkers()` applies it to a vector of
marker names.

## Usage

``` r
markerAliases(reverse = FALSE, extra = NULL)

harmonizeMarkers(markers, reverse = FALSE, extra = NULL)
```

## Arguments

- reverse:

  Logical scalar. If `TRUE`, return the inverse table mapping compact
  spellings onto the spaced spellings expected by CLASTR.

- extra:

  Named character vector of additional aliases, where names are the
  aliases to replace and values are the canonical names to use.

- markers:

  Character vector of marker names to harmonise.

## Value

`markerAliases()` returns a named character vector whose names are
aliases and whose values are canonical marker names.

`harmonizeMarkers()` returns a character vector of the same length as
`markers`, with any recognised aliases replaced.

## Details

The default table resolves the common Penta marker spellings (`Penta C`,
`Penta_C`, and so on) onto the compact forms (`PentaC`) used throughout
this package. This generalises the hard-coded `_pentafix()` helper in
the `strprofiler` Python package: pass `extra` to harmonise any other
marker names your instrument produces.

The CLASTR API expects the *spaced* spellings, so `reverse = TRUE`
inverts the table for outbound queries.

## Author

Jared Andrews

## Examples

``` r
markerAliases()
#>  Penta C  Penta_C  Penta-C  Penta D  Penta_D  Penta-D  Penta E  Penta_E 
#> "PentaC" "PentaC" "PentaC" "PentaD" "PentaD" "PentaD" "PentaE" "PentaE" 
#>  Penta-E 
#> "PentaE" 

harmonizeMarkers(c("Penta D", "Penta_E", "vWA"))
#> [1] "PentaD" "PentaE" "vWA"   

# The CLASTR API wants the spaced spellings back.
harmonizeMarkers(c("PentaD", "PentaE"), reverse = TRUE)
#> [1] "Penta D" "Penta E"

# Harmonise a vendor-specific spelling too.
harmonizeMarkers("AMELOGENIN", extra = c(AMELOGENIN = "AMEL"))
#> [1] "AMEL"
```
