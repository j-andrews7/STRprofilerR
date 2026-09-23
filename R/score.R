#' Score STR profiles against each other
#'
#' Computes the Tanabe and both Masters similarity scores for every
#' query/reference pair.
#'
#' @details
#' ## The scores
#'
#' Let \eqn{M} be the markers at which *both* profiles were typed (markers with
#' no alleles in either profile are ignored), \eqn{s} the number of alleles
#' shared across those markers, and \eqn{q} and \eqn{r} the number of alleles
#' the query and reference carry across those same markers. Then:
#'
#' \deqn{\textrm{Tanabe} = 100 \times \frac{2s}{q + r}}
#' \deqn{\textrm{Masters (query)} = 100 \times \frac{s}{q}}
#' \deqn{\textrm{Masters (reference)} = 100 \times \frac{s}{r}}
#'
#' Tanabe is the Sorenson-Dice coefficient and is symmetric. The two Masters
#' scores are not: Masters (query) asks how much of the query is explained by
#' the reference, which is the question to ask when the query may be a
#' contaminated or drifted derivative of a known line.
#'
#' Amelogenin is a sex marker rather than a polymorphic STR, so it is excluded
#' by default; set `useAmel = TRUE` to include it.
#'
#' ## Implementation
#'
#' Scoring is expressed as four sparse matrix products rather than a loop over
#' pairs, which is what makes whole-database comparison practical. With
#' \eqn{Q_A}/\eqn{R_A} the binary sample-by-(marker, allele) incidence matrices,
#' \eqn{Q_M}/\eqn{R_M} the binary sample-by-marker "typed" matrices, and
#' \eqn{Q_C}/\eqn{R_C} the sample-by-marker allele counts:
#'
#' ```
#' s <- QA %*% t(RA)    # shared alleles
#' q <- QC %*% t(RM)    # query alleles,     over shared markers only
#' r <- QM %*% t(RC)    # reference alleles, over shared markers only
#' ```
#'
#' An allele can only be shared at a marker where both profiles were typed, so
#' the restriction to shared markers falls out of the products.
#'
#' Results are computed in blocks of `chunkSize` queries so that comparing a
#' large batch against a large database does not need the full
#' query-by-reference matrix in memory at once.
#'
#' ## Divergence from the Python package
#'
#' A pair with no markers in common gives a zero denominator. `strprofiler`
#' raises `ZeroDivisionError` (which its Shiny app catches and reports as
#' `FALSE`); this function returns `NA` for the affected scores and warns once
#' with a count.
#'
#' @param query A [STRProfiles] object holding the profiles to score.
#' @param reference A [STRProfiles] object to score against. If `NULL`, `query`
#'   is compared against itself and self-pairs are dropped.
#' @param useAmel Logical scalar. Include amelogenin markers in scoring.
#' @param excludeMarkers Character vector of additional marker names to leave
#'   out of scoring.
#' @param minScore Optional numeric scalar. Drop pairs scoring below this on
#'   `minScoreType`. Applied per block, so it also bounds memory.
#' @param minScoreType Which score `minScore` applies to.
#' @param chunkSize Number of query profiles to score per block.
#'
#' @return A [S4Vectors::DataFrame] with one row per scored pair and columns
#'   `query`, `reference`, `nSharedMarkers`, `nSharedAlleles`, `nQueryAlleles`,
#'   `nReferenceAlleles`, `tanabeScore`, `mastersQueryScore`, and
#'   `mastersRefScore`. Rows are ordered by query (input order), then by Tanabe
#'   score descending.
#'
#' @author Jared Andrews
#'
#' @references
#' Tanabe H, et al. (1999). Cell line individualization by STR multiplex
#' system in the cell bank found cross-contamination between ECV304 and
#' EA.hy926. *Tissue Culture Research Communications* 18:329-338.
#' \doi{10.11418/jtca1981.18.4_329}
#'
#' Masters JR, et al. (2001). Short tandem repeat profiling provides an
#' international reference standard for human cell lines. *PNAS*
#' 98(14):8012-8017. \doi{10.1073/pnas.121616198}
#'
#' @seealso [compareProfiles()] for scoring plus a per-sample summary,
#'   [summarizeMatches()] to condense the output.
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
#' head(as.data.frame(scores))
#'
#' # All-against-all within one set.
#' scoreProfiles(ref)[1:3, ]
#'
#' # Keep only strong Tanabe hits.
#' scoreProfiles(q, ref, minScore = 90)
#'
#' @export
scoreProfiles <- function(query,
                          reference = NULL,
                          useAmel = FALSE,
                          excludeMarkers = NULL,
                          minScore = NULL,
                          minScoreType = c("tanabe", "mastersQuery", "mastersRef"),
                          chunkSize = 2000L) {
    stopifnot(is(query, "STRProfiles"))
    minScoreType <- match.arg(minScoreType)

    selfCompare <- is.null(reference)
    if (selfCompare) {
        reference <- query
    }
    stopifnot(is(reference, "STRProfiles"))

    # Guard before chunking: seq.int(1L, 0L) counts down rather than being empty.
    if (nrow(query) == 0L || nrow(reference) == 0L) {
        return(.emptyScores())
    }

    mk <- .scoringMarkers(query, reference, useAmel = useAmel, excludeMarkers = excludeMarkers)

    qk <- .alleleKeys(query, mk)
    rk <- .alleleKeys(reference, mk)

    keyLevels <- intersect(unique(qk$key), unique(rk$key))
    QA <- .incidenceMatrix(qk, keyLevels, nrow(query))
    RA <- .incidenceMatrix(rk, keyLevels, nrow(reference))

    QC <- qk$counts
    RC <- rk$counts

    mats <- list(
        QA = QA, RA = RA,
        QC = QC, RC = RC,
        QM = (QC > 0) * 1, RM = (RC > 0) * 1,
        qNames = rownames(query), rNames = rownames(reference)
    )

    chunkSize <- max(as.integer(chunkSize), 1L)
    starts <- seq.int(1L, nrow(query), by = chunkSize)
    blocks <- vector("list", length(starts))
    nEmpty <- 0L

    for (b in seq_along(starts)) {
        idx <- seq.int(starts[[b]], min(starts[[b]] + chunkSize - 1L, nrow(query)))
        chunk <- .scoreChunk(idx, mats, selfCompare, minScore, minScoreType)

        nEmpty <- nEmpty + chunk$nEmpty
        blocks[[b]] <- chunk$scores
    }

    if (nEmpty > 0L) {
        warning(
            nEmpty, " comparison(s) had no markers in common; their scores are NA.",
            call. = FALSE
        )
    }

    blocks <- blocks[!vapply(blocks, is.null, logical(1))]
    out <- if (length(blocks) == 0L) .emptyScores() else do.call(rbind, blocks)

    out[order(match(out$query, mats$qNames), -out$tanabeScore, na.last = TRUE), , drop = FALSE]
}

