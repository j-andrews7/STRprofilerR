#' Accessors for STRProfiles objects
#'
#' Extract and replace the parts of a [STRProfiles] object.
#'
#' @param x A [STRProfiles] object.
#' @param ... Ignored.
#' @param value Replacement value.
#'
#' @return
#' `alleles()` returns a [S4Vectors::DataFrame] of [IRanges::CharacterList]
#' columns, one column per marker.
#'
#' `markers()` returns a character vector of marker names.
#'
#' `markerData()` and `sampleData()` return a [S4Vectors::DataFrame] of marker
#' and sample annotations respectively.
#'
#' `provenance()` returns a list describing how the object was built.
#'
#' The replacement forms return an updated [STRProfiles] object.
#'
#' @author Jared Andrews
#'
#' @examples
#' f <- system.file("extdata", "ExampleSTR_long.csv", package = "STRprofilerR")
#' p <- readSTRProfiles(f, sampleCol = "Sample Name")
#'
#' markers(p)
#' markerData(p)
#' alleles(p)[["marker1"]]
#' provenance(p)$timestamp
#'
#' # Correct a marker classification by hand.
#' markerData(p)$class[markers(p) == "marker1"] <- "y-linked"
#' markerData(p)
#'
#' @name STRProfiles-accessors
NULL

#' @rdname STRProfiles-accessors
#' @export
setMethod("alleles", "STRProfiles", function(x, ...) x@alleles)

#' @rdname STRProfiles-accessors
#' @export
setReplaceMethod("alleles", "STRProfiles", function(x, ..., value) {
    x@alleles <- value
    x@markerData <- .syncMarkerData(value, x@markerData)
    validObject(x)
    x
})

#' @rdname STRProfiles-accessors
#' @export
setMethod("markers", "STRProfiles", function(x, ...) colnames(x@alleles))

#' @rdname STRProfiles-accessors
#' @export
setMethod("markerData", "STRProfiles", function(x, ...) x@markerData)

#' @rdname STRProfiles-accessors
#' @export
setReplaceMethod("markerData", "STRProfiles", function(x, ..., value) {
    x@markerData <- value
    validObject(x)
    x
})

#' @rdname STRProfiles-accessors
#' @export
setMethod("sampleData", "STRProfiles", function(x, ...) x@sampleData)

#' @rdname STRProfiles-accessors
#' @export
setReplaceMethod("sampleData", "STRProfiles", function(x, ..., value) {
    x@sampleData <- value
    validObject(x)
    x
})

#' @rdname STRProfiles-accessors
#' @export
setMethod("provenance", "STRProfiles", function(x, ...) x@provenance)

#' Dimensions, subsetting, and coercion for STRProfiles
#'
#' Standard R idioms for inspecting and reshaping a [STRProfiles] object.
#'
#' @details
#' A `STRProfiles` object is samples-by-markers, so `dim()` reports
#' `c(n_samples, n_markers)` and `x[i, j]` subsets samples by `i` and markers by
#' `j`, both of which accept names, indices, or logical vectors.
#'
#' `as.data.frame()` flattens the object back to the wide layout
#' [readSTRProfiles()] accepts, with alleles collapsed to comma-separated
#' strings, so profiles round-trip through disk without loss. Annotations the
#' package computes at ingest rather than reading from the input — currently
#' `nDroppedCalls` — are left out, since every column emitted is read back as a
#' marker and a QC statistic is not one.
#'
#' @param x A [STRProfiles] object.
#' @param i Sample index: names, positions, or a logical vector.
#' @param j Marker index: names, positions, or a logical vector.
#' @param drop Ignored; present for compatibility with the `[` generic.
#' @param name A marker or sample annotation name.
#' @param row.names,optional,... Passed through to `as.data.frame()`.
#' @param object A [STRProfiles] object.
#' @param recursive Ignored; present for compatibility with the `c()` generic.
#'
#' @return
#' `dim()` returns an integer vector of length two; `dimnames()` a list of two
#' character vectors. `[` and `c()` return a [STRProfiles] object.
#' `as.data.frame()` returns a `data.frame`. `$` returns the named column of
#' [sampleData()].
#'
#' @author Jared Andrews
#'
#' @examples
#' f <- system.file("extdata", "ExampleSTR_database.csv", package = "STRprofilerR")
#' p <- readSTRProfiles(f, sampleCol = "Sample Name")
#'
#' dim(p)
#' colnames(p)
#'
#' # Subset to three samples and drop amelogenin.
#' sub <- p[1:3, markerData(p)$class != "amelogenin"]
#' dim(sub)
#'
#' as.data.frame(sub)
#'
#' @aliases [,STRProfiles-method
#'
#' @name STRProfiles-methods
NULL

