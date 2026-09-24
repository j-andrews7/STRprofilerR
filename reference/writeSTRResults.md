# Write comparison results to disk

Writes a
[STRComparison](https://j-andrews7.github.io/STRprofilerR/reference/STRComparison-class.md)
out as the file set the `strprofiler` command line tool produces: a
summary table, one table per query sample, an HTML view of the summary,
and a log recording the parameters used.

## Usage

``` r
writeSTRResults(
  x,
  dir,
  formats = c("csv", "html"),
  perSample = TRUE,
  timestamp = Sys.time(),
  prefix = "STRprofilerR"
)
```

## Arguments

- x:

  A
  [STRComparison](https://j-andrews7.github.io/STRprofilerR/reference/STRComparison-class.md)
  object.

- dir:

  Directory to write into. Created if it does not exist.

- formats:

  Which outputs to write. Any of `"csv"`, `"html"`, and `"xlsx"`. The
  `xlsx` summary needs the `writexl` package.

- perSample:

  Logical scalar. Write the per-query comparison tables. Ignored unless
  `"csv"` is in `formats`.

- timestamp:

  A `POSIXct` used to stamp the file names.

- prefix:

  File name prefix.

## Value

Invisibly, a named character vector of the paths written.

## Details

Files are named with an `STRprofilerR` prefix where the Python package
uses `strprofiler`, so results from the two are distinguishable.

Written into `dir`, with `<stamp>` a `YYYYMMDD.HH_MM_SS` timestamp:

- `full_summary.STRprofilerR.<stamp>.csv`:

  One row per query: the mixing flag, top two hits, and every hit
  passing each threshold.

- `<sample>.STRprofilerR.<stamp>.csv`:

  One file per query, listing every reference it was compared against
  with the scores and that reference's alleles. The query itself is the
  first row.

- `full_summary.STRprofilerR.<stamp>.html`:

  The summary as a browsable table.

- `STRprofilerR.<stamp>.log`:

  Parameters, input files, and package and R versions.

Sample names are sanitised for use as file names, so a query called
`HT-29/P3` is written as `HT-29_P3.STRprofilerR.<stamp>.csv`. The name
inside the file is untouched.

The HTML is written with `DT` when `DT`, `htmlwidgets`, and `pandoc` are
all available, giving a sortable, searchable, self-contained table.
Otherwise a plain styled HTML table is written instead. Either way the
file stands alone, unlike the Python package's output, which pulls
jQuery and DataTables from a CDN at view time.

## See also

[`compareProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/compareProfiles.md)
to produce `x`.

## Author

Jared Andrews

## Examples

``` r
q <- readSTRProfiles(
    system.file("extdata", "ExampleSTR_long.csv", package = "STRprofilerR"),
    sampleCol = "Sample Name"
)
ref <- readSTRProfiles(
    system.file("extdata", "ExampleSTR_database.csv", package = "STRprofilerR"),
    sampleCol = "Sample Name"
)

out <- file.path(tempdir(), "STRprofilerR-demo")
written <- writeSTRResults(compareProfiles(q, ref), out)
basename(written)
#> [1] "full_summary.STRprofilerR.20260924.19_58_13.csv" 
#> [2] "SampleA.STRprofilerR.20260924.19_58_13.csv"      
#> [3] "SampleB.STRprofilerR.20260924.19_58_13.csv"      
#> [4] "full_summary.STRprofilerR.20260924.19_58_13.html"
#> [5] "STRprofilerR.20260924.19_58_13.log"              
```
