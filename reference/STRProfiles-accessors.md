# Accessors for STRProfiles objects

Extract and replace the parts of a
[STRProfiles](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles.md)
object.

## Usage

``` r
alleles(x, ...)

alleles(x, ...) <- value

markers(x, ...)

markerData(x, ...)

markerData(x, ...) <- value

sampleData(x, ...)

sampleData(x, ...) <- value

provenance(x, ...)

# S4 method for class 'STRProfiles'
alleles(x, ...)

# S4 method for class 'STRProfiles'
alleles(x, ...) <- value

# S4 method for class 'STRProfiles'
markers(x, ...)

# S4 method for class 'STRProfiles'
markerData(x, ...)

# S4 method for class 'STRProfiles'
markerData(x, ...) <- value

# S4 method for class 'STRProfiles'
sampleData(x, ...)

# S4 method for class 'STRProfiles'
sampleData(x, ...) <- value

# S4 method for class 'STRProfiles'
provenance(x, ...)
```

## Arguments

- x:

  A
  [STRProfiles](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles.md)
  object.

- ...:

  Ignored.

- value:

  Replacement value.

## Value

`alleles()` returns a
[S4Vectors::DataFrame](https://rdrr.io/pkg/S4Vectors/man/DataFrame-class.html)
of
[IRanges::CharacterList](https://rdrr.io/pkg/IRanges/man/AtomicList-class.html)
columns, one column per marker.

`markers()` returns a character vector of marker names.

`markerData()` and `sampleData()` return a
[S4Vectors::DataFrame](https://rdrr.io/pkg/S4Vectors/man/DataFrame-class.html)
of marker and sample annotations respectively.

`provenance()` returns a list describing how the object was built.

The replacement forms return an updated
[STRProfiles](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles.md)
object.

## Author

Jared Andrews

## Examples

``` r
f <- system.file("extdata", "ExampleSTR_long.csv", package = "STRprofilerR")
p <- readSTRProfiles(f, sampleCol = "Sample Name")
#> Warning: NAs introduced by coercion

markers(p)
#> [1] "marker1" "marker2" "marker4" "PentaD"  "PentaE"  "AMEL"   
markerData(p)
#> DataFrame with 6 rows and 2 columns
#>               class    nTyped
#>         <character> <integer>
#> marker1   autosomal         2
#> marker2   autosomal         2
#> marker4   autosomal         2
#> PentaD    autosomal         2
#> PentaE    autosomal         2
#> AMEL     amelogenin         2
alleles(p)[["marker1"]]
#> CharacterList of length 2
#> [[1]] 12 14
#> [[2]] 12 14
provenance(p)$timestamp
#> [1] "2026-09-23 21:20:34 UTC"

# Correct a marker classification by hand.
markerData(p)$class[markers(p) == "marker1"] <- "y-linked"
markerData(p)
#> DataFrame with 6 rows and 2 columns
#>               class    nTyped
#>         <character> <integer>
#> marker1    y-linked         2
#> marker2   autosomal         2
#> marker4   autosomal         2
#> PentaD    autosomal         2
#> PentaE    autosomal         2
#> AMEL     amelogenin         2
```
