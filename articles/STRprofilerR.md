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
[STRprofiler](https://github.com/j-andrews7/STRprofiler) Python package.

**STRprofilerR is intended for research purposes only.** A low score is
a prompt to investigate, not a verdict.

## Installation

You can install **STRprofilerR** from Bioconductor with:

``` r

if (!requireNamespace("BiocManager", quietly = TRUE))
    install.packages("BiocManager")
BiocManager::install("STRprofilerR")

# You can install the development version from Github
pak::pak("j-andrews7/STRprofilerR")
```

## Reading profiles

STR files typically come in one of two shapes (at least from our
facility/platform), and
[`readSTRProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/readSTRProfiles.md)
reads both. A **long** file has one row per sample and one column per
marker:

``` r

library(STRprofilerR)
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
`metadataCols` and they end up in
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

This file is the database the Shiny application uses by default:
profiles of patient-derived models from The Jackson Laboratory PDX
program and the NCI Patient-Derived Models Repository. It’s also
provided as the `pdxSTRProfiles` dataset used [below](#workflow).

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
profiles and the score is unchanged. The Masters scores are not, which
can be useful. Masters (query) asks how much of the query the reference
accounts for, which is useful when a query may be contaminated. A query
containing everything the reference has *plus* extra alleles scores 100
on Masters (reference) while Tanabe drops.

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

The summary carries one row per query - the best two hits, and
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
produces the file set the Python command line tool does, prefixed
`STRprofilerR` rather than `strprofiler`:

``` r

outDir <- file.path(tempdir(), "STRprofilerR-vignette")
written <- writeSTRResults(cmp, outDir)

basename(written)
#> [1] "full_summary.STRprofilerR.20261013.22_11_55.csv" 
#> [2] "SampleA.STRprofilerR.20261013.22_11_55.csv"      
#> [3] "SampleB.STRprofilerR.20261013.22_11_55.csv"      
#> [4] "full_summary.STRprofilerR.20261013.22_11_55.html"
#> [5] "STRprofilerR.20261013.22_11_55.log"
```

That is a summary table, one table per query listing every reference it
was compared against with that reference’s alleles, a self-contained
HTML view of the summary, and a log recording the parameters, inputs,
and versions used.

## Querying Cellosaurus

When you have no local reference for a line,
[CLASTR](https://www.cellosaurus.org/str-search/) searches the human
profiles in Cellosaurus. Check your marker names against its controlled
vocabulary first, as CLASTR silently ignores markers it does not
recognise:

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
strprofilerr compare --database refs.csv -o ./results STR1.xlsx STR2.csv
strprofilerr clastr --score-filter 90 -o ./results batch.csv
strprofilerr app --database refs.csv
strprofilerr compare --help
```

Flags mirror the Python CLI, and both spellings are accepted, so
`--sample-col` and `--sample_col` both work and existing invocations
keep running.

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

From a shell, `strprofilerr app --database our_database.csv` does the
same. To host the application for others, deploy an `app.R` that calls
[`STRprofilerR::STRprofilerApp()`](https://j-andrews7.github.io/STRprofilerR/reference/STRprofilerApp.md)
with your database. One ships with the package, at
`system.file("app", "app.R", package = "STRprofilerR")`.

## STRprofilerR in a larger workflow

STR authentication is rarely an end in itself. It is a quality control
step that decides which models go on into experiments, and its results
belong with the data those experiments produce.

### Bioconductor data structures

`STRProfiles` is built from
*[S4Vectors](https://bioconductor.org/packages/3.23/S4Vectors)* and
*[IRanges](https://bioconductor.org/packages/3.23/IRanges)* classes
rather than bespoke ones.
[`sampleData()`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles-accessors.md),
[`markerData()`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles-accessors.md),
[`scores()`](https://j-andrews7.github.io/STRprofilerR/reference/STRComparison-accessors.md),
and [`summary()`](https://rdrr.io/r/base/summary.html) all return
`DataFrame`s, and each marker’s alleles are a `CharacterList`, so the
usual Bioconductor idioms for subsetting, merging, and list-wise
operations apply. Counting the alleles each sample carries at a marker,
for instance:

``` r

lengths(alleles(batch)[["D5S818"]])
#> [1] 2 3 1
```

### The bundled PDX database

`pdxSTRProfiles` holds 1,258 STR profiles from The Jackson Laboratory
PDX program and the NCI Patient-Derived Models Repository, ready to use
as a reference:

``` r

data(pdxSTRProfiles)
pdxSTRProfiles
#> class: STRProfiles
#> samples(1258): J000077451 J000077591 ... K98450 SA0426
#> markers(18): Amelogenin CSF1PO ... PentaE PentaD
#> sampleData(3): Center Passage nDroppedCalls
#> markerClass: amelogenin(1) autosomal(17)
#> source(1): main_database.csv

pdxCmp <- compareProfiles(batch, pdxSTRProfiles)
as.data.frame(summary(pdxCmp))[, c("Sample", "mixed", "topHit", "nextBest")]
#>            Sample mixed             topHit      nextBest
#> Sample_A Sample_A FALSE J000077451: 100.00 957936: 57.14
#> Sample_B Sample_B FALSE  J000077960: 85.71 193399: 76.00
#> Sample_C Sample_C FALSE J000078366: 100.00 137432: 57.14
```

### Generating profiles from raw data

[`STRProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles.md)
provides the ability to build profiles a `data.frame` already in memory,
such as the result of a LIMS query, an instrument export after some
reshaping, or STR calls made from sequencing data by another tool. It
needs one row per sample and one column per marker, and need not cover
the full panel:

``` r

calls <- data.frame(
    Sample = "PDX_042",
    Amelogenin = "X", CSF1PO = "11", D13S317 = "9,14", D16S539 = "12",
    D18S51 = "17", D21S11 = "29,31", D3S1358 = "15", D5S818 = "11",
    D7S820 = "9,11", D8S1179 = "13,15", FGA = "21,22", TH01 = "9.3",
    TPOX = "8", vWA = "14"
)
newModel <- STRProfiles(calls)

scoreProfiles(newModel, pdxSTRProfiles, minScore = 80)
#> DataFrame with 1 row and 9 columns
#>         query   reference nSharedMarkers nSharedAlleles nQueryAlleles
#>   <character> <character>      <integer>      <integer>     <integer>
#> 1     PDX_042  J000078366             13             18            18
#>   nReferenceAlleles tanabeScore mastersQueryScore mastersRefScore
#>           <integer>   <numeric>         <numeric>       <numeric>
#> 1                18         100               100             100
```

### Carrying authentication info with an experiment

Generally, authentication is frequently performed prior to larger
experiments, and these profiles may be worth carrying along with said
assay data. Recording each sample’s authentication result in the
`colData` of its
*[SummarizedExperiment](https://bioconductor.org/packages/3.23/SummarizedExperiment)*
keeps the quality control with the data, so it survives subsetting and
goes wherever the object goes. The same applies to the `colData` of a
`SingleCellExperiment` or `MultiAssayExperiment`.

In this example, the experiment’s sample sheet records which model each
sample should be, and `Sample_C` has been swapped:

``` r

library(SummarizedExperiment)

# A stand-in for an experiment on the three models in the batch.
counts <- matrix(
    rpois(30, lambda = 50),
    nrow = 10,
    dimnames = list(paste0("gene", 1:10), rownames(batch))
)

se <- SummarizedExperiment(
    assays = list(counts = counts),
    colData = DataFrame(
        model = c("J000077451", "J000077960", "J000077451"),
        row.names = rownames(batch)
    )
)

# Each sample's best match in the reference.
pairs <- scores(pdxCmp)
pairs <- pairs[order(pairs$query, -pairs$tanabeScore), ]
best <- pairs[!duplicated(pairs$query), ]
best <- best[match(colnames(se), best$query), ]

se$strMatch <- best$reference
se$strTanabe <- best$tanabeScore
se$strMixed <- summary(pdxCmp)[colnames(se), "mixed"]
se$authenticated <- se$strMatch == se$model & se$strTanabe >= 80 & !se$strMixed
colData(se)
#> DataFrame with 3 rows and 5 columns
#>                model    strMatch strTanabe  strMixed authenticated
#>          <character> <character> <numeric> <logical>     <logical>
#> Sample_A  J000077451  J000077451  100.0000     FALSE          TRUE
#> Sample_B  J000077960  J000077960   85.7143     FALSE          TRUE
#> Sample_C  J000077451  J000078366  100.0000     FALSE         FALSE

# Keep only authenticated samples for analysis.
se[, se$authenticated]
#> class: SummarizedExperiment 
#> dim: 10 2 
#> metadata(0):
#> assays(1): counts
#> rownames(10): gene1 gene2 ... gene9 gene10
#> rowData names(0):
#> colnames(2): Sample_A Sample_B
#> colData names(5): model strMatch strTanabe strMixed authenticated
```

### Maintaining a reference database

Once a new model is authenticated, its profile could become a reference
for the next batch. [`c()`](https://rdrr.io/r/base/c.html) combines
`STRProfiles` objects, taking the union of their markers, and
[`writeSTRProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/writeSTRProfiles.md)
writes a file that
[`readSTRProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/readSTRProfiles.md),
the command line application’s `--database`, and
[`STRprofilerApp()`](https://j-andrews7.github.io/STRprofilerR/reference/STRprofilerApp.md)
can all read:

``` r

inHouse <- c(pdxSTRProfiles, newModel)
inHouse
#> class: STRProfiles
#> samples(1259): J000077451 J000077591 ... SA0426 PDX_042
#> markers(18): Amelogenin CSF1PO ... PentaE PentaD
#> sampleData(3): Center Passage nDroppedCalls
#> markerClass: amelogenin(1) autosomal(17)
#> source(1): main_database.csv

writeSTRProfiles(inHouse, file.path(tempdir(), "in_house_database.csv"))
```

This makes updating a reference database straightforward.

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
#> [1] stats4    stats     graphics  grDevices utils     datasets  methods  
#> [8] base     
#> 
#> other attached packages:
#>  [1] SummarizedExperiment_1.42.0 Biobase_2.72.0             
#>  [3] GenomicRanges_1.64.0        Seqinfo_1.2.0              
#>  [5] IRanges_2.46.0              S4Vectors_0.50.3           
#>  [7] BiocGenerics_0.58.1         generics_0.1.4             
#>  [9] MatrixGenerics_1.24.0       matrixStats_1.5.0          
#> [11] STRprofilerR_0.99.1         BiocStyle_2.40.0           
#> 
#> loaded via a namespace (and not attached):
#>  [1] sass_0.4.10         SparseArray_1.12.3  lattice_0.22-9     
#>  [4] digest_0.6.39       magrittr_2.0.5      evaluate_1.0.5     
#>  [7] grid_4.6.1          bookdown_0.48       fastmap_1.2.0      
#> [10] cellranger_1.1.0    jsonlite_2.0.0      Matrix_1.7-5       
#> [13] BiocManager_1.30.27 crosstalk_1.2.2     textshaping_1.0.5  
#> [16] jquerylib_0.1.4     abind_1.4-8         cli_3.6.6          
#> [19] rlang_1.3.0         XVector_0.52.0      cachem_1.1.0       
#> [22] DelayedArray_0.38.2 yaml_2.3.12         otel_0.2.0         
#> [25] S4Arrays_1.12.1     tools_4.6.1         DT_0.34.0          
#> [28] vctrs_0.7.3         R6_2.6.1            lifecycle_1.0.5    
#> [31] fs_2.1.0            htmlwidgets_1.6.4   ragg_1.5.2         
#> [34] pkgconfig_2.0.3     desc_1.4.3          pkgdown_2.2.1      
#> [37] bslib_0.12.0        pillar_1.11.1       glue_1.8.1         
#> [40] systemfonts_1.3.2   xfun_0.61           tibble_3.3.1       
#> [43] knitr_1.52          htmltools_0.5.9     rmarkdown_2.32     
#> [46] compiler_4.6.1      readxl_1.5.0.1
```
