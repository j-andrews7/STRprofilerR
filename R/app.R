#' Launch the STRprofiler Shiny application
#'
#' Builds the interactive STRprofiler application, for comparing STR profiles
#' against a reference database or Cellosaurus from a web browser without
#' writing any code.
#'
#' @details
#' The application is a port of the one in the `strprofiler` Python package,
#' aligned with its 0.5.1 release. It has four tabs:
#'
#' \describe{
#'   \item{Single Query}{Type a profile in marker by marker and score it
#'     against the loaded database, or search Cellosaurus with it through
#'     CLASTR. The report lists every reference passing the chosen score
#'     threshold, best first, with alleles that differ from the query
#'     highlighted.}
#'   \item{Batch Query}{Upload a file of profiles and compare them against the
#'     database, against each other ("Within File Query"), or against
#'     Cellosaurus. Database and within-file searches give one summary row per
#'     profile, as [compareProfiles()] does.}
#'   \item{Database File Management}{Swap in a custom reference database for
#'     the session, or restore the one the application started with.}
#'   \item{Usage Guide}{How to use the application, and what to cite.}
#' }
#'
#' Uploaded files are read with [readSTRProfiles()], so they may be csv, tsv,
#' tab-separated txt, or xlsx, in the wide or long layout.
#'
#' CLASTR searches need network access. As with the rest of this package, the
#' application **is for research use only**.
#'
#' ## Deploying
#'
#' The return value is an ordinary Shiny application object. To host it with
#' your own database, on Posit Connect or a Shiny Server for example, deploy an
#' `app.R` containing:
#'
#' ```
#' STRprofilerR::STRprofilerApp(database = "my_database.csv")
#' ```
#'
#' From a shell, `strprofiler app --database my_database.csv` runs the same
#' application locally.
#'
#' ## Divergences from the Python package
#'
#' Checked against the application in `strprofiler` 0.5.1:
#'
#' * An upload that fails to load leaves the current database in place.
#'   `strprofiler` loads its stock database instead, while still displaying the
#'   failed file's name.
#' * Changing the batch search type clears the results. `strprofiler` re-runs
#'   the query, which for CLASTR means an unprompted API call.
#' * Batch CLASTR results are read from CLASTR's JSON API, shown per profile,
#'   and downloadable as csv, with CLASTR's own xlsx workbook still offered.
#'   `strprofiler` reads the workbook back, keying sheets by sample name, which
#'   fails for names longer than Excel's 31-character sheet name limit.
#' * Uploads may be csv, tsv, txt, or xlsx. `strprofiler`'s upload controls
#'   accept csv only.
#' * Single query results show whichever metadata columns the database has.
#'   `strprofiler` always shows `Center` and `Passage`, empty if the database
#'   lacks them.
#' * Amelogenin is recognised under any of the spellings in
#'   [amelogeninMarkers()]. `strprofiler`'s application only recognises a
#'   marker named `Amelogenin`.
#'
#' @param database The reference database. `NULL`, the default, uses the
#'   database bundled with the package, of models from The Jackson Laboratory
#'   PDX program and the NCI Patient-Derived Models Repository. Otherwise a path
#'   to a file [readSTRProfiles()] can read, or a [STRProfiles] object.
#' @param sampleCol Name of the sample identifier column, used when reading
#'   `database` from a file and for every file uploaded in the application.
#' @param markerCol Name of the marker column in wide-layout files, used as
#'   `sampleCol` is.
#'
#' @return A `shiny.appobj`. Print it, or pass it to [shiny::runApp()], to
#'   launch the application.
#'
#' @author Jared Andrews
#'
#' @references
#' Andrews JM, Lloyd MW, Neuhauser SB, Bundy M, Jocoy EL, Airhart SD, Bult CJ,
#' Evrard YA, Chuang JH, Baker S (2024). STRprofiler: efficient comparisons of
#' short tandem repeat profiles for biomedical model authentication.
#' *Bioinformatics*, btae713. \doi{10.1093/bioinformatics/btae713}
#'
#' @seealso [compareProfiles()] and [clastrQuery()], which the application
#'   calls.
#'
#' @examples
#' if (requireNamespace("shiny", quietly = TRUE) &&
#'     requireNamespace("bslib", quietly = TRUE) &&
#'     requireNamespace("DT", quietly = TRUE)) {
#'     app <- STRprofilerApp()
#'
#'     # With a custom database.
#'     custom <- system.file("extdata", "Example_Custom_Database.csv", package = "STRprofilerR")
#'     app <- STRprofilerApp(database = custom)
#'
#'     if (interactive()) {
#'         shiny::runApp(app)
#'     }
#' }
#'
#' @export
STRprofilerApp <- function(database = NULL, sampleCol = "Sample", markerCol = "Marker") {
    .requireAppPackages()

    if (is.null(database)) {
        profiles <- readSTRProfiles(.extdata("main_database.csv"))
        name <- "main_database.csv"
    } else if (is(database, "STRProfiles")) {
        profiles <- database
        src <- provenance(database)$files
        name <- if (length(src) > 0L) paste(basename(src), collapse = ", ") else "Custom database"
    } else if (is.character(database) && length(database) == 1L && !is.na(database)) {
        profiles <- readSTRProfiles(database, sampleCol = sampleCol, markerCol = markerCol)
        name <- basename(database)
    } else {
        stop("'database' must be NULL, a file path, or a STRProfiles object.", call. = FALSE)
    }

    if (nrow(profiles) == 0L || ncol(profiles) == 0L) {
        stop("The database has no profiles to compare against.", call. = FALSE)
    }

    shiny::addResourcePath(.APP_PREFIX, system.file("app", "www", package = "STRprofilerR"))

    shiny::shinyApp(
        ui = .appUI(),
        server = .appServer(profiles, name, sampleCol = sampleCol, markerCol = markerCol)
    )
}


