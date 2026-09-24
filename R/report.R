#' Write comparison results to disk
#'
#' Writes a [STRComparison] out as the file set the `strprofiler` command line
#' tool produces: a summary table, one table per query sample, an HTML view of
#' the summary, and a log recording the parameters used.
#'
#' @details
#' Files are named with an `STRprofilerR` prefix where the Python package uses
#' `strprofiler`, so results from the two are distinguishable.
#'
#' Written into `dir`, with `<stamp>` a `YYYYMMDD.HH_MM_SS` timestamp:
#'
#' \describe{
#'   \item{`full_summary.STRprofilerR.<stamp>.csv`}{One row per query: the
#'     mixing flag, top two hits, and every hit passing each threshold.}
#'   \item{`<sample>.STRprofilerR.<stamp>.csv`}{One file per query, listing every
#'     reference it was compared against with the scores and that reference's
#'     alleles. The query itself is the first row.}
#'   \item{`full_summary.STRprofilerR.<stamp>.html`}{The summary as a browsable
#'     table.}
#'   \item{`STRprofilerR.<stamp>.log`}{Parameters, input files, and package and R
#'     versions.}
#' }
#'
#' Sample names are sanitised for use as file names, so a query called
#' `HT-29/P3` is written as `HT-29_P3.STRprofilerR.<stamp>.csv`. The name inside
#' the file is untouched.
#'
#' The HTML is written with `DT` when `DT`, `htmlwidgets`, and `pandoc` are all
#' available, giving a sortable, searchable, self-contained table. Otherwise a
#' plain styled HTML table is written instead. Either way the file stands alone,
#' unlike the Python package's output, which pulls jQuery and DataTables from a
#' CDN at view time.
#'
#' @param x A [STRComparison] object.
#' @param dir Directory to write into. Created if it does not exist.
#' @param formats Which outputs to write. Any of `"csv"`, `"html"`, and
#'   `"xlsx"`. The `xlsx` summary needs the `writexl` package.
#' @param perSample Logical scalar. Write the per-query comparison tables.
#'   Ignored unless `"csv"` is in `formats`.
#' @param timestamp A `POSIXct` used to stamp the file names.
#' @param prefix File name prefix.
#'
#' @return Invisibly, a named character vector of the paths written.
#'
#' @author Jared Andrews
#'
#' @seealso [compareProfiles()] to produce `x`.
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
#' out <- file.path(tempdir(), "STRprofilerR-demo")
#' written <- writeSTRResults(compareProfiles(q, ref), out)
#' basename(written)
#'
#' @export
writeSTRResults <- function(x,
                            dir,
                            formats = c("csv", "html"),
                            perSample = TRUE,
                            timestamp = Sys.time(),
                            prefix = "STRprofilerR") {
    stopifnot(is(x, "STRComparison"))
    formats <- match.arg(formats, c("csv", "html", "xlsx"), several.ok = TRUE)

    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    stamp <- .fileStamp(timestamp)
    written <- character(0)

    summ <- as.data.frame(summary(x))
    base <- file.path(dir, paste0("full_summary.", prefix, ".", stamp))

    if ("csv" %in% formats) {
        utils::write.csv(summ, paste0(base, ".csv"), row.names = FALSE, na = "")
        written <- c(written, summary = paste0(base, ".csv"))

        if (perSample) {
            for (s in rownames(queryProfiles(x))) {
                path <- file.path(
                    dir, paste0(.safeFileName(s), ".", prefix, ".", stamp, ".csv")
                )
                utils::write.csv(.perSampleTable(x, s), path, row.names = FALSE, na = "")
                written <- c(written, stats::setNames(path, s))
            }
        }
    }

    if ("html" %in% formats) {
        strHTMLTable(summ, paste0(base, ".html"))
        written <- c(written, html = paste0(base, ".html"))
    }

    if ("xlsx" %in% formats) {
        if (!requireNamespace("writexl", quietly = TRUE)) {
            warning(
                "Writing xlsx needs the 'writexl' package; skipping the xlsx summary.",
                call. = FALSE
            )
        } else {
            writexl::write_xlsx(summ, paste0(base, ".xlsx"))
            written <- c(written, xlsx = paste0(base, ".xlsx"))
        }
    }

    logPath <- file.path(dir, paste0(prefix, ".", stamp, ".log"))
    writeLines(.resultLog(x, timestamp), logPath)
    written <- c(written, log = logPath)

    invisible(written)
}

