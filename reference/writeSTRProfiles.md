# Write STR profiles to file

Writes a
[STRProfiles](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles.md)
object to a CSV in the wide layout that
[`readSTRProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/readSTRProfiles.md)
reads back, with alleles collapsed to comma-separated strings.

## Usage

``` r
writeSTRProfiles(x, file, sampleCol = "Sample")
```

## Arguments

- x:

  A
  [STRProfiles](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles.md)
  object.

- file:

  Path to write to.

- sampleCol:

  Name to give the sample identifier column.

## Value

Invisibly, the path written to.

## Author

Jared Andrews

## Examples

``` r
db <- system.file("extdata", "ExampleSTR_database.csv", package = "STRprofilerR")
p <- readSTRProfiles(db, sampleCol = "Sample Name")
#> Warning: NAs introduced by coercion

out <- file.path(tempdir(), "profiles.csv")
writeSTRProfiles(p, out)
head(read.csv(out, check.names = FALSE))
#>        Sample marker1 marker2 marker4 PentaD PentaE AMEL
#> 1 Ref_SampleA   12,14      12      13   9,10  12,14    X
#> 2 Ref_SampleB   12,14 11.3,12   13,15   9,10  12,14    X
#> 3 Ref_SampleC   10,15   11,12      10     10  12,14    X
#> 4 Ref_SampleD    9,16   10,12   10,14     12     12    X
#> 5 Ref_SampleE      14      13   13,15     13  12,15  X,Y
```
