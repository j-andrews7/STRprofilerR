#' Summarise pairwise scores into one row per query
#'
#' Condenses the pair-level output of [scoreProfiles()] into a per-query
#' overview: the best hits, every hit passing each score threshold, and an
#' optional mixing flag and copy of the query's alleles.
#'
#' @details
#' Hits are reported as `"name: score"`, joined by `"; "`, with scores shown to
#' two decimal places. Each of the three match columns is ordered by its own
#' score, descending. `topHit` and `nextBest` use the Tanabe score.
#'
#' If `scores` was filtered (via the `minScore` argument of [scoreProfiles()]),
#' the summary reflects only the pairs that survived.
#'
#' ## Divergences from the Python package
#'
#' `strprofiler` reads the top two hits positionally out of a table whose first
#' row is the query itself, reporting an empty string when a query has fewer than
#' two comparisons (through 0.4.2 it raised an `IndexError`). Here a query with no
#' comparisons gets `NA` for both, and one with a single comparison gets `NA` for
#' `nextBest`.
#'
#' `strprofiler` orders all three match columns by Tanabe score, so the Masters
#' columns come out in an order unrelated to their own values. Each column is
#' sorted on its own score here.
#'
#' @param scores A [S4Vectors::DataFrame] of pairwise scores from
#'   [scoreProfiles()].
#' @param profiles Optional [STRProfiles] of the query profiles. When supplied,
#'   a `mixed` column and the query's allele columns are added.
#' @param tanThreshold Minimum Tanabe score to report in `tanabeMatches`.
#' @param masQThreshold Minimum Masters (query) score to report in
#'   `mastersQueryMatches`.
#' @param masRThreshold Minimum Masters (reference) score to report in
#'   `mastersRefMatches`.
#' @param threeAlleleThreshold Passed to [flagMixedSamples()]. Ignored when
#'   `profiles` is `NULL`.
#' @param includeAlleles Logical scalar. Append the query's allele columns.
#'   Ignored when `profiles` is `NULL`.
#'
#' @return A [S4Vectors::DataFrame] with one row per query sample and columns
#'   `Sample`, `mixed` (optional), `topHit`, `nextBest`, `tanabeMatches`,
#'   `mastersQueryMatches`, `mastersRefMatches`, followed by the allele columns.
#'
#' @author Jared Andrews
#'
#' @seealso [scoreProfiles()] to produce `scores`, [compareProfiles()] to do
#'   both in one call.
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
#' scores <- scoreProfiles(q, ref)
#' summarizeMatches(scores, q)
#'
#' # Scores only, without the mixing flag or alleles.
#' summarizeMatches(scores)
#'
#' @export
summarizeMatches <- function(scores,
                             profiles = NULL,
                             tanThreshold = 80,
                             masQThreshold = 80,
                             masRThreshold = 80,
                             threeAlleleThreshold = 3,
                             includeAlleles = TRUE) {
    scores <- as(scores, "DataFrame")

    samples <- if (is.null(profiles)) unique(scores$query) else rownames(profiles)
    byQuery <- split(seq_len(nrow(scores)), factor(scores$query, levels = samples))

    out <- S4Vectors::DataFrame(
        Sample = samples,
        topHit = .bestHit(scores, byQuery, "tanabeScore", 1L),
        nextBest = .bestHit(scores, byQuery, "tanabeScore", 2L),
        tanabeMatches = .matchList(scores, byQuery, "tanabeScore", tanThreshold),
        mastersQueryMatches = .matchList(scores, byQuery, "mastersQueryScore", masQThreshold),
        mastersRefMatches = .matchList(scores, byQuery, "mastersRefScore", masRThreshold),
        row.names = samples
    )

    if (!is.null(profiles)) {
        stopifnot(is(profiles, "STRProfiles"))

        mixed <- flagMixedSamples(profiles, threeAlleleThreshold = threeAlleleThreshold)
        out <- cbind(
            out[, "Sample", drop = FALSE],
            S4Vectors::DataFrame(mixed = unname(mixed[samples]), row.names = samples),
            out[, setdiff(colnames(out), "Sample"), drop = FALSE]
        )

        if (includeAlleles) {
            # unstrsplit() drops names, so restore them to reorder by sample,
            # then drop them again: a DataFrame column should not carry them.
            flat <- lapply(as.list(alleles(profiles)), function(z) {
                unname(stats::setNames(S4Vectors::unstrsplit(z, ","), rownames(profiles))[samples])
            })
            out <- cbind(out, S4Vectors::DataFrame(flat, row.names = samples, check.names = FALSE))
        }
    }

    out
}


## ---------------------------------------------------------------------------
## Internals
## ---------------------------------------------------------------------------

# Format a score the way the summary columns show it.
.formatScore <- function(x) {
    formatC(x, format = "f", digits = 2)
}

# "name: score" for the n-th best hit on 'column', or NA where there is none.
.bestHit <- function(scores, byQuery, column, n) {
    vapply(byQuery, function(idx) {
        if (length(idx) == 0L) {
            return(NA_character_)
        }
        idx <- idx[order(-scores[[column]][idx], na.last = TRUE)]
        if (length(idx) < n) {
            return(NA_character_)
        }

        hit <- idx[[n]]
        if (is.na(scores[[column]][hit])) {
            return(NA_character_)
        }
        paste0(scores$reference[hit], ": ", .formatScore(scores[[column]][hit]))
    }, character(1), USE.NAMES = FALSE)
}

# "a: 92.31; b: 88.00" for every hit at or above 'threshold' on 'column'.
.matchList <- function(scores, byQuery, column, threshold) {
    vapply(byQuery, function(idx) {
        if (length(idx) == 0L) {
            return("")
        }
        value <- scores[[column]][idx]
        idx <- idx[!is.na(value) & value >= threshold]
        if (length(idx) == 0L) {
            return("")
        }

        idx <- idx[order(-scores[[column]][idx])]
        paste(
            paste0(scores$reference[idx], ": ", .formatScore(scores[[column]][idx])),
            collapse = "; "
        )
    }, character(1), USE.NAMES = FALSE)
}
