#' Clean and split a vector of allele calls
#'
#' Splits comma-separated allele strings into their component alleles,
#' de-duplicating and ordering them consistently.
#'
#' @details
#' Each element is split on commas and each token trimmed. A token survives only
#' if it is an allele:
#'
#' * a finite repeat count, de-duplicated numerically, sorted ascending, and
#'   rendered without a trailing `.0`, so `"10.0"` and `"10"` collapse to a
#'   single `"10"` while `"9.3"` is preserved; or
#' * one of the calls named in `keepCalls`, matched case-insensitively and stored
#'   in the spelling given there, so `"x"` and `"X"` are one allele rather than
#'   two that never match. These sort after the numeric alleles.
#'
#' Everything else is discarded: the empty token left by a trailing comma
#' (`"12,"`), the codes a capillary-electrophoresis export uses for a peak it
#' could not call (`OL` for one outside the ladder, `?` for one it declined to
#' type, `NR`, `ND` and the like), and free text. None of them is an allele, and
#' keeping them makes two profiles that merely failed at the same marker score as
#' sharing a value; discarding them leaves the marker untyped, which lowers the
#' shared-marker count instead. `"nan"` and `"inf"` go the same way, though
#' `as.numeric()` accepts both.
#'
#' `keepCalls` defaults to the amelogenin sex markers, the only allele calls that
#' are not repeat counts. [readSTRProfiles()] and [STRProfiles()] are stricter
#' still and honour `keepCalls` at amelogenin markers only, since a letter at any
#' other marker is a failed call rather than a sex call. `strprofiler` (from 0.5.0) keeps
#' `X`/`Y` at every marker; through 0.4.2 it scored every one of these codes as an
#' ordinary allele.
#'
#' @param x Character vector of comma-separated allele calls. `NA` is treated as
#'   an empty call.
#' @param keepCalls Character vector of non-numeric calls that count as alleles,
#'   compared case-insensitively against each whole token and stored in the
#'   spelling given here. Exports are not consistent about capitalisation. Pass
#'   `character(0)` to accept repeat counts only.
#'
#' @return A [IRanges::CharacterList] the same length as `x`, each element the
#'   cleaned allele vector for the corresponding input.
#'
#' @author Jared Andrews
#'
#' @examples
#' cleanAlleles("10.0,10,13,13.0,14,14 ")
#'
#' # The sex markers are kept, in one spelling, and sort after numeric alleles.
#' cleanAlleles(c("Y,X", "17.3, 12", "", NA))
#' cleanAlleles("x,X,y")
#'
#' # Uncallable peaks and free text are discarded, leaving a marker untyped.
#' cleanAlleles("OL,11")
#' cleanAlleles(c("OL", "12,NR,ND"))
#'
#' # Repeat counts only.
#' cleanAlleles("12,X", keepCalls = character(0))
#'
#' @export
cleanAlleles <- function(x, keepCalls = c("X", "Y")) {
    .cleanAllelesCounted(x, keepCalls)$alleles
}

