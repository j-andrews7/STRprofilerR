#' Marker names accepted by the CLASTR API
#'
#' The controlled vocabulary of marker names the Cellosaurus CLASTR similarity
#' search accepts, and a helper for checking a profile against it.
#'
#' @details
#' CLASTR silently ignores markers it does not recognise, so a profile using a
#' local marker spelling can be scored on far fewer markers than intended
#' without any warning. Check first with `validateClastrMarkers()`.
#'
#' Note that CLASTR wants the *spaced* Penta spellings (`Penta D`), which is the
#' opposite of this package's internal convention; [clastrQuery()] converts them
#' for you via [harmonizeMarkers()] with `reverse = TRUE`.
#'
#' @param markers Character vector of marker names to check.
#'
#' @return
#' `clastrMarkers()` returns the accepted marker names.
#'
#' `validateClastrMarkers()` returns the subset of `markers` that CLASTR does
#' not recognise, as a character vector, empty if all are valid.
#'
#' @author Jared Andrews
#'
#' @references
#' Robin T, Capes-Davis A, Bairoch A (2020). CLASTR: The Cellosaurus STR
#' similarity search tool - A precious help for cell line authentication.
#' *International Journal of Cancer* 146(5):1299-1306. \doi{10.1002/ijc.32639}
#'
#' @seealso [clastrQuery()], which validates automatically before querying.
#'
#' @examples
#' head(clastrMarkers())
#'
#' validateClastrMarkers(c("Amelogenin", "vWA", "marker1", "NotAMarker"))
#'
#' @export
clastrMarkers <- function() {
    c(
        "Amel", "Amelogenin", "CSF1PO", "D2S1338", "D3S1358", "D5S818",
        "D7S820", "D8S1179", "D13S317", "D16S539", "D18S51", "D19S433",
        "D21S11", "FGA", "Penta D", "Penta E", "PentaD", "PentaE", "TH01",
        "TPOX", "vWA", "D1S1656", "D2S441", "D6S1043", "D10S1248", "D12S391",
        "D22S1045", "DXS101", "DYS391", "F13A01", "F13B", "FESFPS", "LPL",
        "Penta C", "PentaC", "SE33"
    )
}

#' @rdname clastrMarkers
#' @export
validateClastrMarkers <- function(markers) {
    reserved <- c(
        "algorithm", "includeAmelogenin", "scoreFilter", "description",
        "scoringMode", "minMarkers", "maxResults", "outputFormat"
    )
    markers <- setdiff(as.character(markers), reserved)

    setdiff(markers, clastrMarkers())
}