#' @rdname STRProfiles-methods
#' @export
setMethod("dim", "STRProfiles", function(x) c(nrow(x@alleles), ncol(x@alleles)))

#' @rdname STRProfiles-methods
#' @export
setMethod("dimnames", "STRProfiles", function(x) list(rownames(x@alleles), colnames(x@alleles)))

#' @rdname STRProfiles-methods
#' @export
setMethod(
    "[", signature(x = "STRProfiles", i = "ANY", j = "ANY", drop = "ANY"),
    function(x, i, j, ..., drop = FALSE) {
        if (missing(i)) i <- seq_len(nrow(x@alleles))
        if (missing(j)) j <- seq_len(ncol(x@alleles))

        i <- .resolveIndex(i, rownames(x@alleles), "sample")
        j <- .resolveIndex(j, colnames(x@alleles), "marker")

        x@alleles <- x@alleles[i, j, drop = FALSE]
        x@markerData <- x@markerData[j, , drop = FALSE]
        x@sampleData <- x@sampleData[i, , drop = FALSE]
        x@markerData <- .syncMarkerData(x@alleles, x@markerData)

        validObject(x)
        x
    }
)

#' @rdname STRProfiles-methods
#' @export
setMethod("$", "STRProfiles", function(x, name) x@sampleData[[name]])

#' @rdname STRProfiles-methods
#' @export
setMethod("show", "STRProfiles", function(object) {
    cat("class: STRProfiles\n")
    cat(.labelledLine("samples", rownames(object@alleles)))
    cat(.labelledLine("markers", colnames(object@alleles)))
    cat(.labelledLine("sampleData", colnames(object@sampleData)))

    cls <- object@markerData$class
    if (length(cls) > 0L) {
        tab <- table(cls)
        cat("markerClass: ", paste0(names(tab), "(", as.integer(tab), ")", collapse = " "), "\n", sep = "")
    }

    src <- object@provenance$files
    if (length(src) > 0L) {
        cat(.labelledLine("source", basename(src)))
    }
    invisible(NULL)
})

#' @rdname STRProfiles-methods
#' @export
setMethod("c", "STRProfiles", function(x, ..., recursive = FALSE) {
    others <- list(...)
    if (length(others) == 0L) {
        return(x)
    }
    Reduce(.combineTwoProfiles, others, init = x)
})

#' @rdname STRProfiles-methods
#' @param sampleCol Name to give the sample identifier column.
#' @export
setMethod(
    "as.data.frame", "STRProfiles",
    function(x, row.names = NULL, optional = FALSE, ..., sampleCol = "Sample") {
        flat <- lapply(as.list(x@alleles), function(z) S4Vectors::unstrsplit(z, ","))

        out <- data.frame(
            .sample = rownames(x@alleles),
            stringsAsFactors = FALSE,
            check.names = FALSE
        )
        names(out) <- sampleCol

        # Reserved annotations are ingest statistics, not profile data, and
        # anything emitted here is read back as a marker. See
        # .RESERVED_SAMPLE_COLS.
        sd <- x@sampleData[, setdiff(colnames(x@sampleData), .RESERVED_SAMPLE_COLS),
            drop = FALSE
        ]
        if (ncol(sd) > 0L) {
            out <- cbind(out, as.data.frame(sd), stringsAsFactors = FALSE)
        }
        if (length(flat) > 0L) {
            out <- cbind(out, as.data.frame(flat, check.names = FALSE, stringsAsFactors = FALSE))
        }

        rownames(out) <- row.names
        out
    }
)
