#' Compare STR profiles end to end
#'
#' Scores profiles, flags potential mixing, and summarises the hits in one call.
#' This is the R equivalent of the Python package's `strprofiler compare`
#' command, minus the file writing, which [writeSTRResults()] handles.
#'
#' @details
#' With `reference` supplied, each query is compared against the reference set
#' only, never against the other queries. This is the "batch against database"
#' mode. With `reference = NULL`, queries are compared against each other and
#' self-comparisons are dropped.
#'
#' Unlike `strprofiler`, this returns an object rather than writing files, so
#' results can be inspected, filtered, or plotted before anything is committed
#' to disk. Pass the result to [writeSTRResults()] to produce the same file set
#' the Python CLI does.
#'
#' @inheritParams scoreProfiles
#' @inheritParams summarizeMatches
#'
#' @return A [STRComparison] object.
#'
#' @author Jared Andrews
#'
#' @seealso [scoreProfiles()] and [summarizeMatches()] for the individual steps,
#'   [writeSTRResults()] to write the output files.
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
#'
#' cmp <- compareProfiles(q, ref)
#' cmp
#' summary(cmp)
#'
#' # All-against-all within a single set.
#' compareProfiles(ref)
#'
#' @export
compareProfiles <- function(query,
                            reference = NULL,
                            useAmel = FALSE,
                            excludeMarkers = NULL,
                            tanThreshold = 80,
                            masQThreshold = 80,
                            masRThreshold = 80,
                            threeAlleleThreshold = 3,
                            minScore = NULL,
                            minScoreType = c("tanabe", "mastersQuery", "mastersRef"),
                            chunkSize = 2000L) {
    stopifnot(is(query, "STRProfiles"))
    minScoreType <- match.arg(minScoreType)

    selfCompare <- is.null(reference)
    if (selfCompare && nrow(query) < 2L) {
        stop(
            "Only one profile supplied and no reference to compare it against.\n",
            "Pass a 'reference' set, or supply at least two query profiles.",
            call. = FALSE
        )
    }

    sc <- scoreProfiles(
        query = query,
        reference = reference,
        useAmel = useAmel,
        excludeMarkers = excludeMarkers,
        minScore = minScore,
        minScoreType = minScoreType,
        chunkSize = chunkSize
    )

    summ <- summarizeMatches(
        scores = sc,
        profiles = query,
        tanThreshold = tanThreshold,
        masQThreshold = masQThreshold,
        masRThreshold = masRThreshold,
        threeAlleleThreshold = threeAlleleThreshold
    )

    new("STRComparison",
        scores = sc,
        summary = summ,
        query = query,
        reference = if (selfCompare) query else reference,
        params = list(
            useAmel = useAmel,
            excludeMarkers = excludeMarkers,
            tanThreshold = tanThreshold,
            masQThreshold = masQThreshold,
            masRThreshold = masRThreshold,
            threeAlleleThreshold = threeAlleleThreshold,
            minScore = minScore,
            minScoreType = minScoreType,
            selfCompare = selfCompare,
            timestamp = Sys.time(),
            version = .pkgVersion()
        )
    )
}