#' Query the Cellosaurus knowledge base via CLASTR
#'
#' Searches the human cell line profiles in
#' [Cellosaurus](https://www.cellosaurus.org) for matches to one or more STR
#' profiles, using the
#' [CLASTR REST API](https://www.cellosaurus.org/str-search/help.html).
#'
#' @details
#' Each profile is submitted separately and the JSON responses are parsed into
#' one tidy table, with a `query` column naming the profile each row answers.
#' A result carrying two profiles (CLASTR returns at most two) is reported as
#' two rows, with `" (Best)"` and `" (Worst)"` appended to the accession, as the
#' Python package does.
#'
#' Marker names are converted to CLASTR's spellings on the way out and back to
#' this package's on the way in, so `PentaD` round-trips correctly. Markers
#' CLASTR does not recognise are reported with a warning and ignored by the
#' search; check ahead of time with [validateClastrMarkers()].
#'
#' This function needs network access, and **is for research use only**.
#'
#' ## Divergences from the Python package
#'
#' The response is parsed directly from the nested JSON rather than through a
#' flatten-and-pivot chain over generated column names. `algorithm = 3` is sent
#' for Masters (reference) in batch mode, as `strprofiler` does from 0.5.0;
#' through 0.4.2 it sent `2`, which silently runs a Masters (query) search.
#'
#' @param x A [STRProfiles] object, or a named character vector giving one
#'   profile's markers and comma-separated alleles.
#' @param algorithm Similarity score CLASTR should rank by.
#' @param scoringMode How CLASTR handles markers missing from one side:
#'   `"nonEmpty"` uses markers present in both, `"query"` all query markers,
#'   `"reference"` all reference markers.
#' @param scoreFilter Minimum score for a match to be returned.
#' @param minMarkers Minimum number of shared markers for a match to be
#'   returned.
#' @param maxResults Maximum number of matches to return per query.
#' @param includeAmelogenin Logical scalar. Include amelogenin in CLASTR's
#'   scoring.
#' @param url API endpoint. Exposed for testing.
#'
#' @return A [S4Vectors::DataFrame] with one row per returned profile and
#'   columns `query`, `accession`, `name`, `species`, `score`, `accessionLink`,
#'   `problem`, followed by one column per marker. Zero rows if nothing matched.
#'
#' @author Jared Andrews
#'
#' @references
#' Bairoch A (2018). The Cellosaurus, a cell-line knowledge resource.
#' *Journal of Biomolecular Techniques* 29(2):25-38. \doi{10.7171/jbt.18-2902-002}
#'
#' Robin T, Capes-Davis A, Bairoch A (2020). CLASTR: The Cellosaurus STR
#' similarity search tool. *International Journal of Cancer* 146(5):1299-1306.
#' \doi{10.1002/ijc.32639}
#'
#' @seealso [clastrBatchQuery()] for CLASTR's own multi-sheet XLSX output,
#'   [compareProfiles()] to compare against a local database instead.
#'
#' @examplesIf interactive() && requireNamespace("curl", quietly = TRUE) && curl::has_internet()
#' profile <- c(
#'     Amelogenin = "X", CSF1PO = "13,14", D5S818 = "13", D7S820 = "8,9",
#'     D13S317 = "12", FGA = "24", TH01 = "8", TPOX = "11", vWA = "16"
#' )
#'
#' hits <- clastrQuery(profile, scoreFilter = 80)
#' as.data.frame(hits)[, c("accession", "name", "score")]
#'
#' @export
clastrQuery <- function(x,
                        algorithm = c("tanabe", "mastersQuery", "mastersRef"),
                        scoringMode = c("nonEmpty", "query", "reference"),
                        scoreFilter = 80,
                        minMarkers = 8,
                        maxResults = 200,
                        includeAmelogenin = FALSE,
                        url = "https://www.cellosaurus.org/str-search/api/query/") {
    algorithm <- match.arg(algorithm)
    scoringMode <- match.arg(scoringMode)

    profiles <- .asClastrProfiles(x)
    .warnClastrMarkers(unique(unlist(lapply(profiles, names), use.names = FALSE)))

    parts <- lapply(names(profiles), function(nm) {
        body <- c(
            profiles[[nm]],
            list(
                algorithm = .clastrAlgorithm(algorithm),
                scoringMode = .clastrScoringMode(scoringMode),
                scoreFilter = as.integer(scoreFilter),
                minMarkers = as.integer(minMarkers),
                maxResults = as.integer(maxResults),
                includeAmelogenin = isTRUE(includeAmelogenin)
            )
        )

        resp <- httr2::request(url)
        resp <- httr2::req_body_json(resp, body, auto_unbox = TRUE)
        resp <- httr2::req_user_agent(resp, .userAgent())
        resp <- httr2::req_retry(resp, max_tries = 3L)
        resp <- httr2::req_perform(resp)

        .parseClastrResults(httr2::resp_body_json(resp, simplifyVector = FALSE), nm)
    })

    .bindClastrRows(unlist(parts, recursive = FALSE))
}

#' Query CLASTR in batch and save the XLSX result
#'
#' Submits several profiles to CLASTR's batch endpoint and writes the workbook
#' it returns, one sheet per query.
#'
#' @details
#' The batch endpoint returns a formatted XLSX rather than JSON, so this is the
#' route to take when you want CLASTR's own presentation of the results. Use
#' [clastrQuery()] instead when you want the hits as data to work with.
#'
#' This function needs network access, and **is for research use only**.
#'
#' @param x A [STRProfiles] object, or a named character vector for a single
#'   profile.
#' @param file Path to write the XLSX to.
#' @inheritParams clastrQuery
#'
#' @return Invisibly, the path written to.
#'
#' @author Jared Andrews
#'
#' @seealso [clastrQuery()] for parsed results.
#'
#' @examplesIf interactive() && requireNamespace("curl", quietly = TRUE) && curl::has_internet()
#' p <- readSTRProfiles(
#'     system.file("extdata", "Example_clastr_input.csv", package = "STRprofilerR")
#' )
#'
#' out <- file.path(tempdir(), "clastr.xlsx")
#' clastrBatchQuery(p, out)
#'
#' @export
clastrBatchQuery <- function(x,
                             file,
                             algorithm = c("tanabe", "mastersQuery", "mastersRef"),
                             scoringMode = c("nonEmpty", "query", "reference"),
                             scoreFilter = 80,
                             minMarkers = 8,
                             maxResults = 200,
                             includeAmelogenin = FALSE,
                             url = "https://www.cellosaurus.org/str-search/api/batch/") {
    algorithm <- match.arg(algorithm)
    scoringMode <- match.arg(scoringMode)

    profiles <- .asClastrProfiles(x)
    .warnClastrMarkers(unique(unlist(lapply(profiles, names), use.names = FALSE)))

    body <- lapply(names(profiles), function(nm) {
        c(
            profiles[[nm]],
            list(
                description = nm,
                algorithm = .clastrAlgorithm(algorithm),
                scoringMode = .clastrScoringMode(scoringMode),
                scoreFilter = as.integer(scoreFilter),
                minMarkers = as.integer(minMarkers),
                maxResults = as.integer(maxResults),
                includeAmelogenin = isTRUE(includeAmelogenin),
                outputFormat = "xlsx"
            )
        )
    })

    resp <- httr2::request(url)
    resp <- httr2::req_body_json(resp, body, auto_unbox = TRUE)
    resp <- httr2::req_user_agent(resp, .userAgent())
    resp <- httr2::req_retry(resp, max_tries = 3L)
    resp <- httr2::req_perform(resp)

    writeBin(httr2::resp_body_raw(resp), file)
    invisible(file)
}


