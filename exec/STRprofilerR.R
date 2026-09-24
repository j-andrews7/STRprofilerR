#!/usr/bin/env Rapp
#| name: strprofilerr
#| title: STRprofilerR
#| description: |
#|   Compare short tandem repeat (STR) profiles to authenticate biomedical
#|   models against the samples they were derived from.
#|
#|   For research use only.
#| examples:
#|   - strprofilerr compare -o ./results STR1.xlsx STR2.csv
#|   - strprofilerr compare --database refs.csv -o ./results batch.csv
#|   - strprofilerr clastr --score_filter 90 -o ./results batch.csv
#|   - strprofilerr app --database refs.csv

# Top-level assignments in each branch are the command line surface, so they use
# the snake_case spelling of the Python strprofiler flags rather than the
# camelCase used elsewhere in this package. Rapp takes the flag name verbatim
# from the variable name.

suppressPackageStartupMessages(library(STRprofilerR))

# --keep_calls arrives as one comma-separated string. An empty string means
# repeat counts only, which is character(0) rather than "".
.splitKeepCalls <- function(x) {
    if (is.na(x)) {
        return(character(0))
    }
    out <- trimws(strsplit(as.character(x), ",", fixed = TRUE)[[1L]])
    out[nzchar(out)]
}

switch(
    command <- "",

    #| title: Compare STR profiles
    #| description: |
    #|   Compare STR profiles to each other, or to a reference database with
    #|   --database. Writes a summary table, a table per query sample, an HTML
    #|   view of the summary, and a log of the parameters used.
    #| examples:
    #|   - strprofilerr compare --tan_threshold 90 -o ./results STR1.csv
    #|   - strprofilerr compare -d refs.csv -s "Sample Name" -o ./results batch.csv
    compare = {
        #| description: Minimum Tanabe score to report as a potential match.
        tan_threshold <- 80

        #| description: Minimum Masters (vs. query) score to report as a potential match.
        mas_q_threshold <- 80

        #| description: Minimum Masters (vs. reference) score to report as a potential match.
        mas_r_threshold <- 80

        #| description: |
        #|   Markers with more than two alleles tolerated before a sample is
        #|   flagged for potential mixing.
        mix_threshold <- 3L

        #| description: |
        #|   Path to an STR database in csv, tsv, txt, or xlsx format. Queries
        #|   are compared against it rather than against each other.
        #| short: d
        database <- NA_character_

        #| description: |
        #|   Path to a headerless two-column csv mapping current sample names to
        #|   new ones.
        sample_map <- NA_character_

        #| description: Name of the sample column in the input file(s).
        #| short: s
        sample_col <- "Sample"

        #| description: Name of the marker column. Only used for wide-format files.
        #| short: m
        marker_col <- "Marker"

        #| description: Non-marker column to treat as sample metadata (repeatable).
        metadata_col <- c()

        #| description: Harmonise the PentaC/D/E marker spellings.
        penta_fix <- TRUE

        #| description: |
        #|   Comma-separated non-numeric calls that count as alleles, honoured at
        #|   amelogenin markers only. Pass an empty string for repeat counts only.
        keep_calls <- "X,Y"

        #| description: Include amelogenin in similarity scoring.
        score_amel <- FALSE

        #| description: Drop pairs scoring below this on the Tanabe score.
        min_score <- NA_real_

        #| description: Output format to write (repeatable). One or more of csv, html, xlsx.
        format <- c()

        #| description: Directory to write results into.
        #| short: o
        output_dir <- "./STRprofilerR"

        #| description: STR profile file(s) to compare.
        input_files... <- NULL

        metaCols <- if (length(metadata_col)) metadata_col else c("Center", "Passage")
        outFormats <- if (length(format)) format else c("csv", "html")
        keepCalls <- .splitKeepCalls(keep_calls)

        query <- readSTRProfiles(
            input_files...,
            sampleCol = sample_col,
            markerCol = marker_col,
            sampleMap = if (is.na(sample_map)) NULL else sample_map,
            pentaFix = penta_fix,
            metadataCols = metaCols,
            keepCalls = keepCalls
        )

        # Assigned from an if/else rather than a bare NULL: Rapp reads a
        # top-level `x <- NULL` in a command branch as a positional argument.
        reference <- if (is.na(database)) {
            NULL
        } else {
            readSTRProfiles(
                database,
                sampleCol = sample_col,
                markerCol = marker_col,
                pentaFix = penta_fix,
                metadataCols = metaCols,
                keepCalls = keepCalls
            )
        }

        cmp <- compareProfiles(
            query = query,
            reference = reference,
            useAmel = score_amel,
            tanThreshold = tan_threshold,
            masQThreshold = mas_q_threshold,
            masRThreshold = mas_r_threshold,
            threeAlleleThreshold = mix_threshold,
            minScore = if (is.na(min_score)) NULL else min_score
        )

        written <- writeSTRResults(cmp, output_dir, formats = outFormats)

        cat(
            "Compared", nrow(query), "profile(s) against",
            nrow(referenceProfiles(cmp)), "reference(s).\n"
        )
        mixed <- summary(cmp)$mixed
        if (any(mixed, na.rm = TRUE)) {
            cat(
                "Flagged for potential mixing:",
                paste(summary(cmp)$Sample[mixed], collapse = ", "), "\n"
            )
        }
        cat("Wrote", length(written), "file(s) to", normalizePath(output_dir), "\n")
    },

    #| title: Query Cellosaurus via CLASTR
    #| description: |
    #|   Compare STR profiles against the human Cellosaurus knowledge base using
    #|   the CLASTR REST API. Needs network access.
    #| examples:
    #|   - strprofilerr clastr --score_filter 90 -o ./results batch.csv
    #|   - strprofilerr clastr --search_algorithm mastersQuery --xlsx batch.csv
    clastr = {
        #| description: |
        #|   Score to rank by: tanabe, mastersQuery, or mastersRef. The Python
        #|   package's 1, 2, and 3 are also accepted.
        #| short: a
        search_algorithm <- "tanabe"

        #| description: |
        #|   How CLASTR handles markers missing from one side: nonEmpty, query,
        #|   or reference. The Python package's 1, 2, and 3 are also accepted.
        scoring_mode <- "nonEmpty"

        #| description: Minimum score for a match to be returned.
        score_filter <- 80L

        #| description: Minimum number of shared markers for a match to be returned.
        min_markers <- 8L

        #| description: Maximum number of matches to return per query.
        max_results <- 200L

        #| description: Include amelogenin in CLASTR's scoring.
        score_amel <- FALSE

        #| description: |
        #|   Also request CLASTR's own multi-sheet xlsx workbook alongside the
        #|   parsed csv.
        xlsx <- FALSE

        #| description: |
        #|   Path to a headerless two-column csv mapping current sample names to
        #|   new ones.
        sample_map <- NA_character_

        #| description: Name of the sample column in the input file(s).
        #| short: s
        sample_col <- "Sample"

        #| description: Name of the marker column. Only used for wide-format files.
        #| short: m
        marker_col <- "Marker"

        #| description: Harmonise the PentaC/D/E marker spellings.
        penta_fix <- TRUE

        #| description: |
        #|   Comma-separated non-numeric calls sent to CLASTR as alleles, honoured
        #|   at amelogenin markers only. Pass an empty string to send none.
        keep_calls <- "X,Y"

        #| description: Directory to write results into.
        #| short: o
        output_dir <- "./STRprofilerR"

        #| description: STR profile file(s) to query.
        input_files... <- NULL

        algorithm <- switch(as.character(search_algorithm),
            "1" = "tanabe", "2" = "mastersQuery", "3" = "mastersRef",
            as.character(search_algorithm)
        )
        mode <- switch(as.character(scoring_mode),
            "1" = "nonEmpty", "2" = "query", "3" = "reference",
            as.character(scoring_mode)
        )

        query <- readSTRProfiles(
            input_files...,
            sampleCol = sample_col,
            markerCol = marker_col,
            sampleMap = if (is.na(sample_map)) NULL else sample_map,
            pentaFix = penta_fix,
            keepCalls = .splitKeepCalls(keep_calls)
        )

        dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
        stamp <- format(Sys.time(), "%Y%m%d.%H_%M_%S")

        hits <- clastrQuery(
            query,
            algorithm = algorithm,
            scoringMode = mode,
            scoreFilter = score_filter,
            minMarkers = min_markers,
            maxResults = max_results,
            includeAmelogenin = score_amel
        )

        out <- file.path(output_dir, paste0("STRprofilerR.clastr.", stamp, ".csv"))
        utils::write.csv(as.data.frame(hits), out, row.names = FALSE, na = "")
        cat("Returned", nrow(hits), "hit(s) for", nrow(query), "profile(s).\n")
        cat("Wrote", out, "\n")

        if (xlsx) {
            book <- file.path(output_dir, paste0("STRprofilerR.clastr.", stamp, ".xlsx"))
            clastrBatchQuery(
                query, book,
                algorithm = algorithm,
                scoringMode = mode,
                scoreFilter = score_filter,
                minMarkers = min_markers,
                maxResults = max_results,
                includeAmelogenin = score_amel
            )
            cat("Wrote", book, "\n")
        }
    },

    #| title: Launch the Shiny application
    #| description: |
    #|   Serve the interactive STRprofiler application, for single and batch
    #|   queries against a reference database or Cellosaurus. Needs the shiny,
    #|   bslib, and DT packages.
    #| examples:
    #|   - strprofilerr app
    #|   - strprofilerr app --database refs.csv --port 8080 --launch-browser
    app = {
        #| description: |
        #|   Path to a reference database in csv, tsv, txt, or xlsx format.
        #|   Defaults to the bundled database of JAX PDX and NCI PDMR models.
        #| short: d
        database <- NA_character_

        #| description: Name of the sample column in the database and uploaded files.
        #| short: s
        sample_col <- "Sample"

        #| description: Name of the marker column. Only used for wide-format files.
        #| short: m
        marker_col <- "Marker"

        #| description: Port to serve the application on.
        #| short: p
        port <- 8000L

        #| description: Address to listen on. Use 0.0.0.0 to serve to other machines.
        host <- "127.0.0.1"

        #| description: Open the application in the default web browser.
        launch_browser <- FALSE

        strApp <- STRprofilerApp(
            database = if (is.na(database)) NULL else database,
            sampleCol = sample_col,
            markerCol = marker_col
        )
        shiny::runApp(strApp, port = port, host = host, launch.browser = launch_browser)
    }
)
