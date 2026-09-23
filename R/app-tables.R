# Table building for the Shiny application. Nothing here is reactive, so it can
# be tested without a Shiny session; only .resultsDT() needs DT.

# Score choices shared by the single query and CLASTR controls. The values are
# the algorithm names compareProfiles() and clastrQuery() take.
.SCORE_CHOICES <- c(
    "Tanabe" = "tanabe",
    "Masters Query" = "mastersQuery",
    "Masters Reference" = "mastersRef"
)

.SCORE_COLUMNS <- c(
    tanabe = "tanabeScore",
    mastersQuery = "mastersQueryScore",
    mastersRef = "mastersRefScore"
)

.SCORE_LABELS <- c(
    tanabe = "Tanabe Score",
    mastersQuery = "Masters Query Score",
    mastersRef = "Masters Ref Score"
)

# summary() columns shown in the batch results, and the labels strprofiler's app
# gives them.
.BATCH_LABELS <- c(
    Sample = "Sample",
    mixed = "Mixed Sample",
    topHit = "Top Match",
    nextBest = "Next Best Match",
    tanabeMatches = "Tanabe Matches",
    mastersQueryMatches = "Masters Query Matches",
    mastersRefMatches = "Masters Ref Matches"
)

.MISMATCH_COLOUR <- "#ec7a80"

# One hand-entered profile as an STRProfiles object, or NULL when nothing valid
# was typed. Calls are cleaned exactly as they are at ingest, so a query of only
# discarded calls (e.g. "OL") counts as empty, as it does from strprofiler 0.5.1.
.queryProfile <- function(values, sample = "Query") {
    values <- vapply(values, function(v) if (is.null(v) || is.na(v)) "" else as.character(v), character(1))
    df <- data.frame(
        c(stats::setNames(list(sample), "Sample"), as.list(values)),
        check.names = FALSE,
        stringsAsFactors = FALSE
    )

    # Every name is a marker here; the database's metadata never reaches the form.
    q <- STRProfiles(df, metadataCols = character(0))
    if (.nAlleles(q) == 0L) NULL else q
}

.nAlleles <- function(x) {
    sum(vapply(as.list(alleles(x)), function(z) sum(S4Vectors::elementNROWS(z)), integer(1)))
}

# A database's metadata columns (Center, Passage, ...) for the given samples,
# blank where a sample is not in the database.
.metadataColumns <- function(reference, samples) {
    sd <- sampleData(reference)
    sd <- sd[, setdiff(colnames(sd), .RESERVED_SAMPLE_COLS), drop = FALSE]

    idx <- match(samples, rownames(sd))
    out <- lapply(as.list(sd), function(z) {
        v <- as.character(z)[idx]
        v[is.na(v)] <- ""
        v
    })
    as.data.frame(out, check.names = FALSE, stringsAsFactors = FALSE)
}

# The single query report: the query first, then every reference at or above
# 'threshold' on the chosen score, best first. Mirrors strprofiler's
# _single_query(), including rounding before filtering.
.singleQueryTable <- function(query,
                              reference,
                              useAmel = FALSE,
                              mixThreshold = 3,
                              scoreType = c("tanabe", "mastersQuery", "mastersRef"),
                              threshold = 80) {
    scoreType <- match.arg(scoreType)
    scoreCol <- .SCORE_COLUMNS[[scoreType]]
    sample <- rownames(query)[[1L]]

    cmp <- compareProfiles(
        query, reference,
        useAmel = useAmel,
        threeAlleleThreshold = mixThreshold
    )
    tab <- .perSampleTable(cmp, sample)
    tab[[scoreCol]] <- round(tab[[scoreCol]], 2)

    hits <- tab[-1L, , drop = FALSE]
    hits <- hits[!is.na(hits[[scoreCol]]) & hits[[scoreCol]] >= threshold, , drop = FALSE]
    hits <- hits[order(-hits[[scoreCol]]), , drop = FALSE]
    tab <- rbind(tab[1L, , drop = FALSE], hits)

    markerCols <- union(markers(query), markers(reference))

    out <- data.frame(
        Sample = tab$Sample,
        "Mixed Sample" = tab$mixed,
        "Shared Markers" = tab$nSharedMarkers,
        "Shared Alleles" = tab$nSharedAlleles,
        check.names = FALSE,
        stringsAsFactors = FALSE
    )
    out[[.SCORE_LABELS[[scoreType]]]] <- tab[[scoreCol]]

    meta <- .metadataColumns(reference, tab$Sample)
    if (ncol(meta) > 0L) {
        out <- cbind(out, meta)
    }
    out <- cbind(out, tab[, markerCols, drop = FALSE])
    rownames(out) <- NULL

    list(table = out, download = out, markers = markerCols, scoreCol = .SCORE_LABELS[[scoreType]])
}

