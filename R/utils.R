# Internal helpers. Not exported, not documented with roxygen.

#' @importFrom S4Vectors elementNROWS unstrsplit
NULL

# Sample annotations the package computes at ingest rather than reading from the
# input. They live in sampleData() because they are per-sample facts, but
# as.data.frame() leaves them out: every column it emits is read back as a marker
# unless it is named in 'metadataCols', so echoing them would quietly turn a QC
# statistic into a marker on the next round-trip.
.RESERVED_SAMPLE_COLS <- "nDroppedCalls"

# Build an all-empty CharacterList of length n.
.emptyCharacterList <- function(n) {
    IRanges::CharacterList(rep(list(character(0)), n))
}

# Add any missing marker columns as empty, then order columns to match 'mk'.
.padAlleles <- function(al, mk) {
    n <- nrow(al)
    for (m in setdiff(mk, colnames(al))) {
        al[[m]] <- .emptyCharacterList(n)
    }
    al[, mk, drop = FALSE]
}

# Recompute markerData so it stays aligned with the allele columns. Existing
# 'class' assignments are preserved so a manual correction survives subsetting.
.syncMarkerData <- function(al, md = NULL) {
    mk <- colnames(al)
    nTyped <- vapply(as.list(al), function(z) sum(S4Vectors::elementNROWS(z) > 0L), integer(1))

    if (is.null(md) || nrow(md) == 0L || is.null(rownames(md))) {
        md <- S4Vectors::DataFrame(class = classifyMarkers(mk), row.names = mk)
    } else {
        md <- md[match(mk, rownames(md)), , drop = FALSE]
        rownames(md) <- mk
        cls <- classifyMarkers(mk)
        if ("class" %in% colnames(md)) {
            keep <- !is.na(md$class)
            cls[keep] <- md$class[keep]
        }
        md$class <- cls
    }

    md$nTyped <- unname(nTyped)
    md
}

# Turn names/logicals/positions into positional indices, with a clear error.
.resolveIndex <- function(idx, nms, what) {
    if (is.character(idx)) {
        hit <- match(idx, nms)
        if (anyNA(hit)) {
            stop("Unknown ", what, "(s): ", paste(idx[is.na(hit)], collapse = ", "), ".", call. = FALSE)
        }
        return(hit)
    }
    if (is.logical(idx)) {
        if (length(idx) != length(nms)) {
            stop(
                "Logical ", what, " index must have length ", length(nms),
                ", not ", length(idx), ".",
                call. = FALSE
            )
        }
        return(which(idx))
    }
    idx
}

# "samples(4): A B C D" / "markers(20): A B ... Y Z"
.labelledLine <- function(label, values, maxShow = 6L) {
    n <- length(values)
    if (n == 0L) {
        return(paste0(label, "(0):\n"))
    }
    shown <- if (n <= maxShow) {
        values
    } else {
        c(values[seq_len(2L)], "...", values[c(n - 1L, n)])
    }
    paste0(label, "(", n, "): ", paste(shown, collapse = " "), "\n")
}

# rbind two DataFrames, filling columns absent from either with NA.
.rbindFill <- function(a, b) {
    cols <- union(colnames(a), colnames(b))
    rn <- c(rownames(a), rownames(b))

    if (length(cols) == 0L) {
        return(S4Vectors::DataFrame(row.names = rn))
    }
    for (cc in setdiff(cols, colnames(a))) a[[cc]] <- rep(NA_character_, nrow(a))
    for (cc in setdiff(cols, colnames(b))) b[[cc]] <- rep(NA_character_, nrow(b))

    rbind(a[, cols, drop = FALSE], b[, cols, drop = FALSE])
}

# Union two STRProfiles over markers, stacking samples.
.combineTwoProfiles <- function(x, y) {
    if (!is(y, "STRProfiles")) {
        stop("Can only combine 'STRProfiles' objects.", call. = FALSE)
    }

    dup <- intersect(rownames(x@alleles), rownames(y@alleles))
    if (length(dup) > 0L) {
        stop(
            "Duplicated sample names across objects: ", paste(dup, collapse = ", "), ".",
            call. = FALSE
        )
    }

    mk <- union(colnames(x@alleles), colnames(y@alleles))
    al <- rbind(.padAlleles(x@alleles, mk), .padAlleles(y@alleles, mk))

    knownClass <- c(
        stats::setNames(y@markerData$class, rownames(y@markerData)),
        stats::setNames(x@markerData$class, rownames(x@markerData))
    )
    md <- S4Vectors::DataFrame(class = unname(knownClass[mk]), row.names = mk)

    new("STRProfiles",
        alleles = al,
        markerData = .syncMarkerData(al, md),
        sampleData = .rbindFill(x@sampleData, y@sampleData),
        provenance = list(
            files = c(x@provenance$files, y@provenance$files),
            options = x@provenance$options,
            timestamp = Sys.time(),
            version = .pkgVersion(),
            combined = TRUE
        )
    )
}

.pkgVersion <- function() {
    as.character(utils::packageVersion("STRprofilerR"))
}

# Timestamp in the format the Python package uses for output file names.
.fileStamp <- function(time = Sys.time()) {
    format(time, "%Y%m%d.%H_%M_%S")
}
