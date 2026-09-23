# Launch the STRprofiler Shiny application

Builds the interactive STRprofiler application, for comparing STR
profiles against a reference database or Cellosaurus from a web browser
without writing any code.

## Usage

``` r
STRprofilerApp(database = NULL, sampleCol = "Sample", markerCol = "Marker")
```

## Arguments

- database:

  The reference database. `NULL`, the default, uses the database bundled
  with the package, of models from The Jackson Laboratory PDX program
  and the NCI Patient-Derived Models Repository. Otherwise a path to a
  file
  [`readSTRProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/readSTRProfiles.md)
  can read, or a
  [STRProfiles](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles.md)
  object.

- sampleCol:

  Name of the sample identifier column, used when reading `database`
  from a file and for every file uploaded in the application.

- markerCol:

  Name of the marker column in wide-layout files, used as `sampleCol`
  is.

## Value

A `shiny.appobj`. Print it, or pass it to
[`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html), to
launch the application.

## Details

The application is a port of the one in the `strprofiler` Python
package, aligned with its 0.5.1 release. It has four tabs:

- Single Query:

  Type a profile in marker by marker and score it against the loaded
  database, or search Cellosaurus with it through CLASTR. The report
  lists every reference passing the chosen score threshold, best first,
  with alleles that differ from the query highlighted.

- Batch Query:

  Upload a file of profiles and compare them against the database,
  against each other ("Within File Query"), or against Cellosaurus.
  Database and within-file searches give one summary row per profile, as
  [`compareProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/compareProfiles.md)
  does.

- Database File Management:

  Swap in a custom reference database for the session, or restore the
  one the application started with.

- Usage Guide:

  How to use the application, and what to cite.

Uploaded files are read with
[`readSTRProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/readSTRProfiles.md),
so they may be csv, tsv, tab-separated txt, or xlsx, in the wide or long
layout.

CLASTR searches need network access. As with the rest of this package,
the application **is for research use only**.

### Deploying

The return value is an ordinary Shiny application object. To host it
with your own database, on Posit Connect or a Shiny Server for example,
deploy an `app.R` containing:

    STRprofilerR::STRprofilerApp(database = "my_database.csv")

From a shell, `strprofiler app --database my_database.csv` runs the same
application locally.

### Divergences from the Python package

Checked against the application in `strprofiler` 0.5.1:

- An upload that fails to load leaves the current database in place.
  `strprofiler` loads its stock database instead, while still displaying
  the failed file's name.

- Changing the batch search type clears the results. `strprofiler`
  re-runs the query, which for CLASTR means an unprompted API call.

- Batch CLASTR results are read from CLASTR's JSON API, shown per
  profile, and downloadable as csv, with CLASTR's own xlsx workbook
  still offered. `strprofiler` reads the workbook back, keying sheets by
  sample name, which fails for names longer than Excel's 31-character
  sheet name limit.

- Uploads may be csv, tsv, txt, or xlsx. `strprofiler`'s upload controls
  accept csv only.

- Single query results show whichever metadata columns the database has.
  `strprofiler` always shows `Center` and `Passage`, empty if the
  database lacks them.

- Amelogenin is recognised under any of the spellings in
  [`amelogeninMarkers()`](https://j-andrews7.github.io/STRprofilerR/reference/amelogeninMarkers.md).
  `strprofiler`'s application only recognises a marker named
  `Amelogenin`.

## References

Andrews JM, Lloyd MW, Neuhauser SB, Bundy M, Jocoy EL, Airhart SD, Bult
CJ, Evrard YA, Chuang JH, Baker S (2024). STRprofiler: efficient
comparisons of short tandem repeat profiles for biomedical model
authentication. *Bioinformatics*, btae713.
[doi:10.1093/bioinformatics/btae713](https://doi.org/10.1093/bioinformatics/btae713)
.

## See also

[`compareProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/compareProfiles.md)
and
[`clastrQuery()`](https://j-andrews7.github.io/STRprofilerR/reference/clastrQuery.md),
which the application calls.

## Author

Jared Andrews

## Examples

``` r
if (requireNamespace("shiny", quietly = TRUE) &&
    requireNamespace("bslib", quietly = TRUE) &&
    requireNamespace("DT", quietly = TRUE)) {
    app <- STRprofilerApp()

    # With a custom database.
    custom <- system.file("extdata", "Example_Custom_Database.csv", package = "STRprofilerR")
    app <- STRprofilerApp(database = custom)

    if (interactive()) {
        shiny::runApp(app)
    }
}
#> Warning: NAs introduced by coercion
#> Warning: NAs introduced by coercion
#> Warning: NAs introduced by coercion
#> Warning: NAs introduced by coercion
#> Warning: NAs introduced by coercion
#> Warning: NAs introduced by coercion
#> Warning: NAs introduced by coercion
#> Warning: NAs introduced by coercion
```
