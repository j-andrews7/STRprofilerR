# The "Batch Query" tab: a file of profiles compared against the loaded
# database, against each other, or against Cellosaurus via CLASTR.

.BATCH_SEARCH_CHOICES <- c(
    "STRprofiler Database" = "database",
    "Cellosaurus Database (CLASTR)" = "clastr",
    "Within File Query" = "file"
)

.batchQueryUI <- function(id) {
    ns <- shiny::NS(id)

    thresholds <- shiny::conditionalPanel(
        "input.search_type !== 'clastr'",
        ns = ns,
        shiny::fluidRow(
            shiny::column(
                6,
                bslib::tooltip(
                    shiny::numericInput(ns("mix_threshold"), "'Mixed' Sample Threshold", value = 3, width = "100%"),
                    "Multi-allelic marker count required to indicate potential sample mixing"
                ),
                bslib::tooltip(
                    shiny::numericInput(
                        ns("mas_q_threshold"), "Masters (vs. query) Filter Threshold",
                        value = 80, width = "100%"
                    ),
                    "Masters (vs. query) score that must be met for result to be displayed"
                )
            ),
            shiny::column(
                6,
                bslib::tooltip(
                    shiny::numericInput(ns("tan_threshold"), "Tanabe Filter Threshold", value = 80, width = "100%"),
                    "Tanabe score that must be met for result to be displayed"
                ),
                bslib::tooltip(
                    shiny::numericInput(
                        ns("mas_r_threshold"), "Masters (vs. ref.) Filter Threshold",
                        value = 80, width = "100%"
                    ),
                    "Masters (vs. reference) score that must be met for result to be displayed"
                )
            )
        )
    )

    clastrOptions <- shiny::conditionalPanel(
        "input.search_type === 'clastr'",
        ns = ns,
        shiny::fluidRow(
            shiny::column(6, bslib::tooltip(
                shiny::selectInput(ns("score_filter"), "Similarity Score Filter", .SCORE_CHOICES, width = "100%"),
                "Similarity score method used for computation"
            )),
            shiny::column(6, bslib::tooltip(
                shiny::numericInput(
                    ns("score_threshold"), "Similarity Score Filter Threshold",
                    value = 80, width = "100%"
                ),
                "Score threshold that must be met for result to be displayed"
            ))
        )
    )

    options <- bslib::sidebar(
        position = "left",
        width = 400,
        open = "always",
        shiny::h3("Options"),
        shiny::selectInput(ns("search_type"), "Search Type", .BATCH_SEARCH_CHOICES, width = "100%"),
        bslib::card(
            bslib::tooltip(
                bslib::input_switch(ns("score_amel"), "Score Amelogenin", value = FALSE),
                "Include Amelogenin in similarity scoring"
            ),
            thresholds,
            clastrOptions
        ),
        shiny::fileInput(ns("file"), "Input File:", accept = .uploadAccept(), multiple = FALSE, width = "100%"),
        bslib::input_task_button(ns("run"), "Batch Query", class = "btn-primary", width = "100%"),
        shiny::downloadButton(
            ns("example"), "Download Example Batch File",
            class = "btn-secondary", style = "width: 100%;"
        )
    )

    bslib::card(
        bslib::layout_sidebar(
            sidebar = options,
            shiny::h3("Results"),
            shiny::uiOutput(ns("sample_ui")),
            shiny::uiOutput(ns("results_ui")),
            shiny::uiOutput(ns("download_ui"))
        )
    )
}

