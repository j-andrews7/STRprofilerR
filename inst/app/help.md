# STRprofiler Application Usage

**This site and tool are intended for research purposes only.**

## Database Queries

For a sample entered manually in the `Single Query` tab, or samples uploaded from a batch file in the `Batch Query` tab, STRprofiler generates a report that includes the similarity scores (described below) computed against a database of known STR profiles.

The report differs depending on whether an individual sample or a batch of samples is provided.

### Default Database

The data underlying the default database were provided by [The Jackson Laboratory PDX program](https://tumor.informatics.jax.org/mtbwi/pdxSearch.do) and the [NCI Patient-Derived Models Repository (PDMR)](https://pdmr.cancer.gov/).

If this app is hosted with a custom database, please contact the host for information on the database source.

### CLASTR / Cellosaurus API Query

Queries of the [Cellosaurus](https://www.cellosaurus.org/description.html) (Bairoch, 2018) cell line database are also available for single and batch samples via the [CLASTR](https://www.cellosaurus.org/str-search/) (Robin, Capes-Davis, and Bairoch, 2020) [REST API](https://www.cellosaurus.org/str-search/help.html#5). These queries need network access. Marker names CLASTR does not recognise are reported and ignored by the search.

---

### Single Query Report

For individual samples, a report is generated with the following fields when `STRprofiler Database` is selected as the search type. The query is always the first row.

| Output Field | Description |
| :--- | :--- |
| Mixed Sample | Flag to indicate sample mixing, determined by the "'Mixed' Sample Threshold" option. If more markers have more than 2 alleles than the threshold, the sample is flagged as potentially mixed. |
| Shared Markers | Number of markers typed in both the query and database sample. |
| Shared Alleles | Number of alleles shared between the query and database sample. |
| Tanabe Score | Tanabe similarity score between the query and database sample (if Tanabe selected). |
| Masters Query Score | Masters 'query' similarity score between the query and database sample (if Masters Query selected). |
| Masters Ref Score | Masters 'reference' similarity score between the query and database sample (if Masters Reference selected). |
| Center, Passage | Sample metadata, if the database has it. |
| Markers 1 ... n | Marker alleles, with those that differ from the query highlighted. |

The report includes only those samples scoring greater than or equal to the `Similarity Score Filter Threshold`, and reports only the selected similarity score.

When `Cellosaurus Database (CLASTR)` is selected as the search type, a report is generated with the following fields:

| Output Field | Description |
| :--- | :--- |
| Accession | Cellosaurus cell line accession, linked to its Cellosaurus page. Lines Cellosaurus flags as problematic (e.g. contaminated or misidentified) are shown in red italics; hover over the accession for details. |
| Name | Cell line name. |
| Score | Similarity score between the query and cell line, using the selected Similarity Score Filter. |
| Markers 1 ... n | Marker alleles, with those that differ from the query highlighted. |

The report includes only those cell lines scoring greater than or equal to the `Similarity Score Filter Threshold`.

Either report can be downloaded as a CSV file with the `Download CSV` button.

---

### Batch Query Report

For batches of samples, a summary report is generated with one row per sample in the file.

| Output Field | Description |
| :--- | :--- |
| Mixed Sample | Flag to indicate sample mixing, determined by the "'Mixed' Sample Threshold" option. If more markers have more than 2 alleles than the threshold, the sample is flagged as potentially mixed. |
| Top Match | Name and Tanabe score of the best match to the sample. |
| Next Best Match | Name and Tanabe score of the next best match to the sample. |
| Tanabe Matches | Name and Tanabe score of every match at or above the Tanabe threshold. |
| Masters Query Matches | Name and Masters (vs. query) score of every match at or above the Masters (vs. query) threshold. |
| Masters Ref Matches | Name and Masters (vs. reference) score of every match at or above the Masters (vs. reference) threshold. |

`STRprofiler Database` compares every sample in the file against the loaded database. Every marker in the file must also be in the database, so that a misspelled marker name is caught rather than silently left unscored. `Within File Query` compares the samples in the file against each other.

When `Cellosaurus Database (CLASTR)` is selected as the search type, each sample is searched in turn. Use `Choose Sample` to view the results for each; `Download CSV` downloads the results for every sample, and `Download XLSX` fetches CLASTR's own workbook, with one sheet per sample.

---

### Database File Management

Custom database files can be uploaded for the session. They may be CSV, TSV, tab-separated TXT, or XLSX files, in either layout:

* **Long**: one row per sample, one column per marker, with alleles separated by commas (e.g. `12,14`).
* **Wide**: one row per sample and marker, with a `Marker` column and the alleles spread across columns whose names contain `Allele`.

A `Sample` column must be present (or the sample column the app was started with), but custom marker names may be used. Sample names must be unique. Amelogenin is recognised as `AMEL`, `Amel`, or `Amelogenin`, among other spellings, and is only scored if `Score Amelogenin` is selected.

Alleles are expected to be repeat counts, e.g. `12` or `9.3`. The only non-numeric alleles recognized are the Amelogenin sex markers `X` and `Y`. Any other non-numeric call - off-ladder (`OL`), ambiguous (`?`), `NR`, `ND` and the like - is discarded and never counted as an allele, whether it comes from an uploaded database or is typed into a marker box.

Optional `Center` and `Passage` columns are recognized as sample metadata rather than markers. They are displayed alongside results, but are excluded from similarity scoring and mixing checks. They may also be present in batch query files.

If an upload fails to load, the current database is kept. `Reset Custom Database` restores the database the app started with.

---

## Reported Similarity Scores

Scores are computed over the markers typed in both profiles.

1. [Tanabe, AKA the Sørensen-Dice coefficient](https://doi.org/10.11418/jtca1981.18.4_329):

![Tanabe = 2 x shared alleles / (query alleles + reference alleles) x 100](strprofilerr/tanabe_inverted.png)

2. [Masters (vs. query)](https://doi.org/10.1073/pnas.121616198):

![Masters (vs. query) = shared alleles / query alleles x 100](strprofilerr/masters_query_inverted.png)

3. [Masters (vs. reference)](https://doi.org/10.1073/pnas.121616198):

![Masters (vs. reference) = shared alleles / reference alleles x 100](strprofilerr/masters_ref_inverted.png)

---

## Query Options

### Single Query Options

* Amelogenin scoring is excluded by default but can be included by selecting the option.
* 'Mixed' Sample Threshold: the number of markers with > 2 alleles allowed before a sample is flagged for potential mixing. [default: 3]
* Similarity Score Filter: the similarity score used for result filtering. [default: Tanabe]
* Similarity Score Filter Threshold: the threshold to filter results. Only those samples with scores >= the threshold appear in results. [default: 80]

### Batch Query Options

`STRprofiler Database` and `Within File Query` options:

* Amelogenin scoring is excluded by default but can be included by selecting the option.
* 'Mixed' Sample Threshold: as for single queries. [default: 3]
* Tanabe Filter Threshold: the Tanabe score at or above which a sample is considered a match. [default: 80]
* Masters (vs. query) Filter Threshold: the Masters (vs. query) score at or above which a sample is considered a match. [default: 80]
* Masters (vs. reference) Filter Threshold: the Masters (vs. reference) score at or above which a sample is considered a match. [default: 80]

`Cellosaurus Database (CLASTR)` options:

* Amelogenin scoring is excluded by default but can be included by selecting the option.
* Similarity Score Filter: the similarity score used for result filtering. [default: Tanabe]
* Similarity Score Filter Threshold: the threshold to filter results. Only those cell lines with scores >= the threshold appear in results. [default: 80]

---

## R Package & CLI

This app is part of the [STRprofilerR](https://github.com/j-andrews7/STRprofilerR) R package, which also provides the comparisons as R functions and a command line interface for batch use in automated workflows. Its documentation is available [online](https://j-andrews7.github.io/STRprofilerR/). Run the app locally with `STRprofilerR::STRprofilerApp()`, or `strprofiler app` from a shell.

STRprofilerR is a port of the [STRprofiler](https://github.com/j-andrews7/STRprofiler) Python package, [available from PyPI](https://pypi.org/project/strprofiler/).

---

## References

STRprofiler is provided under the MIT license. If you use this app in your research, please cite:

Jared M Andrews\*, Michael W Lloyd\*, Steven B Neuhauser, Margaret Bundy, Emily L Jocoy, Susan D Airhart, Carol J Bult, Yvonne A Evrard, Jeffrey H Chuang, Suzanne Baker. STRprofiler: efficient comparisons of short tandem repeat profiles for biomedical model authentication. *Bioinformatics*, 2024, btae713. DOI: [10.1093/bioinformatics/btae713](https://doi.org/10.1093/bioinformatics/btae713); PMID: [39589865](https://pubmed.ncbi.nlm.nih.gov/39589865/)

If you use the Cellosaurus database in the app, please also cite:

Bairoch A. (2018) The Cellosaurus, a cell line knowledge resource. *Journal of Biomolecular Techniques* 29:25-38. DOI: [10.7171/jbt.18-2902-002](https://doi.org/10.7171/jbt.18-2902-002); PMID: 29805321

Robin T, Capes-Davis A, Bairoch A. (2020) CLASTR: the Cellosaurus STR Similarity Search Tool - A Precious Help for Cell Line Authentication. *International Journal of Cancer* 146(5):1299-1306. DOI: [10.1002/ijc.32639](https://doi.org/10.1002/ijc.32639); PMID: 31444973
