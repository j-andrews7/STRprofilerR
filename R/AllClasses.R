#' STRProfiles: a set of short tandem repeat profiles
#'
#' An S4 container holding STR profiles for a set of samples, the markers they
#' were typed at, per-sample metadata, and a record of how the object was built.
#'
#' @details
#' Alleles are stored **pre-split**: each column of the `alleles` slot is an
#' [IRanges::CharacterList] whose i-th element is the character vector of
#' unique alleles called for sample i at that marker. A sample that was not
#' typed at a marker has a zero-length entry.
#'
#' This is the main structural departure from the `strprofiler` Python package,
#' which stores comma-joined strings and re-splits them on every single pairwise
#' comparison. Splitting once at ingest is what lets [scoreProfiles()] express
#' scoring as a handful of sparse matrix products.
#'
#' Build one with [readSTRProfiles()] (from files) or [STRProfiles()] (from a
#' `data.frame` already in memory).
#'
#' @slot alleles A [S4Vectors::DataFrame] with one row per sample and one column
#'   per marker. Every column is a [IRanges::CharacterList].
#' @slot markerData A [S4Vectors::DataFrame] with one row per marker, row names
#'   matching `colnames(alleles)`. Always carries a `class` column
#'   (see [classifyMarkers()]) and an `nTyped` column.
#' @slot sampleData A [S4Vectors::DataFrame] with one row per sample, row names
#'   matching `rownames(alleles)`. Holds non-marker columns such as `Center` and
#'   `Passage`.
#' @slot provenance A list recording the source files, ingest options,
#'   timestamp, and package version.
#'
#' @return An object of class `STRProfiles`.
#'
#' @author Jared Andrews
#'
#' @seealso [readSTRProfiles()] to build one, [scoreProfiles()] to compare them.
#'
#' @examples
#' f <- system.file("extdata", "ExampleSTR_long.csv", package = "STRprofilerR")
#' p <- readSTRProfiles(f, sampleCol = "Sample Name")
#' p
#'
#' @export
setClass("STRProfiles",
    slots = c(
        alleles = "DataFrame",
        markerData = "DataFrame",
        sampleData = "DataFrame",
        provenance = "list"
    )
)

setValidity("STRProfiles", function(object) {
    msg <- character(0)

    al <- object@alleles
    md <- object@markerData
    sd <- object@sampleData

    if (ncol(al) != nrow(md)) {
        msg <- c(msg, "'markerData' must have one row per column of 'alleles'.")
    } else if (!identical(colnames(al), rownames(md))) {
        msg <- c(msg, "'rownames(markerData)' must match 'colnames(alleles)'.")
    }

    if (nrow(al) != nrow(sd)) {
        msg <- c(msg, "'sampleData' must have one row per row of 'alleles'.")
    } else if (!identical(rownames(al), rownames(sd))) {
        msg <- c(msg, "'rownames(sampleData)' must match 'rownames(alleles)'.")
    }

    if (is.null(rownames(al))) {
        msg <- c(msg, "'alleles' must have row names (sample identifiers).")
    } else if (anyDuplicated(rownames(al))) {
        dup <- unique(rownames(al)[duplicated(rownames(al))])
        msg <- c(msg, paste0("Duplicated sample names: ", paste(dup, collapse = ", "), "."))
    }

    if (ncol(al) > 0L && anyDuplicated(colnames(al))) {
        dup <- unique(colnames(al)[duplicated(colnames(al))])
        msg <- c(msg, paste0("Duplicated marker names: ", paste(dup, collapse = ", "), "."))
    }

    notList <- !vapply(as.list(al), function(z) is(z, "CharacterList"), logical(1))
    if (any(notList)) {
        msg <- c(msg, paste0(
            "All 'alleles' columns must be CharacterList; these are not: ",
            paste(colnames(al)[notList], collapse = ", "), "."
        ))
    }

    if (nrow(md) > 0L && !"class" %in% colnames(md)) {
        msg <- c(msg, "'markerData' must have a 'class' column.")
    }

    if (length(msg) == 0L) TRUE else msg
})

#' STRComparison: the result of comparing STR profiles
#'
#' An S4 container returned by [compareProfiles()], holding every pairwise score
#' alongside a per-query summary and the parameters used to produce them.
#'
#' @slot scores A [S4Vectors::DataFrame] with one row per query/reference pair.
#' @slot summary A [S4Vectors::DataFrame] with one row per query sample.
#' @slot query The query [STRProfiles].
#' @slot reference The reference [STRProfiles]. Identical to `query` for an
#'   all-against-all comparison.
#' @slot params A list of the scoring and threshold parameters used.
#'
#' @return An object of class `STRComparison`.
#'
#' @author Jared Andrews
#'
#' @aliases STRComparison
#'
#' @seealso [compareProfiles()] to build one, [writeSTRResults()] to write it out.
#'
#' @examples
#' f <- system.file("extdata", "ExampleSTR_long.csv", package = "STRprofilerR")
#' db <- system.file("extdata", "ExampleSTR_database.csv", package = "STRprofilerR")
#' cmp <- compareProfiles(
#'     readSTRProfiles(f, sampleCol = "Sample Name"),
#'     readSTRProfiles(db, sampleCol = "Sample Name")
#' )
#' cmp
#'
#' @export
setClass("STRComparison",
    slots = c(
        scores = "DataFrame",
        summary = "DataFrame",
        query = "STRProfiles",
        reference = "STRProfiles",
        params = "list"
    )
)

setValidity("STRComparison", function(object) {
    msg <- character(0)

    required <- c(
        "query", "reference", "nSharedMarkers", "nSharedAlleles",
        "nQueryAlleles", "nReferenceAlleles",
        "tanabeScore", "mastersQueryScore", "mastersRefScore"
    )
    missing <- setdiff(required, colnames(object@scores))
    if (length(missing) > 0L) {
        msg <- c(msg, paste0("'scores' is missing columns: ", paste(missing, collapse = ", "), "."))
    }

    if (length(msg) == 0L) TRUE else msg
})