# The working half of cleanAlleles(), which also reports how many uncallable
# calls were discarded from each element. The count is what lets .buildProfiles()
# record an 'nDroppedCalls' column without a second pass over the alleles, and it
# is free here because the tokens are already flattened.
.cleanAllelesCounted <- function(x, keepCalls = c("X", "Y")) {
    x <- as.character(x)
    x[is.na(x)] <- ""

    toks <- strsplit(x, ",", fixed = TRUE)
    n <- length(toks)
    if (n == 0L) {
        return(list(alleles = IRanges::CharacterList(list()), nDropped = integer(0)))
    }

    # Work on every token from every element at once, tagged by which element it
    # came from. Cleaning one element at a time means a format() call per allele,
    # which dominates the cost of reading a whole database.
    group <- rep.int(seq_len(n), lengths(toks))
    flat <- trimws(unlist(toks, use.names = FALSE))

    # An allele is a finite repeat count, or one of the calls 'keepCalls' permits.
    # Only tokens written as a decimal number are converted: as.numeric() would
    # warn for every letter (X, OL, ...), and would also accept the "nan", "inf",
    # and hexadecimal spellings that are junk here.
    decimal <- grepl("^[+-]?([0-9]+[.]?[0-9]*|[.][0-9]+)([eE][+-]?[0-9]+)?$", flat)
    num <- rep(NA_real_, length(flat))
    num[decimal] <- as.numeric(flat[decimal])
    isNum <- is.finite(num)
    permitted <- match(toupper(flat), toupper(keepCalls))
    isCall <- !isNum & !is.na(permitted)

    # Whatever is left is a peak the instrument could not call, or free text.
    # Counted per element before it is discarded, so the caller can report what
    # was removed rather than leaving it to be inferred from a marker count. An
    # empty token is not a call, so it is dropped without being counted.
    nDropped <- tabulate(group[nzchar(flat) & !isNum & !isCall], nbins = n)

    # Canonical spelling: numbers normalised so "10.0" and "10" collapse, kept
    # calls taken from 'keepCalls' so "x" and "X" are one allele. Scoring compares
    # these strings literally, so a spelling left un-normalised here is not a near
    # miss, it is a silent non-match.
    canonical <- character(length(flat))
    canonical[isNum] <- .formatAllele(num[isNum])
    canonical[isCall] <- keepCalls[permitted[isCall]]

    keep <- isNum | isCall
    group <- group[keep]
    canonical <- canonical[keep]
    num <- num[keep]
    isNum <- isNum[keep]

    # Within an element: numeric alleles ascending, then string alleles sorted.
    ord <- order(
        group, !isNum,
        ifelse(isNum, num, Inf), canonical,
        method = "radix"
    )
    group <- group[ord]
    canonical <- canonical[ord]

    # Sorted, so duplicates within an element are adjacent.
    if (length(group) > 1L) {
        prev <- seq_len(length(group) - 1L)
        dup <- c(FALSE, group[-1L] == group[prev] & canonical[-1L] == canonical[prev])
        group <- group[!dup]
        canonical <- canonical[!dup]
    }

    list(
        alleles = IRanges::CharacterList(
            unname(split(canonical, factor(group, levels = seq_len(n))))
        ),
        nDropped = nDropped
    )
}

# Render numeric alleles the way Python's str() does: no trailing ".0", no
# scientific notation. Vectorised, unlike format(), which would pick one common
# width for the whole vector.
.formatAllele <- function(v) {
    if (length(v) == 0L) {
        return(character(0))
    }
    out <- sub("0+$", "", sprintf("%.10f", v))
    sub("[.]$", "", out)
}