# Returns list(results = reactive) so tests can inspect the report.
.batchQueryServer <- function(id, db, sampleCol = "Sample", markerCol = "Marker") {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns
        results <- shiny::reactiveVal(NULL)

        # Stale results are cleared rather than silently recomputed; a CLASTR
        # search in particular should only run when asked for.
        shiny::observeEvent(input$search_type, results(NULL), ignoreInit = TRUE)
        shiny::observeEvent(input$file, results(NULL), ignoreInit = TRUE)
        shiny::observeEvent(db$version(), results(NULL), ignoreInit = TRUE)

        .enforceInteger(input, session, "score_threshold")

        shiny::observeEvent(input$run, {
            if (is.null(input$file)) {
                shiny::showNotification("Choose an input file to query.", type = "warning")
                return()
            }

            fileError <- "There was a fatal error in the input file."
            retry <- "Adjust input file and retry upload/query."

            query <- .appTry(
                .readUpload(input$file, sampleCol = sampleCol, markerCol = markerCol),
                title = "Batch Query Error",
                before = paste0(fileError, "\n\nEnsure column header: '", sampleCol, "' was used."),
                after = retry
            )
            if (is.null(query)) {
                results(NULL)
                return()
            }

            res <- if (input$search_type == "clastr") {
                .batchClastrSearch(query, input)
            } else {
                cmp <- .appTry(
                    .batchCompare(
                        query,
                        reference = if (input$search_type == "database") db$profiles() else NULL,
                        useAmel = isTRUE(input$score_amel),
                        mixThreshold = .checkNumber(input$mix_threshold, "'Mixed' Sample Threshold"),
                        tanThreshold = .checkNumber(input$tan_threshold, "Tanabe Filter Threshold"),
                        masQThreshold = .checkNumber(input$mas_q_threshold, "Masters (vs. query) Filter Threshold"),
                        masRThreshold = .checkNumber(input$mas_r_threshold, "Masters (vs. ref.) Filter Threshold")
                    ),
                    title = "Batch Query Error",
                    before = fileError,
                    after = retry
                )
                if (is.null(cmp)) NULL else list(kind = "summary", table = .batchSummaryTable(cmp))
            }
            results(res)
        })

        output$sample_ui <- shiny::renderUI({
            res <- shiny::req(results())
            shiny::req(res$kind == "clastr")
            shiny::selectInput(ns("sample"), "Choose Sample:", rownames(res$query))
        })

        # Only present while there are results: a cleared widget is hidden
        # rather than removed, and would leave an empty block behind.
        output$results_ui <- shiny::renderUI({
            shiny::req(results())
            DT::DTOutput(ns("results"))
        })

        output$results <- DT::renderDT({
            res <- shiny::req(results())
            if (res$kind == "clastr") {
                s <- input$sample
                shiny::req(s %in% rownames(res$query))
                tab <- .clastrQueryTable(res$query[s, ], res$hits[res$hits$query == s, , drop = FALSE])
                .resultsDT(tab$table, tab$markers, html = tab$html, scoreCols = tab$scoreCol)
            } else {
                .resultsDT(res$table)
            }
        })

        output$download_ui <- shiny::renderUI({
            res <- shiny::req(results())
            csv <- shiny::downloadButton(ns("download"), "Download CSV", class = "btn-primary", style = "width: 25%;")
            if (res$kind == "clastr") {
                shiny::tagList(
                    csv,
                    shiny::downloadButton(ns("download_xlsx"), "Download XLSX", class = "btn-primary", style = "width: 25%;")
                )
            } else {
                csv
            }
        })

        output$download <- shiny::downloadHandler(
            filename = function() .downloadName("STR_Batch_Results_", "_", "csv"),
            content = function(file) {
                res <- results()
                out <- if (res$kind == "clastr") as.data.frame(res$hits, optional = TRUE) else res$table
                utils::write.csv(out, file, row.names = FALSE, na = "")
            }
        )

        # CLASTR's own workbook, one sheet per profile, fetched on request.
        output$download_xlsx <- shiny::downloadHandler(
            filename = function() .downloadName("STR_Batch_Results_", "_", "xlsx"),
            content = function(file) {
                res <- results()
                tryCatch(
                    do.call(clastrBatchQuery, c(list(res$query, file), res$params)),
                    error = function(e) {
                        shiny::showNotification(
                            paste("The CLASTR workbook could not be downloaded:", conditionMessage(e)),
                            type = "error", duration = NULL
                        )
                        stop(e)
                    }
                )
            }
        )

        output$example <- shiny::downloadHandler(
            filename = "Example_Batch_File.csv",
            content = function(file) {
                file.copy(.extdata("Example_Batch_File.csv"), file, overwrite = TRUE)
            }
        )

        list(results = results)
    })
}

# Search Cellosaurus with every profile in the file, reporting progress. The
# result keeps the parameters so CLASTR's workbook can be requested to match.
.batchClastrSearch <- function(query, input) {
    bad <- .clastrIncompatible(query)
    if (length(bad) > 0L) {
        .showClastrMarkerModal(bad)
    }

    params <- list(
        algorithm = input$score_filter,
        scoreFilter = input$score_threshold,
        includeAmelogenin = isTRUE(input$score_amel)
    )

    hits <- .appTry(
        {
            .checkNumber(params$scoreFilter, "Similarity Score Filter Threshold")
            shiny::withProgress(message = "Querying CLASTR", value = 0, {
                n <- nrow(query)
                do.call(.batchClastr, c(
                    list(query, progress = function(i, name) shiny::incProgress(1 / n, detail = name)),
                    params
                ))
            })
        },
        title = "CLASTR Query Error",
        before = "The Cellosaurus CLASTR API could not be queried.\n\nReported error:"
    )
    if (is.null(hits)) {
        return(NULL)
    }

    list(kind = "clastr", query = query, hits = hits, params = params)
}
