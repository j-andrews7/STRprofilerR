# The "Database File Management" tab: shows the loaded database and swaps a
# custom one in for the session.

.databaseUI <- function(id) {
    ns <- shiny::NS(id)

    bslib::layout_columns(
        col_widths = c(-3, 6, -3),
        shiny::div(
            bslib::value_box(
                title = "Current Database:",
                value = shiny::div(style = "font-size: 20px;", shiny::textOutput(ns("name"), inline = TRUE)),
                shiny::textOutput(ns("count")),
                showcase = shiny::icon("layer-group"),
                theme = "blue"
            ),
            shiny::hr(),
            shiny::uiOutput(ns("upload_ui")),
            bslib::layout_columns(
                shiny::downloadButton(ns("example"), "Download Example Database", class = "btn-secondary"),
                shiny::actionButton(ns("reset"), "Reset Custom Database", class = "btn-danger")
            )
        )
    )
}

# Returns reactives for the current database, its display name, and a counter
# that increments whenever the database is replaced.
.databaseServer <- function(id, initial, initialName, sampleCol = "Sample", markerCol = "Marker") {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns
        state <- shiny::reactiveValues(profiles = initial, name = initialName, version = 0L)
        resets <- shiny::reactiveVal(0L)

        # Re-rendered on reset so the control forgets the last upload.
        output$upload_ui <- shiny::renderUI({
            resets()
            shiny::fileInput(
                ns("upload"), "Upload Custom Database",
                accept = .uploadAccept(), multiple = FALSE, width = "100%"
            )
        })

        output$name <- shiny::renderText(state$name)
        output$count <- shiny::renderText(paste0("Number of Database Samples: ", nrow(state$profiles)))

        shiny::observeEvent(input$upload, {
            profiles <- .appTry(
                {
                    p <- .readUpload(input$upload, sampleCol = sampleCol, markerCol = markerCol)
                    if (ncol(p) == 0L) {
                        stop("No marker columns were found.", call. = FALSE)
                    }
                    p
                },
                title = "File Load Error",
                before = paste0(
                    "The file failed to load.\nCheck that sample IDs are unique and that the sample ",
                    "column is named '", sampleCol, "'.\n\nReported error:"
                ),
                after = "The current database has not been changed."
            )
            if (is.null(profiles)) {
                return()
            }

            state$profiles <- profiles
            state$name <- input$upload$name[[1L]]
            state$version <- state$version + 1L
        })

        shiny::observeEvent(input$reset, {
            state$profiles <- initial
            state$name <- initialName
            state$version <- state$version + 1L
            resets(resets() + 1L)
        })

        output$example <- shiny::downloadHandler(
            filename = "Example_Custom_Database.csv",
            content = function(file) {
                file.copy(.extdata("Example_Custom_Database.csv"), file, overwrite = TRUE)
            }
        )

        list(
            profiles = shiny::reactive(state$profiles),
            name = shiny::reactive(state$name),
            version = shiny::reactive(state$version)
        )
    })
}