#' Read STR profiles from file
#'
#' Reads one or more STR profile files, in either wide or long layout, into a
#' single [STRProfiles] object.
#'
#' @details
#' ## Layouts
#'
#' **Long** files carry one row per sample, with every column other than the
#' sample column (and any `metadataCols`) treated as a marker:
#'
#' ```
#' Sample,  D1S1656, DYS391, AMEL
#' Line1,   "12,14", 12,     X
#' ```
#'
#' **Wide** files carry one row per sample/marker pair, with the alleles spread
#' across several columns. Any column whose name contains `Allele` is collected;
#' size and height columns are ignored:
#'
#' ```
#' Sample, Marker,  Allele 1, Size 1, Allele 2
#' Line1,  D3S1358, 16,       128.29, 18
#' ```
#'
#' With `format = "auto"` a file is read as wide when it has a `markerCol`
#' column *and* at least one column containing `Allele`, and long otherwise.
#'
#' ## Combining files
#'
#' Files may mix layouts and formats. Markers are unioned across files, with
#' samples missing a marker recorded as untyped rather than as an empty allele.
#' Sample names must be unique across all files.
#'
#' ## Divergences from the Python package
#'
#' `metadataCols` are held in [sampleData()] rather than alongside the markers.
#' `strprofiler` (from 0.5.0) carries them in the profile and skips them at scoring and
#' mixing time, so a custom metadata column has to be declared to each of those
#' functions rather than once at ingest. (Through 0.4.2 it had no such argument,
#' and two samples sharing a `Center` of `"JAX"` scored as sharing a marker.)
#'
#' Row order follows the input files. `strprofiler` returns wide-format samples
#' in sorted order because it groups with `pandas`.
#'
#' All columns are read as text, so alleles are never coerced to numbers and
#' back. This removes a class of bug that `strprofiler` patched twice through
#' 0.4.2 (alleles ending in zero being truncated, for example `10` becoming `1`);
#' since 0.5.0 it instead parses every call and renders it back.
#'
#' @param files Character vector of paths. Supported extensions are `csv`,
#'   `tsv`, `txt` (tab-separated), and `xlsx` (first sheet; needs `readxl`).
#' @param sampleCol Name of the sample identifier column.
#' @param markerCol Name of the marker identifier column. Used only for wide
#'   files.
#' @param sampleMap Optional sample renaming table: either a path to a
#'   headerless two-column CSV, or a `data.frame`/`matrix` with at least two
#'   columns. The first column holds names as they appear in the input, the
#'   second the names to use instead.
#' @param pentaFix Logical scalar. Harmonise the common Penta marker spellings
#'   via [markerAliases()].
#' @param metadataCols Character vector of non-marker column names to route into
#'   [sampleData()]. Columns not present in the input are ignored.
#' @param format One of `"auto"`, `"wide"`, or `"long"`. Applied to every file.
#' @param extraAliases Named character vector of additional marker aliases,
#'   passed to [harmonizeMarkers()].
#' @param keepCalls Character vector of non-numeric calls that count as alleles,
#'   passed to [cleanAlleles()] and honoured at amelogenin markers only. Defaults
#'   to the sex markers `X` and `Y`. Every other non-numeric call is an uncallable
#'   peak or free text, and the per-sample count discarded is recorded in
#'   [sampleData()] as `nDroppedCalls`.
#'
#' @return A [STRProfiles] object.
#'
#' @author Jared Andrews
#'
#' @seealso [STRProfiles()] to build one from an in-memory `data.frame`,
#'   [scoreProfiles()] to compare the result.
#'
#' @examples
#' long <- system.file("extdata", "ExampleSTR_long.csv", package = "STRprofilerR")
#' p <- readSTRProfiles(long, sampleCol = "Sample Name")
#' p
#'
#' # Penta spellings are harmonised by default.
#' markers(p)
#' markers(readSTRProfiles(long, sampleCol = "Sample Name", pentaFix = FALSE))
#'
#' # A database file with Center and Passage metadata.
#' db <- system.file("extdata", "main_database.csv", package = "STRprofilerR")
#' ref <- readSTRProfiles(db)
#' sampleData(ref)[1:3, ]
#'
#' # Rename samples on the way in.
#' smap <- system.file("extdata", "SampleMap_exp.csv", package = "STRprofilerR")
#' xlsx <- system.file("extdata", "ExampleSTR.xlsx", package = "STRprofilerR")
#' if (requireNamespace("readxl", quietly = TRUE)) {
#'     rownames(readSTRProfiles(xlsx, sampleCol = "Sample Name", sampleMap = smap))
#' }
#'
#' @export
readSTRProfiles <- function(files,
                            sampleCol = "Sample",
                            markerCol = "Marker",
                            sampleMap = NULL,
                            pentaFix = TRUE,
                            metadataCols = c("Center", "Passage"),
                            format = c("auto", "wide", "long"),
                            extraAliases = NULL,
                            keepCalls = c("X", "Y")) {
    format <- match.arg(format)
    files <- as.character(files)
    if (length(files) == 0L) {
        stop("No input files supplied.", call. = FALSE)
    }

    profs <- lapply(files, function(path) {
        df <- .readTable(path)
        fmt <- if (format == "auto") .detectFormat(df, markerCol) else format

        parsed <- switch(fmt,
            wide = .parseWideTable(df, sampleCol, markerCol, metadataCols, path),
            long = .parseLongTable(df, sampleCol, metadataCols, path)
        )

        .buildProfiles(
            samples = parsed$samples,
            markerTable = parsed$markers,
            metaTable = parsed$meta,
            pentaFix = pentaFix,
            extraAliases = extraAliases,
            file = path,
            format = fmt,
            keepCalls = keepCalls
        )
    })

    out <- Reduce(.combineTwoProfiles, profs)

    if (!is.null(sampleMap)) {
        renamed <- .applySampleMap(rownames(out@alleles), sampleMap)
        if (anyDuplicated(renamed)) {
            dup <- unique(renamed[duplicated(renamed)])
            stop(
                "'sampleMap' produces duplicated sample names: ",
                paste(dup, collapse = ", "), ".",
                call. = FALSE
            )
        }
        rownames(out@alleles) <- renamed
        rownames(out@sampleData) <- renamed
    }

    out@provenance <- list(
        files = files,
        options = list(
            sampleCol = sampleCol,
            markerCol = markerCol,
            pentaFix = pentaFix,
            metadataCols = metadataCols,
            format = format,
            keepCalls = keepCalls,
            sampleMap = if (is.character(sampleMap)) sampleMap else !is.null(sampleMap)
        ),
        timestamp = Sys.time(),
        version = .pkgVersion()
    )

    validObject(out)
    out
}