# The CLASTR report for one query: the query first, then CLASTR's hits.
# 'hits' is clastrQuery() output for this query only. The display table links
# each accession to Cellosaurus and flags problematic lines, as strprofiler's
# app does; the download keeps clastrQuery()'s own columns.
.clastrQueryTable <- function(query, hits) {
    hits <- as.data.frame(hits, optional = TRUE)
    qFlat <- .flatTable(query)
    markerCols <- union(markers(query), setdiff(colnames(hits), .clastrColumns()))

    cell <- function(d, m) {
        v <- if (m %in% colnames(d)) as.character(d[[m]]) else rep("", nrow(d))
        v[is.na(v)] <- ""
        v
    }
    problem <- cell(hits, "problem")

    links <- vapply(seq_len(nrow(hits)), function(i) {
        style <- if (nzchar(problem[[i]])) {
            sprintf(
                " title=\"%s\" style=\"font-style:oblique;color:%s\"",
                .escapeHTML(problem[[i]]), .MISMATCH_COLOUR
            )
        } else {
            ""
        }
        sprintf(
            "<a href=\"%s\" target=\"_blank\" rel=\"noopener\"%s>%s</a>",
            .escapeHTML(hits$accessionLink[[i]]), style, .escapeHTML(hits$accession[[i]])
        )
    }, character(1))

    display <- data.frame(
        Accession = c("Query", links),
        Name = c("", cell(hits, "name")),
        Score = c(NA_real_, round(as.numeric(hits$score), 2)),
        check.names = FALSE,
        stringsAsFactors = FALSE
    )

    queryRow <- data.frame(
        query = rownames(query)[[1L]],
        accession = "Query",
        name = "",
        species = "",
        score = NA_real_,
        accessionLink = "",
        problem = "",
        stringsAsFactors = FALSE
    )
    download <- rbind(queryRow, hits[, .clastrColumns(), drop = FALSE])

    for (m in markerCols) {
        values <- c(cell(qFlat, m), cell(hits, m))
        display[[m]] <- values
        download[[m]] <- values
    }
    rownames(display) <- NULL
    rownames(download) <- NULL

    list(table = display, download = download, markers = markerCols, scoreCol = "Score", html = "Accession")
}

# The batch report: summary(cmp) without the allele columns, labelled as in
# strprofiler's app. A missing hit is blank rather than NA.
.batchSummaryTable <- function(cmp) {
    s <- as.data.frame(summary(cmp), optional = TRUE)
    s <- s[, intersect(names(.BATCH_LABELS), colnames(s)), drop = FALSE]
    names(s) <- unname(.BATCH_LABELS[colnames(s)])

    s[] <- lapply(s, function(z) {
        if (is.character(z)) z[is.na(z)] <- ""
        z
    })
    rownames(s) <- NULL
    s
}

# Compare a batch file against the database (or against itself when
# 'reference' is NULL). As in strprofiler 0.5.1, a file naming markers the
# database lacks is rejected rather than scored on the overlap.
.batchCompare <- function(query,
                          reference = NULL,
                          useAmel = FALSE,
                          mixThreshold = 3,
                          tanThreshold = 80,
                          masQThreshold = 80,
                          masRThreshold = 80) {
    if (!is.null(reference)) {
        bad <- setdiff(markers(query), markers(reference))
        if (length(bad) > 0L) {
            stop(
                "Marker(s): ", paste0("'", bad, "'", collapse = ", "),
                " are incompatible with the loaded database.",
                call. = FALSE
            )
        }
    }

    compareProfiles(
        query, reference,
        useAmel = useAmel,
        tanThreshold = tanThreshold,
        masQThreshold = masQThreshold,
        masRThreshold = masRThreshold,
        threeAlleleThreshold = mixThreshold
    )
}

# Markers in 'query' CLASTR will not recognise, in CLASTR's spelling. Only typed
# markers are sent, so only those are checked.
.clastrIncompatible <- function(query) {
    sent <- unique(unlist(lapply(.asClastrProfiles(query), names), use.names = FALSE))
    validateClastrMarkers(sent)
}

# clastrQuery() without its unrecognised-marker warning, which the app reports
# once, up front, rather than once per profile.
.quietClastrQuery <- function(query, ...) {
    withCallingHandlers(
        clastrQuery(query, ...),
        warning = function(w) {
            if (grepl("not recognised by CLASTR", conditionMessage(w), fixed = TRUE)) {
                invokeRestart("muffleWarning")
            }
        }
    )
}