#' Score a single profile against a reference set
#'
#' A convenience wrapper around [scoreProfiles()] for scoring one hand-entered
#' profile, as an interactive session or a query form would.
#'
#' @param x A named character vector or list mapping marker names to
#'   comma-separated allele calls.
#' @param reference A [STRProfiles] object to score against.
#' @param sample Name to label the query with.
#' @param pentaFix Logical scalar. Harmonise Penta marker spellings in `x`.
#' @inheritParams scoreProfiles
#' @inheritParams readSTRProfiles
#'
#' @return A [S4Vectors::DataFrame] as returned by [scoreProfiles()].
#'
#' @author Jared Andrews
#'
#' @seealso [scoreProfiles()], which this calls.
#'
#' @examples
#' ref <- readSTRProfiles(
#'     system.file("extdata", "ExampleSTR_database.csv", package = "STRprofilerR"),
#'     sampleCol = "Sample Name"
#' )
#'
#' scoreQuery(
#'     c(marker1 = "12,14", marker2 = "12", marker4 = "13", AMEL = "X"),
#'     ref
#' )
#'
#' @export
scoreQuery <- function(x,
                       reference,
                       sample = "Query",
                       useAmel = FALSE,
                       excludeMarkers = NULL,
                       pentaFix = TRUE,
                       keepCalls = c("X", "Y")) {
    x <- as.list(x)
    if (is.null(names(x)) || !all(nzchar(names(x)))) {
        stop("'x' must be fully named, with one name per marker.", call. = FALSE)
    }

    df <- data.frame(
        c(stats::setNames(list(sample), "Sample"), lapply(x, as.character)),
        check.names = FALSE,
        stringsAsFactors = FALSE
    )

    scoreProfiles(
        STRProfiles(df, pentaFix = pentaFix, keepCalls = keepCalls),
        reference,
        useAmel = useAmel,
        excludeMarkers = excludeMarkers
    )
}


## ---------------------------------------------------------------------------
## Internals
## ---------------------------------------------------------------------------

