# The "Single Query" tab: one profile typed in marker by marker, scored against
# the loaded database or searched against Cellosaurus via CLASTR.

.SINGLE_SEARCH_CHOICES <- c(
    "STRprofiler Database" = "database",
    "Cellosaurus Database (CLASTR)" = "clastr"
)

# The formula for each score, white on transparent for the dark theme.
.FORMULA_IMAGES <- list(
    tanabe = list(file = "tanabe_inverted.png", width = "320px", alt = "Tanabe = 2 x shared / (query + reference)"),
    mastersQuery = list(file = "masters_query_inverted.png", width = "200px", alt = "Masters (vs. query) = shared / query"),
    mastersRef = list(file = "masters_ref_inverted.png", width = "200px", alt = "Masters (vs. reference) = shared / reference")
)

.singleQueryUI <- function(id) {
    ns <- shiny::NS(id)

    options <- bslib::sidebar(
        position = "right",
        width = 400,
        open = "always",
        shiny::h3("Options"),
        bslib::card(
            bslib::tooltip(
                bslib::input_switch(ns("score_amel"), "Score Amelogenin", value = FALSE),
                "Include Amelogenin in similarity scoring"
            ),
            shiny::fluidRow(
                shiny::column(6, bslib::tooltip(
                    shiny::numericInput(ns("mix_threshold"), "'Mixed' Sample Threshold", value = 3, width = "100%"),
                    "Multi-allelic marker count required to indicate potential sample mixing"
                )),
                shiny::column(6, bslib::tooltip(
                    shiny::selectInput(ns("score_filter"), "Similarity Score Filter", .SCORE_CHOICES, width = "100%"),
                    "Similarity score method used for computation"
                ))
            ),
            shiny::div(style = "height: 50px;", shiny::uiOutput(ns("formula"))),
            bslib::tooltip(
                shiny::numericInput(
                    ns("score_threshold"), "Similarity Score Filter Threshold",
                    value = 80, width = "100%"
                ),
                "Score threshold that must be met for result to be displayed"
            )
        )
    )

    shiny::tagList(
        bslib::card(
            bslib::layout_sidebar(
                sidebar = options,
                shiny::h3("Sample Input"),
                bslib::card(shiny::uiOutput(ns("marker_inputs"))),
                shiny::fluidRow(
                    shiny::column(4, bslib::tooltip(
                        shiny::actionButton(ns("demo"), "Load Example Data", class = "btn-primary"),
                        "Example taken from loaded database"
                    )),
                    shiny::column(4, shiny::uiOutput(ns("example_text"))),
                    shiny::column(
                        4,
                        shiny::selectInput(ns("search_type"), "Search Type", .SINGLE_SEARCH_CHOICES, width = "90%"),
                        bslib::tooltip(
                            bslib::input_task_button(ns("search"), "Search", class = "btn-success", width = "45%"),
                            "Query STRprofiler Database",
                            id = ns("search_tooltip"),
                            placement = "left"
                        ),
                        shiny::actionButton(ns("reset"), "Reset", class = "btn-danger", width = "45%")
                    )
                )
            )
        ),
        shiny::tags$hr(class = "strprofiler-hr"),
        bslib::card(
            shiny::h3("Results"),
            shiny::uiOutput(ns("results_ui")),
            shiny::uiOutput(ns("download_ui"))
        )
    )
}