## ---------------------------------------------------------------------------
## Internals
## ---------------------------------------------------------------------------

# URL prefix the application's images are served under.
.APP_PREFIX <- "strprofilerr"

.APP_LINKS <- list(
    docs = "https://j-andrews7.github.io/STRprofilerR/",
    paper = "https://doi.org/10.1093/bioinformatics/btae713",
    issues = "https://github.com/j-andrews7/STRprofilerR/issues",
    github = "https://github.com/j-andrews7/STRprofilerR"
)

.extdata <- function(f) {
    system.file("extdata", f, package = "STRprofilerR")
}

.appAsset <- function(f) {
    paste0(.APP_PREFIX, "/", f)
}

.requireAppPackages <- function() {
    pkgs <- c("shiny", "bslib", "DT")
    missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
    if (length(missing) > 0L) {
        stop(
            "The STRprofiler application needs the ",
            paste0("'", missing, "'", collapse = ", "), " package(s).\n",
            "Install with BiocManager::install(c(",
            paste0("\"", missing, "\"", collapse = ", "), ")).",
            call. = FALSE
        )
    }
    invisible(TRUE)
}

.appCSS <- function() {
    paste(
        "#version {padding: 8px;}",
        ".card-body {padding-top: 6px; padding-bottom: 6px;}",
        "table.dataTable, .table {font-size: 12px;}",
        ".strprofiler-hr {margin: 8px 0 !important;}",
        ".strprofiler-footer {font-size: 12px; opacity: 0.8; text-align: center; padding: 8px 12px 16px;}",
        "#strprofiler-help {max-width: 1000px; margin: 0 auto; padding: 12px;}",
        "#strprofiler-help img {display: block; margin: 12px auto;}",
        sep = "\n"
    )
}

.navLink <- function(label, href) {
    bslib::nav_item(shiny::tags$a(label, href = href, target = "_blank", rel = "noopener", class = "nav-link"))
}

.citationFooter <- function() {
    shiny::tags$footer(
        class = "strprofiler-footer",
        shiny::strong("For research use only."),
        " If you use STRprofiler, please cite: ",
        shiny::tags$a(
            href = .APP_LINKS$paper, target = "_blank", rel = "noopener",
            paste(
                "Andrews JM, et al. STRprofiler: efficient comparisons of short tandem repeat",
                "profiles for biomedical model authentication. Bioinformatics (2024)."
            )
        )
    )
}

.helpUI <- function() {
    md <- readLines(system.file("app", "help.md", package = "STRprofilerR"), encoding = "UTF-8", warn = FALSE)

    shiny::div(
        id = "strprofiler-help",
        shiny::markdown(md),
        # Open outside links in a new tab rather than navigating away from the
        # application, and give the guide's tables Bootstrap styling.
        shiny::tags$script(shiny::HTML(paste(
            "document.querySelectorAll('#strprofiler-help a[href^=\"http\"]').forEach(function(a) {",
            "  a.target = '_blank'; a.rel = 'noopener';",
            "});",
            "document.querySelectorAll('#strprofiler-help table').forEach(function(t) {",
            "  t.classList.add('table', 'table-sm', 'table-striped');",
            "});"
        )))
    )
}

