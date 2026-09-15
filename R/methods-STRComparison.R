#' Accessors for STRComparison objects
#'
#' Extract the parts of the [STRComparison] object returned by
#' [compareProfiles()].
#'
#' @param x,object A [STRComparison] object.
#' @param ... Ignored.
#'
#' @return
#' `scores()` returns the pair-level [S4Vectors::DataFrame], `summary()` the
#' per-query one, `queryProfiles()` and `referenceProfiles()` the
#' [STRProfiles] that were compared, and `params()` a list of the scoring and
#' threshold settings used.
#'
#' @author Jared Andrews
#'
#' @examples
#' q <- readSTRProfiles(
#'     system.file("extdata", "ExampleSTR_long.csv", package = "STRprofilerR"),
#'     sampleCol = "Sample Name"
#' )
#' ref <- readSTRProfiles(
#'     system.file("extdata", "ExampleSTR_database.csv", package = "STRprofilerR"),
#'     sampleCol = "Sample Name"
#' )
#' cmp <- compareProfiles(q, ref)
#'
#' cmp
#' summary(cmp)
#' head(as.data.frame(scores(cmp)))
#' params(cmp)$tanThreshold
#'
#' @name STRComparison-accessors
NULL

#' @rdname STRComparison-accessors
#' @export
setMethod("scores", "STRComparison", function(x, ...) x@scores)

#' @rdname STRComparison-accessors
#' @export
setMethod("params", "STRComparison", function(x, ...) x@params)

#' @rdname STRComparison-accessors
#' @export
setMethod("queryProfiles", "STRComparison", function(x, ...) x@query)

#' @rdname STRComparison-accessors
#' @export
setMethod("referenceProfiles", "STRComparison", function(x, ...) x@reference)

#' @rdname STRComparison-accessors
#' @export
setMethod("summary", "STRComparison", function(object, ...) object@summary)

#' @rdname STRComparison-accessors
#' @export
setMethod("show", "STRComparison", function(object) {
    cat("class: STRComparison\n")
    cat("queries(", nrow(object@query), "): ",
        paste(utils::head(rownames(object@query), 4L), collapse = " "),
        if (nrow(object@query) > 4L) " ..." else "", "\n",
        sep = ""
    )
    cat("references(", nrow(object@reference), ")\n", sep = "")
    cat("comparisons: ", nrow(object@scores), "\n", sep = "")

    p <- object@params
    cat("thresholds: tanabe=", p$tanThreshold,
        " mastersQuery=", p$masQThreshold,
        " mastersRef=", p$masRThreshold, "\n",
        sep = ""
    )
    cat("useAmel: ", p$useAmel, "\n", sep = "")

    if (!is.null(object@summary$mixed)) {
        cat("flagged as mixed: ", sum(object@summary$mixed, na.rm = TRUE), "\n", sep = "")
    }
    invisible(NULL)
})