#' Write a data frame as a standalone HTML table
#'
#' Writes a table to a self-contained HTML file, interactive where the optional
#' packages allow and static otherwise.
#'
#' @details
#' When `DT`, `htmlwidgets`, and `pandoc` are all available the table is written
#' as a `DT` widget: sortable, searchable, and paged. Otherwise a plain HTML
#' table with embedded styling is written. Both forms are self-contained and
#' render offline.
#'
#' @param x A `data.frame`.
#' @param file Path to write to.
#' @param title Page title.
#'
#' @return Invisibly, the path written to.
#'
#' @author Jared Andrews
#'
#' @seealso [writeSTRResults()], which calls this for the summary table.
#'
#' @examples
#' f <- file.path(tempdir(), "table.html")
#' strHTMLTable(head(iris), f)
#' file.exists(f)
#'
#' @export
strHTMLTable <- function(x, file, title = "STRprofiler Results") {
    x <- as.data.frame(x)

    interactive <- requireNamespace("DT", quietly = TRUE) &&
        requireNamespace("htmlwidgets", quietly = TRUE) &&
        requireNamespace("rmarkdown", quietly = TRUE) &&
        rmarkdown::pandoc_available("1.12.3")

    if (interactive) {
        widget <- DT::datatable(
            x,
            rownames = FALSE,
            filter = "top",
            caption = title,
            options = list(pageLength = 25, scrollX = TRUE)
        )

        # saveWidget() stages its dependencies in a "<name>_files" directory
        # beside the output and does not always clean it up, so build in a
        # scratch directory and move only the bundled HTML into place.
        scratch <- file.path(tempdir(), paste0("strHTMLTable-", basename(tempfile(""))))
        dir.create(scratch, recursive = TRUE, showWarnings = FALSE)
        on.exit(unlink(scratch, recursive = TRUE), add = TRUE)

        staged <- file.path(scratch, "index.html")
        htmlwidgets::saveWidget(widget, staged, selfcontained = TRUE, title = title)

        if (!file.copy(staged, file, overwrite = TRUE)) {
            stop("Could not write the HTML table to '", file, "'.", call. = FALSE)
        }
    } else {
        writeLines(.staticHTMLTable(x, title), file)
    }

    invisible(file)
}


## ---------------------------------------------------------------------------
## Internals
## ---------------------------------------------------------------------------

.safeFileName <- function(x) {
    out <- gsub("[^A-Za-z0-9._-]+", "_", x)
    out[!nzchar(out)] <- "sample"
    out
}

# Comma-joined alleles as a plain data.frame, one row per sample.
.flatTable <- function(p) {
    cols <- lapply(as.list(alleles(p)), function(z) {
        stats::setNames(S4Vectors::unstrsplit(z, ","), rownames(p))
    })
    as.data.frame(
        cols,
        check.names = FALSE, stringsAsFactors = FALSE, row.names = rownames(p)
    )
}

# One query's comparisons, with the query itself as the first row. Mirrors the
# per-sample CSV the Python package writes.
.perSampleTable <- function(x, sample) {
    sc <- scores(x)
    rows <- sc[sc$query == sample, , drop = FALSE]

    qFlat <- .flatTable(queryProfiles(x))
    rFlat <- .flatTable(referenceProfiles(x))
    allMarkers <- union(names(qFlat), names(rFlat))

    pad <- function(d, n) {
        for (m in setdiff(allMarkers, names(d))) d[[m]] <- rep("", n)
        d[, allMarkers, drop = FALSE]
    }

    mixed <- summary(x)$mixed[match(sample, summary(x)$Sample)]

    head <- data.frame(
        Sample = sample,
        mixed = mixed,
        querySample = TRUE,
        nSharedMarkers = NA_integer_,
        nSharedAlleles = NA_integer_,
        nQueryAlleles = NA_integer_,
        nReferenceAlleles = NA_integer_,
        tanabeScore = NA_real_,
        mastersQueryScore = NA_real_,
        mastersRefScore = NA_real_,
        stringsAsFactors = FALSE
    )
    head <- cbind(head, pad(qFlat[sample, , drop = FALSE], 1L))

    if (nrow(rows) == 0L) {
        rownames(head) <- NULL
        return(head)
    }

    body <- data.frame(
        Sample = rows$reference,
        mixed = NA,
        querySample = FALSE,
        nSharedMarkers = rows$nSharedMarkers,
        nSharedAlleles = rows$nSharedAlleles,
        nQueryAlleles = rows$nQueryAlleles,
        nReferenceAlleles = rows$nReferenceAlleles,
        tanabeScore = rows$tanabeScore,
        mastersQueryScore = rows$mastersQueryScore,
        mastersRefScore = rows$mastersRefScore,
        stringsAsFactors = FALSE
    )
    body <- cbind(body, pad(rFlat[rows$reference, , drop = FALSE], nrow(rows)))

    out <- rbind(head, body)
    rownames(out) <- NULL
    out
}