.appUI <- function() {
    bslib::page_navbar(
        title = shiny::tags$a(
            href = .APP_LINKS$docs, target = "_blank", rel = "noopener",
            shiny::tags$img(src = .appAsset("logo.png"), height = "70px", alt = "STRprofiler")
        ),
        window_title = "STR Profiler",
        theme = bslib::bs_theme(version = 5, bootswatch = "superhero"),
        fillable = FALSE,
        header = shiny::tags$head(
            shiny::tags$link(rel = "icon", href = .appAsset("favicon.ico")),
            shiny::tags$style(shiny::HTML(.appCSS()))
        ),
        footer = .citationFooter(),
        bslib::nav_panel("Single Query", .singleQueryUI("single")),
        bslib::nav_panel("Batch Query", .batchQueryUI("batch")),
        bslib::nav_panel("Database File Management", .databaseUI("database")),
        bslib::nav_panel("Usage Guide", .helpUI()),
        bslib::nav_spacer(),
        .navLink("Docs", .APP_LINKS$docs),
        .navLink("Paper", .APP_LINKS$paper),
        .navLink("Bug Reports", .APP_LINKS$issues),
        bslib::nav_item(shiny::tags$a(
            shiny::icon("github", style = "font-size: 24px;"),
            href = .APP_LINKS$github, target = "_blank", rel = "noopener",
            class = "nav-link", title = "GitHub"
        )),
        bslib::nav_item(shiny::span(id = "version", paste0("v", .pkgVersion())))
    )
}

.appServer <- function(profiles, name, sampleCol = "Sample", markerCol = "Marker") {
    function(input, output, session) {
        db <- .databaseServer("database", profiles, name, sampleCol = sampleCol, markerCol = markerCol)
        .singleQueryServer("single", db)
        .batchQueryServer("batch", db, sampleCol = sampleCol, markerCol = markerCol)
    }
}

# Evaluate 'expr' for the application: an error becomes a modal titled 'title'
# (with 'before' and 'after' paragraphs around the message) and gives NULL, and
# each warning becomes a notification.
.appTry <- function(expr, title = "Error", before = NULL, after = NULL) {
    withCallingHandlers(
        tryCatch(expr, error = function(e) {
            .showErrorModal(title, c(before, conditionMessage(e), after))
            NULL
        }),
        warning = function(w) {
            shiny::showNotification(conditionMessage(w), type = "warning", duration = 10)
            invokeRestart("muffleWarning")
        }
    )
}

.showErrorModal <- function(title, paragraphs) {
    shiny::showModal(shiny::modalDialog(
        title = title,
        lapply(paragraphs, function(p) shiny::p(style = "white-space: pre-line;", p)),
        easyClose = TRUE,
        footer = NULL
    ))
}

.showClastrMarkerModal <- function(bad) {
    shiny::showModal(shiny::modalDialog(
        title = "Incompatible CLASTR Markers",
        shiny::p(
            "Marker(s): ", paste0("'", bad, "'", collapse = ", "),
            " are incompatible with the CLASTR query."
        ),
        shiny::p("The marker(s) will not be used in the query."),
        shiny::p(
            "See: ",
            shiny::tags$a("CLASTR", href = "https://www.cellosaurus.org/str-search/", target = "_blank"),
            " for a complete list of compatible marker names."
        ),
        easyClose = TRUE,
        footer = shiny::modalButton("Understood")
    ))
}

# strprofiler requires whole-number filter thresholds, which CLASTR takes as an
# integer, and truncates anything else with a notice.
.enforceInteger <- function(input, session, id) {
    shiny::observeEvent(input[[id]], {
        x <- input[[id]]
        if (is.numeric(x) && !is.na(x) && x != trunc(x)) {
            shiny::showNotification("Threshold must be an integer", type = "warning")
            shiny::updateNumericInput(session, id, value = trunc(x))
        }
    })
}

# Stop with a readable message when a numeric control has been cleared.
.checkNumber <- function(x, label) {
    if (!is.numeric(x) || length(x) != 1L || is.na(x)) {
        stop("'", label, "' must be a number.", call. = FALSE)
    }
    x
}