#' Build STRProfiles from a data.frame
#'
#' Constructs a [STRProfiles] object from a wide `data.frame` already in memory:
#' one row per sample, one column per marker, alleles as comma-separated
#' strings. This is the inverse of `as.data.frame()` on a `STRProfiles` object.
#'
#' @param x A `data.frame` with a sample identifier column and one column per
#'   marker.
#' @inheritParams readSTRProfiles
#'
#' @return A [STRProfiles] object.
#'
#' @author Jared Andrews
#'
#' @seealso [readSTRProfiles()] to read from disk instead.
#'
#' @examples
#' df <- data.frame(
#'     Sample = c("Line1", "Line2"),
#'     AMEL = c("X,Y", "X"),
#'     vWA = c("16,18", "17"),
#'     "Penta D" = c("9,10", ""),
#'     check.names = FALSE
#' )
#' p <- STRProfiles(df)
#' p
#' alleles(p)[["PentaD"]]
#'
#' # Round-trips through as.data.frame().
#' identical(as.data.frame(STRProfiles(as.data.frame(p))), as.data.frame(p))
#'
#' @export
STRProfiles <- function(x,
                        sampleCol = "Sample",
                        pentaFix = TRUE,
                        metadataCols = c("Center", "Passage"),
                        extraAliases = NULL,
                        keepCalls = c("X", "Y")) {
    x <- as.data.frame(x, check.names = FALSE, stringsAsFactors = FALSE)
    names(x) <- trimws(names(x))
    x[] <- lapply(x, function(z) {
        z <- as.character(z)
        z[is.na(z)] <- ""
        trimws(z)
    })

    parsed <- .parseLongTable(x, sampleCol, metadataCols, "<data.frame>")

    out <- .buildProfiles(
        samples = parsed$samples,
        markerTable = parsed$markers,
        metaTable = parsed$meta,
        pentaFix = pentaFix,
        extraAliases = extraAliases,
        file = character(0),
        format = "long",
        keepCalls = keepCalls
    )

    validObject(out)
    out
}

#' Write STR profiles to file
#'
#' Writes a [STRProfiles] object to a CSV in the wide layout that
#' [readSTRProfiles()] reads back, with alleles collapsed to comma-separated
#' strings.
#'
#' @param x A [STRProfiles] object.
#' @param file Path to write to.
#' @param sampleCol Name to give the sample identifier column.
#'
#' @return Invisibly, the path written to.
#'
#' @author Jared Andrews
#'
#' @examples
#' db <- system.file("extdata", "ExampleSTR_database.csv", package = "STRprofilerR")
#' p <- readSTRProfiles(db, sampleCol = "Sample Name")
#'
#' out <- file.path(tempdir(), "profiles.csv")
#' writeSTRProfiles(p, out)
#' head(read.csv(out, check.names = FALSE))
#'
#' @export
writeSTRProfiles <- function(x, file, sampleCol = "Sample") {
    stopifnot(is(x, "STRProfiles"))
    df <- as.data.frame(x, sampleCol = sampleCol)
    utils::write.csv(df, file, row.names = FALSE, na = "")
    invisible(normalizePath(file, winslash = "/", mustWork = FALSE))
}


## ---------------------------------------------------------------------------
## Internals
## ---------------------------------------------------------------------------