# Returns list(results = reactive) so tests can inspect the report.
.singleQueryServer <- function(id, db) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns
        results <- shiny::reactiveVal(NULL)
        example <- shiny::reactiveVal(NULL)

        # Marker names are not safe as input IDs, so inputs are numbered in
        # database marker order.
        markerIds <- function() paste0("marker_", seq_along(markers(db$profiles())))

        output$marker_inputs <- shiny::renderUI({
            mk <- markers(db$profiles())
            ids <- markerIds()
            boxes <- lapply(seq_along(mk), function(i) {
                shiny::column(2, shiny::textInput(ns(ids[[i]]), mk[[i]], value = "", placeholder = ""))
            })
            do.call(shiny::fluidRow, boxes)
        })

        output$formula <- shiny::renderUI({
            img <- .FORMULA_IMAGES[[input$score_filter]]
            shiny::req(img)
            shiny::img(
                src = .appAsset(img$file), alt = img$alt,
                style = paste0("height: 45px; width: ", img$width, ";")
            )
        })

        output$example_text <- shiny::renderUI({
            shiny::req(example())
            shiny::strong(paste0("Example: ", example()))
        })

        shiny::observeEvent(input$search_type, {
            bslib::update_tooltip(
                "search_tooltip",
                if (input$search_type == "clastr") {
                    "Query Cellosaurus Database via CLASTR API"
                } else {
                    "Query STRprofiler Database"
                }
            )
        }, ignoreInit = TRUE)

        .enforceInteger(input, session, "score_threshold")

        shiny::observeEvent(input$demo, {
            p <- db$profiles()
            first <- as.data.frame(p[1L, ])
            mk <- markers(p)
            ids <- markerIds()
            for (i in seq_along(mk)) {
                shiny::updateTextInput(session, ids[[i]], value = first[[mk[[i]]]][[1L]])
            }
            example(rownames(p)[[1L]])
        })

        resetQuery <- function() {
            for (id in markerIds()) {
                shiny::updateTextInput(session, id, value = "")
            }
            bslib::update_switch("score_amel", value = FALSE)
            shiny::updateNumericInput(session, "mix_threshold", value = 3)
            example(NULL)
            results(NULL)
        }
        shiny::observeEvent(input$reset, resetQuery())
        shiny::observeEvent(db$version(), resetQuery(), ignoreInit = TRUE)

        shiny::observeEvent(input$search, {
            mk <- markers(db$profiles())
            values <- vapply(markerIds(), function(id) {
                v <- input[[id]]
                if (is.null(v)) "" else v
            }, character(1))
            names(values) <- mk

            query <- .appTry(.queryProfile(values), title = "Query Error")
            if (is.null(query)) {
                results(NULL)
                example(NULL)
                shiny::showNotification("No input provided.", type = "warning")
                return()
            }

            res <- if (input$search_type == "clastr") {
                .singleClastrSearch(query, input)
            } else {
                .appTry(
                    .singleQueryTable(
                        query, db$profiles(),
                        useAmel = isTRUE(input$score_amel),
                        mixThreshold = .checkNumber(input$mix_threshold, "'Mixed' Sample Threshold"),
                        scoreType = input$score_filter,
                        threshold = .checkNumber(input$score_threshold, "Similarity Score Filter Threshold")
                    ),
                    title = "Query Error"
                )
            }
            results(res)
        })

        # Only present while there are results: a cleared widget is hidden
        # rather than removed, and would leave an empty block behind.
        output$results_ui <- shiny::renderUI({
            shiny::req(results())
            DT::DTOutput(ns("results"))
        })

        output$results <- DT::renderDT({
            res <- shiny::req(results())
            .resultsDT(res$table, res$markers, html = res$html, scoreCols = res$scoreCol)
        })

        output$download_ui <- shiny::renderUI({
            shiny::req(results())
            shiny::downloadButton(ns("download"), "Download CSV", class = "btn-primary", style = "width: 25%;")
        })

        output$download <- shiny::downloadHandler(
            filename = function() .downloadName("STR_Query_Results_", "-", "csv"),
            content = function(file) {
                utils::write.csv(results()$download, file, row.names = FALSE, na = "")
            }
        )

        list(results = results)
    })
}

# Search Cellosaurus with the typed profile. Unrecognised markers are reported
# up front, as strprofiler does, and are ignored by CLASTR.
.singleClastrSearch <- function(query, input) {
    bad <- .clastrIncompatible(query)
    if (length(bad) > 0L) {
        .showClastrMarkerModal(bad)
    }

    hits <- .appTry(
        .quietClastrQuery(
            query,
            algorithm = input$score_filter,
            scoreFilter = .checkNumber(input$score_threshold, "Similarity Score Filter Threshold"),
            includeAmelogenin = isTRUE(input$score_amel)
        ),
        title = "CLASTR Query Error",
        before = "The Cellosaurus CLASTR API could not be queried.\n\nReported error:"
    )
    if (is.null(hits)) {
        return(NULL)
    }
    if (nrow(hits) == 0L) {
        shiny::showNotification("No CLASTR results met the score threshold.", type = "message")
    }

    .clastrQueryTable(query, hits)
}
