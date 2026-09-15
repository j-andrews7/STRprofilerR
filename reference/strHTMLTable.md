# Write a data frame as a standalone HTML table

Writes a table to a self-contained HTML file, interactive where the
optional packages allow and static otherwise.

## Usage

``` r
strHTMLTable(x, file, title = "STRprofiler Results")
```

## Arguments

- x:

  A `data.frame`.

- file:

  Path to write to.

- title:

  Page title.

## Value

Invisibly, the path written to.

## Details

When `DT`, `htmlwidgets`, and `pandoc` are all available the table is
written as a `DT` widget: sortable, searchable, and paged. Otherwise a
plain HTML table with embedded styling is written. Both forms are
self-contained and render offline.

## See also

[`writeSTRResults()`](https://j-andrews7.github.io/STRprofilerR/reference/writeSTRResults.md),
which calls this for the summary table.

## Author

Jared Andrews

## Examples

``` r
f <- file.path(tempdir(), "table.html")
strHTMLTable(head(iris), f)
file.exists(f)
#> [1] TRUE
```
