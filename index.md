# STRprofilerR

**STRprofilerR** compares short tandem repeat (STR) profiles to
authenticate biomedical models (cell lines, xenografts, organoids)
against the primary tissue they were derived from. It is an R port of
the [strprofiler](https://github.com/j-andrews7/STRprofiler) Python
package.

**STRprofilerR is intended for research purposes only.**

For every profile you provide, STRprofilerR reports three similarity
scores against every other profile:

| Score | Formula | Asks |
|----|----|----|
| [Tanabe](https://doi.org/10.11418/jtca1981.18.4_329) (Sørensen–Dice) | `2 × shared / (query + reference)` | How similar are these two profiles? |
| [Masters (vs. query)](https://doi.org/10.1073/pnas.121616198) | `shared / query` | How much of the query does the reference explain? |
| [Masters (vs. reference)](https://doi.org/10.1073/pnas.121616198) | `shared / reference` | How much of the reference does the query explain? |

Alleles are counted only at markers where *both* profiles were typed.
Amelogenin is excluded by default.

## Installation

``` r

# install.packages("BiocManager")
BiocManager::install("STRprofilerR")

# Or for dev version from GitHub
BiocManager::install("j-andrews7/STRprofilerR")
```

## Quick start

``` r

library(STRprofilerR)

profiles <- readSTRProfiles("STR1.xlsx", sampleCol = "Sample Name")
database <- readSTRProfiles("our_database.csv")

cmp <- compareProfiles(profiles, database)
summary(cmp)

writeSTRResults(cmp, "./results")
```

Compare a batch against itself by leaving `reference` out:

``` r

compareProfiles(profiles)
```

Search Cellosaurus through the
[CLASTR](https://www.cellosaurus.org/str-search/) API:

``` r

clastrQuery(profiles, scoreFilter = 80)
```

## Input formats

Files may be csv, tsv, tab-separated txt, or xlsx, in either layout, and
may be mixed freely in a single call.

**Long** — one row per sample, one column per marker:

| Sample | D1S1656 | DYS391  | D3S1358 | AMEL |
|--------|---------|---------|---------|------|
| Line1  | 12,14   | 12      | 13      | X    |
| Line2  | 12,14   | 11.3,12 | 13,15   | X,Y  |

**Wide** — one row per sample/marker pair, alleles spread across
columns. Any column whose name contains `Allele` is collected; size and
height columns are ignored:

| Sample Name | Marker  | Allele 1 | Size 1 | Allele 2 |
|-------------|---------|----------|--------|----------|
| Sample1     | D3S1358 | 16       | 128.29 | 18       |
| Sample1     | AMEL    | X        | 81.97  |          |

Pass `metadataCols` to keep non-marker columns (`Center` and `Passage`
by default) out of scoring and in
[`sampleData()`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles-accessors.md).

Calls that are not alleles — off-ladder (`OL`), ambiguous (`?`), `NR`,
`ND`, free text — are discarded at ingest, and the per-sample count is
recorded in `sampleData()$nDroppedCalls`. Amelogenin is the one marker
whose calls are letters rather than repeat counts; `keepCalls` says
which letters it accepts, `X` and `Y` by default.

## Command line

The CLI is built on [Rapp](https://github.com/r-lib/Rapp):

``` r

install.packages("Rapp")
Rapp::install_pkg_cli_apps("STRprofilerR")
```

``` bash
strprofiler compare --database refs.csv -o ./results STR1.xlsx STR2.csv
strprofiler clastr --score-filter 90 -o ./results batch.csv
strprofiler app --database refs.csv
strprofiler compare --help
```

Flags mirror the Python CLI. Both `--sample-col` and `--sample_col` are
accepted, so existing invocations keep working.

## Shiny application

The Python package’s Shiny application is included, for single and batch
queries against a reference database or Cellosaurus from a web browser.
It needs the `shiny`, `bslib`, and `DT` packages:

``` r

BiocManager::install(c("shiny", "bslib", "DT"))

STRprofilerR::STRprofilerApp()

# Against your own database instead of the bundled one.
STRprofilerR::STRprofilerApp(database = "our_database.csv")
```

To host it for others, e.g. on Posit Connect or Shiny Server, deploy an
`app.R` containing
`STRprofilerR::STRprofilerApp(database = "our_database.csv")`.

## Alignment with the Python package

STRprofilerR is checked against [`strprofiler`
0.5.1](https://github.com/j-andrews7/STRprofiler/releases/tag/v0.5.1),
whose scoring assertions are ported into the R test suite. They should
agree score-for-score. Deliberate differences are listed in the
documentation of the affected functions, and those of the Shiny
application in
[`?STRprofilerApp`](https://j-andrews7.github.io/STRprofilerR/reference/STRprofilerApp.md).

## Citation

If you use STRprofilerR, please cite the original STRprofiler paper:

> Andrews JM, Lloyd MW, Neuhauser SB, Bundy M, Jocoy EL, Airhart SD,
> Bult CJ, Evrard YA, Chuang JH, Baker S. STRprofiler: efficient
> comparisons of short tandem repeat profiles for biomedical model
> authentication. *Bioinformatics* 2024.
> <https://doi.org/10.1093/bioinformatics/btae713>

If you use the CLASTR functionality, please also cite Cellosaurus and
CLASTR:

> Bairoch A. The Cellosaurus, a cell-line knowledge resource. *J Biomol
> Tech* 2018;29(2):25-38. <https://doi.org/10.7171/jbt.18-2902-002>

> Robin T, Capes-Davis A, Bairoch A. CLASTR: The Cellosaurus STR
> similarity search tool. *Int J Cancer* 2020;146(5):1299-1306.
> <https://doi.org/10.1002/ijc.32639>

## Contributing

Bug reports and feature suggestions are welcome as
[issues](https://github.com/j-andrews7/STRprofilerR/issues); pull
requests are very welcome.

## License

MIT. Released with no warranty for any purpose; the authors retain no
liability for its use.