# Score one block of queries against every reference. Returns the long-form
# rows plus how many pairs had no markers in common.
.scoreChunk <- function(idx, mats, selfCompare, minScore, minScoreType) {
    sharedAlleles <- as.matrix(Matrix::tcrossprod(mats$QA[idx, , drop = FALSE], mats$RA))
    sharedMarkers <- mats$QM[idx, , drop = FALSE] %*% t(mats$RM)
    nQuery <- mats$QC[idx, , drop = FALSE] %*% t(mats$RM)
    nRef <- mats$QM[idx, , drop = FALSE] %*% t(mats$RC)

    tanabe <- 100 * 2 * sharedAlleles / (nQuery + nRef)
    mastersQ <- 100 * sharedAlleles / nQuery
    mastersR <- 100 * sharedAlleles / nRef

    nEmpty <- sum(is.nan(tanabe))
    tanabe[is.nan(tanabe)] <- NA_real_
    mastersQ[is.nan(mastersQ)] <- NA_real_
    mastersR[is.nan(mastersR)] <- NA_real_

    keep <- if (selfCompare) {
        outer(mats$qNames[idx], mats$rNames, FUN = "!=")
    } else {
        matrix(TRUE, nrow = length(idx), ncol = length(mats$rNames))
    }

    if (!is.null(minScore)) {
        score <- switch(minScoreType,
            tanabe = tanabe,
            mastersQuery = mastersQ,
            mastersRef = mastersR
        )
        keep <- keep & !is.na(score) & score >= minScore
    }

    pos <- which(keep, arr.ind = TRUE)
    if (nrow(pos) == 0L) {
        return(list(scores = NULL, nEmpty = nEmpty))
    }

    list(
        scores = S4Vectors::DataFrame(
            query = mats$qNames[idx][pos[, "row"]],
            reference = mats$rNames[pos[, "col"]],
            nSharedMarkers = as.integer(sharedMarkers[pos]),
            nSharedAlleles = as.integer(sharedAlleles[pos]),
            nQueryAlleles = as.integer(nQuery[pos]),
            nReferenceAlleles = as.integer(nRef[pos]),
            tanabeScore = as.numeric(tanabe[pos]),
            mastersQueryScore = as.numeric(mastersQ[pos]),
            mastersRefScore = as.numeric(mastersR[pos])
        ),
        nEmpty = nEmpty
    )
}

.emptyScores <- function() {
    S4Vectors::DataFrame(
        query = character(0),
        reference = character(0),
        nSharedMarkers = integer(0),
        nSharedAlleles = integer(0),
        nQueryAlleles = integer(0),
        nReferenceAlleles = integer(0),
        tanabeScore = numeric(0),
        mastersQueryScore = numeric(0),
        mastersRefScore = numeric(0)
    )
}

# Marker classes recorded on the object, falling back to the name heuristic.
.markerClass <- function(x, mk) {
    md <- markerData(x)
    cls <- as.character(md$class[match(mk, rownames(md))])
    unknown <- is.na(cls)
    cls[unknown] <- classifyMarkers(mk[unknown])
    cls
}

.scoringMarkers <- function(query, reference, useAmel, excludeMarkers) {
    mk <- intersect(markers(query), markers(reference))
    if (length(mk) == 0L) {
        stop(
            "No markers in common between the query and reference profiles.\n",
            "Query markers: ", paste(markers(query), collapse = ", "), "\n",
            "Reference markers: ", paste(markers(reference), collapse = ", "),
            call. = FALSE
        )
    }

    if (!useAmel) {
        isAmel <- .markerClass(query, mk) == "amelogenin" |
            .markerClass(reference, mk) == "amelogenin"
        mk <- mk[!isAmel]
    }
    if (!is.null(excludeMarkers)) {
        mk <- setdiff(mk, excludeMarkers)
    }

    if (length(mk) == 0L) {
        stop(
            "No markers left to score after excluding amelogenin and 'excludeMarkers'.",
            call. = FALSE
        )
    }
    mk
}

# Flatten a STRProfiles into (row, marker-allele key) pairs plus a
# samples-by-markers allele count matrix.
.alleleKeys <- function(x, mk) {
    al <- alleles(x)[, mk, drop = FALSE]
    n <- nrow(al)

    per <- lapply(seq_along(mk), function(j) {
        col <- al[[j]]
        len <- as.integer(S4Vectors::elementNROWS(col))
        flat <- unlist(col, use.names = FALSE)

        list(
            row = rep.int(seq_len(n), len),
            # paste0() recycles a zero-length argument to "", so a marker that
            # nobody was typed at would otherwise emit one phantom key.
            key = if (length(flat) == 0L) character(0) else paste0(j, "\r", flat),
            len = len
        )
    })

    counts <- matrix(
        unlist(lapply(per, `[[`, "len"), use.names = FALSE),
        nrow = n, ncol = length(mk)
    )

    list(
        row = unlist(lapply(per, `[[`, "row"), use.names = FALSE),
        key = unlist(lapply(per, `[[`, "key"), use.names = FALSE),
        counts = counts
    )
}

.incidenceMatrix <- function(keys, keyLevels, nSamples) {
    j <- match(keys$key, keyLevels)
    keep <- !is.na(j)

    Matrix::sparseMatrix(
        i = keys$row[keep],
        j = j[keep],
        x = rep(1, sum(keep)),
        dims = c(nSamples, length(keyLevels))
    )
}
