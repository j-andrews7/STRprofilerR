# Comparing STR profiles with STRprofilerR

## Introduction

Cell lines drift, get mislabelled, and cross-contaminate each other.
Short tandem repeat (STR) profiling is the standard way to catch it:
genotype a panel of highly polymorphic repeat markers, and compare the
result against the material the model was supposed to come from.

**STRprofilerR** compares STR profiles to each other or to a reference
database, scores the similarity three ways, flags samples that look
mixed, and can search the Cellosaurus knowledge base for a match. It is
an R port of the
[strprofiler](https://github.com/j-andrews7/STRprofiler) Python package.

**STRprofilerR is intended for research purposes only.** A low score is
a prompt to investigate, not a verdict.

``` r

library(STRprofilerR)
```

## Reading profiles

STR files typically come in one of two shapes (at least from our
facility/platform), and
[`readSTRProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/readSTRProfiles.md)
reads both. A **long** file has one row per sample and one column per
marker:

``` r

longFile <- system.file("extdata", "ExampleSTR_long.csv", package = "STRprofilerR")
head(read.csv(longFile, check.names = FALSE))
#>   Sample Name marker1  marker2 marker4 Penta D Penta E AMEL
#> 1     SampleA  12, 14       12   13,13    9,10   12,14    X
#> 2     SampleB  12, 14 11.3, 12   13,15    9,10   12,14    X
```

``` r

profiles <- readSTRProfiles(longFile, sampleCol = "Sample Name")
profiles
#> class: STRProfiles
#> samples(2): SampleA SampleB
#> markers(6): marker1 marker2 marker4 PentaD PentaE AMEL
#> sampleData(1): nDroppedCalls
#> markerClass: amelogenin(1) autosomal(5)
#> source(1): ExampleSTR_long.csv
```

A **wide** file has one row per sample/marker pair, with the alleles
spread across numbered columns. Columns whose names contain `Allele` are
collected; size and height columns are ignored. Point `markerCol` at the
column containing marker names and the layout is detected automatically.

Files of either shape, and of any supported format, can be read
together. The marker set is the union across files, and samples missing
a marker are recorded as untyped rather than as having no alleles.
Untyped markers are skipped during scoring rather than counted as
mismatches.

``` r

xlsxFile <- system.file("extdata", "ExampleSTR.xlsx", package = "STRprofilerR")

if (requireNamespace("readxl", quietly = TRUE)) {
    both <- readSTRProfiles(c(longFile, xlsxFile), sampleCol = "Sample Name")
    print(both)
}
#> class: STRProfiles
#> samples(4): SampleA SampleB Sample1 Sample3
#> markers(7): marker1 marker2 ... AMEL marker3
#> sampleData(1): nDroppedCalls
#> markerClass: amelogenin(1) autosomal(6)
#> source(2): ExampleSTR_long.csv ExampleSTR.xlsx
```

### Alleles are stored pre-split

Inside a `STRProfiles` object each marker is a
*[IRanges](https://bioconductor.org/packages/3.23/IRanges)*
`CharacterList`, so the alleles for a sample are already a character
vector rather than a string waiting to be split:

``` r

alleles(profiles)[["marker1"]]
#> CharacterList of length 2
#> [[1]] 12 14
#> [[2]] 12 14
```

Allele calls are cleaned on the way in: duplicates collapse, numeric
alleles sort ahead of string ones, and a trailing `.0` is dropped while
a genuine decimal such as `9.3` is kept.

``` r

cleanAlleles("10.0,10,13,13.0,14,14 ")
#> CharacterList of length 1
#> [[1]] 10 13 14
```

### Marker names

Instruments and databases spell markers inconsistently.
[`markerAliases()`](https://j-andrews7.github.io/STRprofilerR/reference/markerAliases.md)
holds the harmonisation table, applied by default:

``` r

harmonizeMarkers(c("Penta D", "Penta_E", "vWA"))
#> [1] "PentaD" "PentaE" "vWA"
```

Extend it with `extraAliases` when your instrument produces something
the default table does not cover.

Every marker is also classified at ingest, which is how amelogenin is
found without you having to name the column:

``` r

markerData(profiles)
#> DataFrame with 6 rows and 2 columns
#>               class    nTyped
#>         <character> <integer>
#> marker1   autosomal         2
#> marker2   autosomal         2
#> marker4   autosomal         2
#> PentaD    autosomal         2
#> PentaE    autosomal         2
#> AMEL     amelogenin         2
```

### Metadata

Database files often carry non-marker columns. Name them in
`metadataCols` and they fall in
[`sampleData()`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles-accessors.md),
ignored for scoring purposes:

``` r

dbFile <- system.file("extdata", "main_database.csv", package = "STRprofilerR")
reference <- readSTRProfiles(dbFile)

dim(reference)
#> [1] 1258   18
head(sampleData(reference), 3)
#> DataFrame with 3 rows and 3 columns
#>                 Center     Passage nDroppedCalls
#>            <character> <character>     <integer>
#> J000077451         JAX          P0             0
#> J000077591         JAX          P0             0
#> J000077608         JAX          P0             0
```

If using an existing database with extra sample metadata, be sure to set
this so those columns aren’t used in scoring.

## Scoring

Let $`M`$ be the markers where **both** profiles were typed, $`s`$ the
number of alleles they share across those markers, and $`q`$ and $`r`$
the number of alleles each carries across those same markers:

``` math
\textrm{Tanabe} = 100 \times \frac{2s}{q + r}
\qquad
\textrm{Masters (query)} = 100 \times \frac{s}{q}
\qquad
\textrm{Masters (reference)} = 100 \times \frac{s}{r}
```

Tanabe is the Sørensen–Dice coefficient and is symmetric: swap the two
profiles and the score is unchanged. The Masters scores are not, and the
asymmetry is the point. Masters (query) asks how much of the query the
reference accounts for, which is useful when a query may be a
contaminated. A query containing everything the reference has *plus*
extra alleles scores 100 on Masters (reference) while Tanabe drops.

Amelogenin is a sex marker rather than a polymorphic STR, so it is left
out unless you ask for it with `useAmel = TRUE`.

``` r

queries <- readSTRProfiles(longFile, sampleCol = "Sample Name")
refs <- readSTRProfiles(
    system.file("extdata", "ExampleSTR_database.csv", package = "STRprofilerR"),
    sampleCol = "Sample Name"
)

scoreProfiles(queries, refs)
#> DataFrame with 10 rows and 9 columns
#>          query   reference nSharedMarkers nSharedAlleles nQueryAlleles
#>    <character> <character>      <integer>      <integer>     <integer>
#> 1      SampleA Ref_SampleA              5              8             8
#> 2      SampleA Ref_SampleB              5              8             8
#> 3      SampleA Ref_SampleC              5              4             8
#> 4      SampleA Ref_SampleE              5              3             8
#> 5      SampleA Ref_SampleD              5              2             8
#> 6      SampleB Ref_SampleB              5             10            10
#> 7      SampleB Ref_SampleA              5              8            10
#> 8      SampleB Ref_SampleE              5              4            10
#> 9      SampleB Ref_SampleC              5              4            10
#> 10     SampleB Ref_SampleD              5              2            10
#>    nReferenceAlleles tanabeScore mastersQueryScore mastersRefScore
#>            <integer>   <numeric>         <numeric>       <numeric>
#> 1                  8    100.0000             100.0        100.0000
#> 2                 10     88.8889             100.0         80.0000
#> 3                  8     50.0000              50.0         50.0000
#> 4                  7     40.0000              37.5         42.8571
#> 5                  8     25.0000              25.0         25.0000
#> 6                 10    100.0000             100.0        100.0000
#> 7                  8     88.8889              80.0        100.0000
#> 8                  7     47.0588              40.0         57.1429
#> 9                  8     44.4444              40.0         50.0000
#> 10                 8     22.2222              20.0         25.0000
```

Scoring is vectorised as a handful of sparse matrix products rather than
a loop over pairs, so comparing a batch against a database of thousands
is very quick. `chunkSize` controls how many queries are held in memory
at once, and `minScore` discards weak pairs as they are produced:

``` r

scoreProfiles(queries, refs, minScore = 90)
#> DataFrame with 2 rows and 9 columns
#>         query   reference nSharedMarkers nSharedAlleles nQueryAlleles
#>   <character> <character>      <integer>      <integer>     <integer>
#> 1     SampleA Ref_SampleA              5              8             8
#> 2     SampleB Ref_SampleB              5             10            10
#>   nReferenceAlleles tanabeScore mastersQueryScore mastersRefScore
#>           <integer>   <numeric>         <numeric>       <numeric>
#> 1                 8         100               100             100
#> 2                10         100               100             100
```

## Comparing end to end

[`compareProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/compareProfiles.md)
runs scoring, flags mixing, and summarises.

``` r

cmp <- compareProfiles(queries, refs)
cmp
#> class: STRComparison
#> queries(2): SampleA SampleB
#> references(5)
#> comparisons: 10
#> thresholds: tanabe=80 mastersQuery=80 mastersRef=80
#> useAmel: FALSE
#> flagged as mixed: 0
```

The summary carries one row per query — the best two hits, and
everything passing each threshold:

``` r

as.data.frame(summary(cmp))[, c("Sample", "mixed", "topHit", "nextBest")]
#>          Sample mixed              topHit           nextBest
#> SampleA SampleA FALSE Ref_SampleA: 100.00 Ref_SampleB: 88.89
#> SampleB SampleB FALSE Ref_SampleB: 100.00 Ref_SampleA: 88.89
```

Leave `reference` out to compare a batch against itself, dropping
self-comparisons:

``` r

compareProfiles(refs)
#> class: STRComparison
#> queries(5): Ref_SampleA Ref_SampleB Ref_SampleC Ref_SampleD ...
#> references(5)
#> comparisons: 20
#> thresholds: tanabe=80 mastersQuery=80 mastersRef=80
#> useAmel: FALSE
#> flagged as mixed: 0
```

### Mixing

A diploid genome gives at most two alleles per autosomal marker. While
models can get pretty messed up and may occasionally harbor a third
allele, consistently seeing three or more in many markers suggests more
than one genome in the tube.

To help identify such cases, STRprofilerR’s
[`flagMixedSamples()`](https://j-andrews7.github.io/STRprofilerR/reference/flagMixedSamples.md)
counts markers with **more than two** alleles and flags a sample when
that count **exceeds** `threeAlleleThreshold` (3, by default).

``` r

batch <- readSTRProfiles(
    system.file("extdata", "Example_Batch_File.csv", package = "STRprofilerR")
)

flagMixedSamples(batch)
#> Sample_A Sample_B Sample_C 
#>    FALSE    FALSE    FALSE
```

It is worth checking flagged samples more closely.

## Writing results

[`writeSTRResults()`](https://j-andrews7.github.io/STRprofilerR/reference/writeSTRResults.md)
produces the file set the Python command line tool does:

``` r

outDir <- file.path(tempdir(), "strprofiler-vignette")
written <- writeSTRResults(cmp, outDir)

basename(written)
#> [1] "full_summary.strprofiler.20260923.21_56_19.csv" 
#> [2] "SampleA.strprofiler.20260923.21_56_19.csv"      
#> [3] "SampleB.strprofiler.20260923.21_56_19.csv"      
#> [4] "full_summary.strprofiler.20260923.21_56_19.html"
#> [5] "strprofiler.20260923.21_56_19.log"
```

That is a summary table, one table per query listing every reference it
was compared against with that reference’s alleles, a self-contained
HTML view of the summary, and a log recording the parameters, inputs,
and versions used.

## Querying Cellosaurus

When you have no local reference for a line,
[CLASTR](https://www.cellosaurus.org/str-search/) searches the human
profiles in Cellosaurus. Check your marker names against its controlled
vocabulary first — CLASTR silently ignores markers it does not
recognise, which can quietly reduce a search to a handful of markers:

``` r

validateClastrMarkers(markers(refs))
#> [1] "marker1" "marker2" "marker4" "AMEL"
```

The query itself needs network access, so it is not run here:

``` r

profile <- c(
    Amelogenin = "X", CSF1PO = "11,12", D2S1338 = "19,23", D3S1358 = "15,17",
    D5S818 = "11,12", D7S820 = "10", D8S1179 = "10", D13S317 = "11,12",
    D16S539 = "11,12", D18S51 = "13", D19S433 = "14", D21S11 = "29,30",
    FGA = "20,22", PentaD = "11,13", PentaE = "14,16", TH01 = "6,9",
    TPOX = "8,9", vWA = "17,19"
)

hits <- clastrQuery(profile, scoreFilter = 90)
as.data.frame(hits)[, c("accession", "name", "score", "problem")]
```

A cell line with a known contamination history carries a note in
`problem`. A result that CLASTR returns as two profiles appears as two
rows, with `(Best)` and `(Worst)` appended to the accession.

[`clastrBatchQuery()`](https://j-andrews7.github.io/STRprofilerR/reference/clastrBatchQuery.md)
writes CLASTR’s own multi-sheet workbook instead, when you want its
presentation rather than the data.

## The command line application

The CLI is built on [Rapp](https://github.com/r-lib/Rapp). Install the
launcher once:

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

Flags mirror the Python CLI, and both spellings are accepted, so
`--sample-col` and `--sample_col` both work and existing invocations
keep running. During development the app can be driven without
installing a launcher:

``` r

Rapp::run(system.file("exec", "strprofiler.R", package = "STRprofilerR"), "--help")
```

## The Shiny application

For colleagues who would rather not write code,
[`STRprofilerApp()`](https://j-andrews7.github.io/STRprofilerR/reference/STRprofilerApp.md)
serves the same comparisons in a web browser. It is a port of the
`strprofiler` Python package’s application and needs the `shiny`,
`bslib`, and `DT` packages.

``` r

STRprofilerApp()

# Against your own database instead of the bundled one.
STRprofilerApp(database = "our_database.csv")
```

The application has four tabs:

- **Single Query**: type a profile in marker by marker and score it
  against the database or search Cellosaurus with it. Alleles differing
  from the query are highlighted in the report.
- **Batch Query**: upload a file of profiles and compare it against the
  database, within itself, or against Cellosaurus.
- **Database File Management**: swap in a custom database for the
  session.
- **Usage Guide**: how to read the reports, and what to cite.

From a shell, `strprofiler app --database our_database.csv` does the
same. To host the application for others, deploy an `app.R` that calls
[`STRprofilerR::STRprofilerApp()`](https://j-andrews7.github.io/STRprofilerR/reference/STRprofilerApp.md)
with your database. See
[`?STRprofilerApp`](https://j-andrews7.github.io/STRprofilerR/reference/STRprofilerApp.md)
for where it differs from the Python original.

## Session info

``` r

sessionInfo()
#> R version 4.6.1 (2026-06-24)
#> Platform: x86_64-pc-linux-gnu
#> Running under: Ubuntu 24.04.5 LTS
#> 
#> Matrix products: default
#> BLAS:   /usr/lib/x86_64-linux-gnu/openblas-pthread/libblas.so.3 
#> LAPACK: /usr/lib/x86_64-linux-gnu/openblas-pthread/libopenblasp-r0.3.26.so;  LAPACK version 3.12.0
#> 
#> locale:
#>  [1] LC_CTYPE=C.UTF-8       LC_NUMERIC=C           LC_TIME=C.UTF-8       
#>  [4] LC_COLLATE=C.UTF-8     LC_MONETARY=C.UTF-8    LC_MESSAGES=C.UTF-8   
#>  [7] LC_PAPER=C.UTF-8       LC_NAME=C              LC_ADDRESS=C          
#> [10] LC_TELEPHONE=C         LC_MEASUREMENT=C.UTF-8 LC_IDENTIFICATION=C   
#> 
#> time zone: UTC
#> tzcode source: system (glibc)
#> 
#> attached base packages:
#> [1] stats     graphics  grDevices utils     datasets  methods   base     
#> 
#> other attached packages:
#> [1] STRprofilerR_0.99.0 BiocStyle_2.40.0   
#> 
#> loaded via a namespace (and not attached):
#>  [1] Matrix_1.7-5        jsonlite_2.0.0      compiler_4.6.1     
#>  [4] BiocManager_1.30.27 jquerylib_0.1.4     systemfonts_1.3.2  
#>  [7] IRanges_2.46.0      textshaping_1.0.5   yaml_2.3.12        
#> [10] fastmap_1.2.0       readxl_1.5.0.1      lattice_0.22-9     
#> [13] R6_2.6.1            generics_0.1.4      knitr_1.52         
#> [16] BiocGenerics_0.58.1 htmlwidgets_1.6.4   tibble_3.3.1       
#> [19] bookdown_0.48       desc_1.4.3          bslib_0.12.0       
#> [22] pillar_1.11.1       rlang_1.3.0         DT_0.34.0          
#> [25] cachem_1.1.0        xfun_0.61           fs_2.1.0           
#> [28] sass_0.4.10         otel_0.2.0          cli_3.6.6          
#> [31] pkgdown_2.2.1       magrittr_2.0.5      crosstalk_1.2.2    
#> [34] grid_4.6.1          digest_0.6.39       lifecycle_1.0.5    
#> [37] S4Vectors_0.50.3    vctrs_0.7.3         evaluate_1.0.5     
#> [40] glue_1.8.1          cellranger_1.1.0    ragg_1.5.2         
#> [43] stats4_4.6.1        rmarkdown_2.32      tools_4.6.1        
#> [46] pkgconfig_2.0.3     htmltools_0.5.9
```