## ---------------------------------------------------------------------------
## Internals
## ---------------------------------------------------------------------------

.userAgent <- function() {
    paste0("STRprofilerR/", .pkgVersion(), " (https://github.com/j-andrews7/STRprofilerR)")
}

.clastrAlgorithm <- function(x) {
    switch(x, tanabe = 1L, mastersQuery = 2L, mastersRef = 3L)
}

.clastrScoringMode <- function(x) {
    switch(x, nonEmpty = 1L, query = 2L, reference = 3L)
}

# Normalise input into a named list of (marker -> allele string) lists, with
# marker names in CLASTR's spelling and untyped markers dropped.
.asClastrProfiles <- function(x) {
    if (is(x, "STRProfiles")) {
        flat <- lapply(as.list(alleles(x)), function(z) {
            stats::setNames(S4Vectors::unstrsplit(z, ","), rownames(x))
        })
        out <- lapply(rownames(x), function(s) {
            vals <- vapply(flat, `[[`, character(1), s)
            as.list(vals[nzchar(vals)])
        })
        names(out) <- rownames(x)
    } else {
        x <- as.list(x)
        if (is.null(names(x)) || !all(nzchar(names(x)))) {
            stop("'x' must be a STRProfiles object or a fully named vector.", call. = FALSE)
        }
        vals <- vapply(x, function(z) paste(as.character(z), collapse = ","), character(1))
        out <- list(Query = as.list(vals[nzchar(vals)]))
    }

    lapply(out, function(p) {
        names(p) <- harmonizeMarkers(names(p), reverse = TRUE)
        p
    })
}

.warnClastrMarkers <- function(markers) {
    bad <- validateClastrMarkers(markers)
    if (length(bad) > 0L) {
        warning(
            "Marker(s) ", paste0("'", bad, "'", collapse = ", "),
            " are not recognised by CLASTR and will be ignored by the search.\n",
            "See https://www.cellosaurus.org/str-search/ for the accepted names.",
            call. = FALSE
        )
    }
    invisible(bad)
}

# One list per returned profile. Kept separate from the HTTP call so it can be
# exercised against a recorded response with no network.
.parseClastrResults <- function(json, queryName) {
    results <- json$results
    if (length(results) == 0L) {
        return(list())
    }

    out <- list()
    for (res in results) {
        profiles <- res$profiles
        multi <- length(profiles) > 1L

        for (prof in profiles) {
            accession <- res$accession
            if (multi) {
                suffix <- if (isTRUE(all.equal(prof$score, res$bestScore))) " (Best)" else " (Worst)"
                accession <- paste0(accession, suffix)
            }

            mk <- vapply(prof$markers, function(m) as.character(m$name), character(1))
            al <- vapply(prof$markers, function(m) {
                paste(
                    vapply(m$alleles, function(a) as.character(a$value), character(1)),
                    collapse = ","
                )
            }, character(1))
            names(al) <- harmonizeMarkers(mk)

            problem <- res$problem
            if (is.null(problem)) problem <- res$problematic
            problem <- if (is.null(problem) || isFALSE(problem)) "" else as.character(problem)

            out[[length(out) + 1L]] <- list(
                query = queryName,
                accession = accession,
                name = as.character(res$name),
                species = as.character(res$species),
                score = as.numeric(prof$score),
                accessionLink = paste0("https://www.cellosaurus.org/", res$accession),
                problem = problem,
                markers = al
            )
        }
    }

    out
}

.clastrColumns <- function() {
    c("query", "accession", "name", "species", "score", "accessionLink", "problem")
}

.bindClastrRows <- function(rows) {
    fixed <- .clastrColumns()

    if (length(rows) == 0L) {
        empty <- c(
            lapply(stats::setNames(nm = setdiff(fixed, "score")), function(z) character(0)),
            list(score = numeric(0))
        )
        return(do.call(S4Vectors::DataFrame, c(empty[fixed], list(check.names = FALSE))))
    }

    allMarkers <- unique(unlist(lapply(rows, function(r) names(r$markers)), use.names = FALSE))

    base <- lapply(fixed, function(f) {
        if (f == "score") {
            vapply(rows, function(r) r[[f]], numeric(1))
        } else {
            vapply(rows, function(r) as.character(r[[f]]), character(1))
        }
    })
    names(base) <- fixed

    markerCols <- lapply(allMarkers, function(m) {
        vapply(rows, function(r) {
            # Single-bracket: a marker absent from this profile gives NA, where
            # [[ would throw.
            v <- unname(r$markers[m])
            if (is.na(v)) "" else v
        }, character(1))
    })
    names(markerCols) <- allMarkers

    do.call(S4Vectors::DataFrame, c(base, markerCols, list(check.names = FALSE)))
}