.readTable <- function(path) {
    if (!file.exists(path)) {
        stop("File not found: ", path, call. = FALSE)
    }
    ext <- tolower(tools::file_ext(path))

    # A missing trailing newline is common in exported STR files and harmless
    # here, so muffle just that warning rather than passing it on.
    df <- withCallingHandlers(
        switch(ext,
            csv = utils::read.csv(path, check.names = FALSE, colClasses = "character"),
            tsv = ,
            txt = utils::read.delim(path, check.names = FALSE, colClasses = "character"),
            xls = ,
            xlsx = .readExcel(path),
            stop(
                "File extension '", ext, "' in file '", path, "' is not supported. ",
                "Use csv, tsv, txt, or xlsx.",
                call. = FALSE
            )
        ),
        warning = function(w) {
            if (grepl("incomplete final line", conditionMessage(w), fixed = TRUE)) {
                invokeRestart("muffleWarning")
            }
        }
    )

    df <- as.data.frame(df, check.names = FALSE, stringsAsFactors = FALSE)
    names(df) <- trimws(names(df))
    df[] <- lapply(df, function(z) {
        z <- as.character(z)
        z[is.na(z)] <- ""
        trimws(z)
    })
    df
}

.readExcel <- function(path) {
    if (!requireNamespace("readxl", quietly = TRUE)) {
        stop(
            "Reading '", basename(path), "' requires the 'readxl' package.\n",
            "Install it with install.packages(\"readxl\"), or export the file to CSV.",
            call. = FALSE
        )
    }

    as.data.frame(
        readxl::read_excel(path, col_types = "text", .name_repair = "minimal"),
        check.names = FALSE,
        stringsAsFactors = FALSE
    )

}

.detectFormat <- function(df, markerCol) {
    hasAllele <- any(grepl("Allele", names(df), fixed = TRUE))
    if (markerCol %in% names(df) && hasAllele) "wide" else "long"
}

.requireCols <- function(df, cols, path) {
    missing <- setdiff(cols, names(df))
    if (length(missing) > 0L) {
        stop(
            "Column(s) ", paste0("'", missing, "'", collapse = ", "),
            " not found in '", path, "'.\nAvailable columns: ",
            paste0("'", names(df), "'", collapse = ", "), ".",
            call. = FALSE
        )
    }
    invisible(TRUE)
}

.parseLongTable <- function(df, sampleCol, metadataCols, path) {
    .requireCols(df, sampleCol, path)

    samples <- df[[sampleCol]]
    meta <- intersect(metadataCols, names(df))
    markerCols <- setdiff(names(df), c(sampleCol, meta))

    list(
        samples = samples,
        markers = df[, markerCols, drop = FALSE],
        meta = df[, meta, drop = FALSE]
    )
}

.parseWideTable <- function(df, sampleCol, markerCol, metadataCols, path) {
    .requireCols(df, c(sampleCol, markerCol), path)

    alleleCols <- which(grepl("Allele", names(df), fixed = TRUE))
    if (length(alleleCols) == 0L) {
        stop("No columns containing 'Allele' found in '", path, "'.", call. = FALSE)
    }

    combined <- vapply(seq_len(nrow(df)), function(i) {
        vals <- unlist(df[i, alleleCols], use.names = FALSE)
        paste(vals[nzchar(vals)], collapse = ",")
    }, character(1))

    samples <- df[[sampleCol]]
    mk <- df[[markerCol]]
    uSamples <- unique(samples)
    uMarkers <- unique(mk)

    grid <- matrix(
        "",
        nrow = length(uSamples), ncol = length(uMarkers),
        dimnames = list(NULL, uMarkers)
    )
    grid[cbind(match(samples, uSamples), match(mk, uMarkers))] <- combined

    meta <- intersect(metadataCols, names(df))
    metaTable <- if (length(meta) == 0L) {
        as.data.frame(matrix(character(0), nrow = length(uSamples), ncol = 0L))
    } else {
        # One value per sample: the first non-empty entry across that sample's rows.
        as.data.frame(
            lapply(df[meta], function(col) {
                vapply(uSamples, function(s) {
                    vals <- col[samples == s]
                    vals <- vals[nzchar(vals)]
                    if (length(vals) == 0L) "" else vals[[1L]]
                }, character(1), USE.NAMES = FALSE)
            }),
            check.names = FALSE, stringsAsFactors = FALSE
        )
    }

    list(
        samples = uSamples,
        markers = as.data.frame(grid, check.names = FALSE, stringsAsFactors = FALSE),
        meta = metaTable
    )
}

