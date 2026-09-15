# Package index

## Reading and writing profiles

Getting STR profiles in and out of a STRProfiles object.

- [`readSTRProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/readSTRProfiles.md)
  : Read STR profiles from file
- [`STRProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles.md)
  : Build STRProfiles from a data.frame
- [`writeSTRProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/writeSTRProfiles.md)
  : Write STR profiles to file
- [`cleanAlleles()`](https://j-andrews7.github.io/STRprofilerR/reference/cleanAlleles.md)
  : Clean and split a vector of allele calls

## The STRProfiles class

- [`STRProfiles-class`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles-class.md)
  : STRProfiles: a set of short tandem repeat profiles
- [`alleles()`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles-accessors.md)
  [`` `alleles<-`() ``](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles-accessors.md)
  [`markers()`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles-accessors.md)
  [`markerData()`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles-accessors.md)
  [`` `markerData<-`() ``](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles-accessors.md)
  [`sampleData()`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles-accessors.md)
  [`` `sampleData<-`() ``](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles-accessors.md)
  [`provenance()`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles-accessors.md)
  : Accessors for STRProfiles objects
- [`dim(`*`<STRProfiles>`*`)`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles-methods.md)
  [`dimnames(`*`<STRProfiles>`*`)`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles-methods.md)
  [`` `[`( ``*`<STRProfiles>`*`,`*`<ANY>`*`,`*`<ANY>`*`,`*`<ANY>`*`)`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles-methods.md)
  [`` `$`( ``*`<STRProfiles>`*`)`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles-methods.md)
  [`show(`*`<STRProfiles>`*`)`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles-methods.md)
  [`c(`*`<STRProfiles>`*`)`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles-methods.md)
  [`as.data.frame(`*`<STRProfiles>`*`)`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles-methods.md)
  : Dimensions, subsetting, and coercion for STRProfiles

## Marker handling

Harmonising and classifying marker names.

- [`markerAliases()`](https://j-andrews7.github.io/STRprofilerR/reference/markerAliases.md)
  [`harmonizeMarkers()`](https://j-andrews7.github.io/STRprofilerR/reference/markerAliases.md)
  : Marker name harmonisation
- [`amelogeninMarkers()`](https://j-andrews7.github.io/STRprofilerR/reference/amelogeninMarkers.md)
  : Recognised amelogenin marker names
- [`classifyMarkers()`](https://j-andrews7.github.io/STRprofilerR/reference/classifyMarkers.md)
  : Classify STR markers

## Scoring and comparison

- [`scoreProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/scoreProfiles.md)
  : Score STR profiles against each other
- [`scoreQuery()`](https://j-andrews7.github.io/STRprofilerR/reference/scoreQuery.md)
  : Score a single profile against a reference set
- [`flagMixedSamples()`](https://j-andrews7.github.io/STRprofilerR/reference/flagMixedSamples.md)
  : Flag potentially mixed samples
- [`summarizeMatches()`](https://j-andrews7.github.io/STRprofilerR/reference/summarizeMatches.md)
  : Summarise pairwise scores into one row per query
- [`compareProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/compareProfiles.md)
  : Compare STR profiles end to end

## Results

- [`STRComparison-class`](https://j-andrews7.github.io/STRprofilerR/reference/STRComparison-class.md)
  [`STRComparison`](https://j-andrews7.github.io/STRprofilerR/reference/STRComparison-class.md)
  : STRComparison: the result of comparing STR profiles
- [`scores()`](https://j-andrews7.github.io/STRprofilerR/reference/STRComparison-accessors.md)
  [`params()`](https://j-andrews7.github.io/STRprofilerR/reference/STRComparison-accessors.md)
  [`queryProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/STRComparison-accessors.md)
  [`referenceProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/STRComparison-accessors.md)
  [`summary(`*`<STRComparison>`*`)`](https://j-andrews7.github.io/STRprofilerR/reference/STRComparison-accessors.md)
  [`show(`*`<STRComparison>`*`)`](https://j-andrews7.github.io/STRprofilerR/reference/STRComparison-accessors.md)
  : Accessors for STRComparison objects
- [`writeSTRResults()`](https://j-andrews7.github.io/STRprofilerR/reference/writeSTRResults.md)
  : Write comparison results to disk
- [`strHTMLTable()`](https://j-andrews7.github.io/STRprofilerR/reference/strHTMLTable.md)
  : Write a data frame as a standalone HTML table

## Cellosaurus and CLASTR

- [`clastrQuery()`](https://j-andrews7.github.io/STRprofilerR/reference/clastrQuery.md)
  : Query the Cellosaurus knowledge base via CLASTR
- [`clastrBatchQuery()`](https://j-andrews7.github.io/STRprofilerR/reference/clastrBatchQuery.md)
  : Query CLASTR in batch and save the XLSX result
- [`clastrMarkers()`](https://j-andrews7.github.io/STRprofilerR/reference/clastrMarkers.md)
  [`validateClastrMarkers()`](https://j-andrews7.github.io/STRprofilerR/reference/clastrMarkers.md)
  : Marker names accepted by the CLASTR API

## Package

- [`STRprofilerR`](https://j-andrews7.github.io/STRprofilerR/reference/STRprofilerR-package.md)
  [`STRprofilerR-package`](https://j-andrews7.github.io/STRprofilerR/reference/STRprofilerR-package.md)
  : STRprofilerR: Compare Short Tandem Repeat Profiles for Model
  Authentication