.resultLog <- function(x, timestamp) {
    p <- params(x)
    q <- queryProfiles(x)
    r <- referenceProfiles(x)

    fmt <- function(v) {
        if (is.null(v)) "NULL" else paste(v, collapse = ", ")
    }

    c(
        "STRprofilerR comparison log",
        paste0("Run on: ", format(timestamp, "%Y-%m-%d %H:%M:%S")),
        paste0("STRprofilerR version: ", .pkgVersion()),
        paste0("R version: ", R.version.string),
        "",
        "Parameters:",
        paste0("  Tanabe threshold: ", p$tanThreshold),
        paste0("  Masters (query) threshold: ", p$masQThreshold),
        paste0("  Masters (reference) threshold: ", p$masRThreshold),
        paste0("  Mixing threshold: ", p$threeAlleleThreshold),
        paste0("  Score amelogenin: ", p$useAmel),
        paste0("  Excluded markers: ", fmt(p$excludeMarkers)),
        paste0("  Minimum score: ", fmt(p$minScore), " (", p$minScoreType, ")"),
        paste0("  Self comparison: ", p$selfCompare),
        "",
        "Query:",
        paste0("  Files: ", fmt(provenance(q)$files)),
        paste0("  Profiles: ", nrow(q)),
        paste0("  Markers: ", fmt(markers(q))),
        "",
        "Reference:",
        paste0("  Files: ", fmt(provenance(r)$files)),
        paste0("  Profiles: ", nrow(r)),
        paste0("  Markers: ", fmt(markers(r))),
        "",
        paste0("Comparisons written: ", nrow(scores(x)))
    )
}

.escapeHTML <- function(x) {
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    gsub("\"", "&quot;", x, fixed = TRUE)
}

.staticHTMLTable <- function(x, title) {
    cells <- lapply(x, function(col) {
        col <- as.character(col)
        col[is.na(col)] <- ""
        .escapeHTML(col)
    })

    header <- paste0("<th>", .escapeHTML(names(x)), "</th>", collapse = "")
    body <- if (nrow(x) == 0L) {
        ""
    } else {
        rows <- vapply(seq_len(nrow(x)), function(i) {
            paste0(
                "<tr>",
                paste0("<td>", vapply(cells, `[[`, character(1), i), "</td>", collapse = ""),
                "</tr>"
            )
        }, character(1))
        paste(rows, collapse = "\n")
    }

    c(
        "<!doctype html>",
        "<html lang=\"en\">",
        "<head>",
        "<meta charset=\"utf-8\">",
        paste0("<title>", .escapeHTML(title), "</title>"),
        "<style>",
        "body { font-family: system-ui, Arial, sans-serif; margin: 0; background: #fafafa; }",
        "h1 { background: #111; color: #fff; margin: 0 0 1rem; padding: .75rem 1rem; font-size: 1.1rem; }",
        ".wrap { width: 96%; margin: 0 auto 2rem; overflow-x: auto; }",
        "table { border-collapse: collapse; font-size: .8rem; background: #fff; }",
        "th, td { border: 1px solid #ddd; padding: .35rem .5rem; text-align: left; white-space: nowrap; }",
        "th { background: #f0f0f0; position: sticky; top: 0; }",
        "tr:nth-child(even) td { background: #fbfbfb; }",
        "footer { color: #666; font-size: .75rem; padding: 0 1rem 1rem; }",
        "</style>",
        "</head>",
        "<body>",
        paste0("<h1>", .escapeHTML(title), "</h1>"),
        "<div class=\"wrap\">",
        "<table>",
        paste0("<thead><tr>", header, "</tr></thead>"),
        "<tbody>",
        body,
        "</tbody>",
        "</table>",
        "</div>",
        paste0(
            "<footer>Generated by STRprofilerR ", .pkgVersion(),
            " on ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "</footer>"
        ),
        "</body>",
        "</html>"
    )
}