.applySampleMap <- function(samples, sampleMap) {
    if (is.character(sampleMap) && length(sampleMap) == 1L) {
        if (!file.exists(sampleMap)) {
            stop("Sample map file not found: ", sampleMap, call. = FALSE)
        }
        sampleMap <- utils::read.csv(
            sampleMap,
            header = FALSE, colClasses = "character", check.names = FALSE
        )
    }

    sampleMap <- as.data.frame(sampleMap, stringsAsFactors = FALSE)
    if (ncol(sampleMap) < 2L) {
        stop(
            "'sampleMap' must have at least two columns: current name, then new name.",
            call. = FALSE
        )
    }

    from <- trimws(as.character(sampleMap[[1L]]))
    to <- trimws(as.character(sampleMap[[2L]]))

    hit <- match(samples, from)
    samples[!is.na(hit)] <- to[hit[!is.na(hit)]]
    samples
}

.buildProfiles <- function(samples, markerTable, metaTable, pentaFix, extraAliases,
                           file, format, keepCalls = c("X", "Y")) {
    samples <- trimws(as.character(samples))

    if (anyDuplicated(samples)) {
        dup <- unique(samples[duplicated(samples)])
        stop(
            "Duplicated sample names in '", file, "': ", paste(dup, collapse = ", "), ".\n",
            "Sample identifiers must be unique.",
            call. = FALSE
        )
    }

    mk <- names(markerTable)
    if (pentaFix) {
        mk <- harmonizeMarkers(mk, extra = extraAliases)
    } else if (!is.null(extraAliases)) {
        hit <- match(mk, names(extraAliases))
        mk[!is.na(hit)] <- unname(extraAliases[hit[!is.na(hit)]])
    }

    if (anyDuplicated(mk)) {
        # Harmonisation can map several spellings onto one marker. Usually these
        # are disjoint across samples (one sample spells it "Penta D", another
        # "PentaD"), so merging is lossless and silent. Warn only where a single
        # sample really was typed under more than one spelling.
        for (m in unique(mk[duplicated(mk)])) {
            idx <- which(mk == m)
            cols <- unname(as.list(markerTable[idx]))
            nFilled <- Reduce(`+`, lapply(cols, nzchar))

            if (any(nFilled > 1L)) {
                warning(
                    "In '", file, "', ", sum(nFilled > 1L), " sample(s) carry alleles under ",
                    "more than one spelling of marker '", m, "' (",
                    paste0("'", names(markerTable)[idx], "'", collapse = ", "),
                    "); the alleles were merged.",
                    call. = FALSE
                )
            }
            markerTable[[idx[[1L]]]] <- do.call(paste, c(cols, list(sep = ",")))
        }
        keep <- !duplicated(mk)
        markerTable <- markerTable[, keep, drop = FALSE]
        mk <- mk[keep]
    }

    al <- S4Vectors::DataFrame(row.names = samples)
    nDropped <- integer(length(samples))

    # Amelogenin is the one marker reported as a letter. Everywhere else a repeat
    # count is the only kind of allele there is, so 'keepCalls' does not apply and
    # an "X" is a failed call like any other.
    isAmel <- classifyMarkers(mk) == "amelogenin"

    for (i in seq_along(mk)) {
        cleaned <- .cleanAllelesCounted(
            markerTable[[i]],
            if (isAmel[[i]]) keepCalls else character(0)
        )
        al[[mk[[i]]]] <- cleaned$alleles
        nDropped <- nDropped + cleaned$nDropped
    }

    sd <- if (ncol(metaTable) == 0L) {
        S4Vectors::DataFrame(row.names = samples)
    } else {
        S4Vectors::DataFrame(metaTable, row.names = samples, check.names = FALSE)
    }

    # How many uncallable peaks were discarded, per sample. Recorded rather than
    # left implicit: a profile that lost calls has a lower shared-marker count
    # than its panel would suggest, and that is worth being able to see.
    sd$nDroppedCalls <- nDropped

    new("STRProfiles",
        alleles = al,
        markerData = .syncMarkerData(al, NULL),
        sampleData = sd,
        provenance = list(
            files = file,
            options = list(pentaFix = pentaFix, format = format, keepCalls = keepCalls),
            timestamp = Sys.time(),
            version = .pkgVersion()
        )
    )
}