# Query CLASTR one profile at a time so progress can be reported, and stack the
# results. 'progress' is called with the index and name before each query.
.batchClastr <- function(query, ..., progress = NULL) {
    parts <- lapply(seq_len(nrow(query)), function(i) {
        if (!is.null(progress)) {
            progress(i, rownames(query)[[i]])
        }
        .quietClastrQuery(query[i, ], ...)
    })
    Reduce(.rbindFill, parts)
}

# Flag every marker cell that differs from the query's (the first row). Both
# sides are cleaned, sorted allele strings, so "14, 12" typed into the form
# matches "12,14" in the database.
.mismatchFlags <- function(x, cols) {
    flags <- lapply(cols, function(m) {
        v <- as.character(x[[m]])
        v[is.na(v)] <- ""
        as.integer(v != v[[1L]])
    })
    names(flags) <- cols
    as.data.frame(flags, check.names = FALSE)
}

# Render a results table as a DT widget. Marker columns are centred and cells
# differing from the query row highlighted; 'html' names columns already built
# as escaped HTML.
.resultsDT <- function(x, markerCols = character(0), html = character(0), scoreCols = character(0)) {
    x <- as.data.frame(x, optional = TRUE)
    x[] <- lapply(x, function(z) {
        if (is.logical(z)) ifelse(is.na(z), "", ifelse(z, "TRUE", "FALSE")) else z
    })
    visible <- colnames(x)

    defs <- list()
    flagCols <- character(0)
    if (length(markerCols) > 0L && nrow(x) > 0L) {
        flags <- .mismatchFlags(x, markerCols)
        flagCols <- paste0(".mismatch", seq_along(markerCols))
        names(flags) <- flagCols
        x <- cbind(x, flags)
        defs <- list(
            list(visible = FALSE, targets = match(flagCols, colnames(x)) - 1L),
            list(
                className = "dt-center",
                targets = match(markerCols, colnames(x)) - 1L,
                # Sorting comma-joined allele strings is not meaningful, and the
                # sort arrows would widen every marker column.
                orderable = FALSE,
                # Let multi-allele cells wrap after a comma so the table fits
                # its card. Display only: sorting, search, and downloads see the
                # plain value.
                render = DT::JS(
                    "function(data, type) {",
                    "  return type === 'display' && typeof data === 'string' ? data.replace(/,/g, ',<wbr>') : data;",
                    "}"
                )
            )
        )
    }

    widget <- DT::datatable(
        x,
        rownames = FALSE,
        escape = if (length(html)) setdiff(visible, html) else TRUE,
        selection = "none",
        # Bootstrap 5's compact table; DT's own "compact" maps to Bootstrap 3's.
        class = "display table-sm",
        # bslib cards are fill containers, which would otherwise stretch the
        # table to an arbitrary height.
        fillContainer = FALSE,
        # No scrollX: columns shrink and wrap to fit the card instead.
        options = list(
            pageLength = 25,
            autoWidth = FALSE,
            columnDefs = defs,
            # Defined in the page head by .fitTablesJS().
            drawCallback = DT::JS(
                "function() {",
                "  if (window.strprofilerFitTable) strprofilerFitTable(this.api().table().node());",
                "}"
            )
        )
    )

    if (length(flagCols) > 0L) {
        widget <- DT::formatStyle(
            widget,
            columns = markerCols,
            valueColumns = flagCols,
            backgroundColor = DT::styleEqual(1L, .MISMATCH_COLOUR),
            color = DT::styleEqual(1L, "#212529")
        )
    }
    scoreCols <- intersect(scoreCols, visible)
    if (length(scoreCols) > 0L) {
        widget <- DT::formatRound(widget, scoreCols, digits = 2)
    }
    widget
}

# File extensions the upload controls accept. xlsx needs readxl.
.uploadAccept <- function() {
    c(".csv", ".tsv", ".txt", if (requireNamespace("readxl", quietly = TRUE)) c(".xlsx", ".xls"))
}

# Read a fileInput() upload, recording the name the user gave the file rather
# than Shiny's temporary path.
.readUpload <- function(file, sampleCol = "Sample", markerCol = "Marker") {
    p <- readSTRProfiles(file$datapath[[1L]], sampleCol = sampleCol, markerCol = markerCol)
    p@provenance$files <- file$name[[1L]]
    p
}

# "STR_Query_Results_2026-09-23-14h-05m.csv", stamped at download time.
.downloadName <- function(prefix, sep, ext, time = Sys.time()) {
    paste0(prefix, format(time, "%Y-%m-%d"), sep, format(time, "%Hh-%Mm"), ".", ext)
}
