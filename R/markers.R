#' Marker name harmonisation
#'
#' STR marker names are spelled inconsistently across instruments, vendors, and
#' databases. `markerAliases()` returns the alias table used to harmonise them,
#' and `harmonizeMarkers()` applies it to a vector of marker names.
#'
#' @details
#' The default table resolves the common Penta marker spellings (`Penta C`,
#' `Penta_C`, and so on) onto the compact forms (`PentaC`) used throughout this
#' package. This generalises the hard-coded `_pentafix()` helper in the
#' `strprofiler` Python package: pass `extra` to harmonise any other marker
#' names your instrument produces.
#'
#' The CLASTR API expects the *spaced* spellings, so `reverse = TRUE` inverts
#' the table for outbound queries.
#'
#' @param reverse Logical scalar. If `TRUE`, return the inverse table mapping
#'   compact spellings onto the spaced spellings expected by CLASTR.
#' @param extra Named character vector of additional aliases, where names are
#'   the aliases to replace and values are the canonical names to use.
#'
#' @return
#' `markerAliases()` returns a named character vector whose names are aliases
#' and whose values are canonical marker names.
#'
#' `harmonizeMarkers()` returns a character vector of the same length as
#' `markers`, with any recognised aliases replaced.
#'
#' @author Jared Andrews
#'
#' @examples
#' markerAliases()
#'
#' harmonizeMarkers(c("Penta D", "Penta_E", "vWA"))
#'
#' # The CLASTR API wants the spaced spellings back.
#' harmonizeMarkers(c("PentaD", "PentaE"), reverse = TRUE)
#'
#' # Harmonise a vendor-specific spelling too.
#' harmonizeMarkers("AMELOGENIN", extra = c(AMELOGENIN = "AMEL"))
#'
#' @export
markerAliases <- function(reverse = FALSE, extra = NULL) {
    forward <- c(
        "Penta C" = "PentaC",
        "Penta_C" = "PentaC",
        "Penta-C" = "PentaC",
        "Penta D" = "PentaD",
        "Penta_D" = "PentaD",
        "Penta-D" = "PentaD",
        "Penta E" = "PentaE",
        "Penta_E" = "PentaE",
        "Penta-E" = "PentaE"
    )

    tbl <- if (reverse) {
        c(
            "PentaC" = "Penta C",
            "Penta_C" = "Penta C",
            "Penta-C" = "Penta C",
            "PentaD" = "Penta D",
            "Penta_D" = "Penta D",
            "Penta-D" = "Penta D",
            "PentaE" = "Penta E",
            "Penta_E" = "Penta E",
            "Penta-E" = "Penta E"
        )
    } else {
        forward
    }

    if (!is.null(extra)) {
        if (is.null(names(extra)) || anyNA(names(extra)) || !all(nzchar(names(extra)))) {
            stop("'extra' must be a fully named character vector.", call. = FALSE)
        }
        tbl <- c(tbl[setdiff(names(tbl), names(extra))], extra)
    }

    tbl
}

#' @rdname markerAliases
#'
#' @param markers Character vector of marker names to harmonise.
#'
#' @export
harmonizeMarkers <- function(markers, reverse = FALSE, extra = NULL) {
    markers <- as.character(markers)
    tbl <- markerAliases(reverse = reverse, extra = extra)

    hit <- match(markers, names(tbl))
    markers[!is.na(hit)] <- unname(tbl[hit[!is.na(hit)]])
    markers
}

#' Recognised amelogenin marker names
#'
#' Amelogenin is a sex-determining marker rather than a polymorphic STR, so it
#' is excluded from similarity scoring by default. This function returns the
#' spellings recognised as amelogenin.
#'
#' @details
#' The `strprofiler` Python package identifies amelogenin by matching a single
#' user-supplied column name (`amel_col`, default `"AMEL"`), which silently
#' fails when a file uses a different spelling. This package instead classifies
#' every marker at ingest time and records the result in
#' [markerData()], so `AMEL`, `Amel`, and `Amelogenin` all work without
#' configuration.
#'
#' @return A character vector of recognised amelogenin marker names.
#'
#' @author Jared Andrews
#'
#' @examples
#' amelogeninMarkers()
#'
#' @seealso [classifyMarkers()], which uses this to tag markers at ingest.
#'
#' @export
amelogeninMarkers <- function() {
    c("AMEL", "Amel", "amel", "AMELOGENIN", "Amelogenin", "amelogenin", "AMELO")
}

#' Classify STR markers
#'
#' Tags each marker as amelogenin, Y-linked, or autosomal. The classification is
#' stored in the `class` column of [markerData()] and is what
#' [scoreProfiles()] uses to decide which markers to drop from scoring.
#'
#' @details
#' Y-linked markers are recognised by a `DYS` prefix (for example `DYS391`).
#' Everything that is neither amelogenin nor Y-linked is reported as
#' `"autosomal"`; the classification is a naming heuristic, not a lookup against
#' a curated marker panel, so unusual marker names may need correcting by hand
#' via `markerData(x)$class <- ...`.
#'
#' @param markers Character vector of marker names.
#'
#' @return A character vector the same length as `markers`, with values
#'   `"amelogenin"`, `"y-linked"`, or `"autosomal"`.
#'
#' @author Jared Andrews
#'
#' @examples
#' classifyMarkers(c("AMEL", "DYS391", "vWA", "PentaD"))
#'
#' @export
classifyMarkers <- function(markers) {
    markers <- as.character(markers)
    out <- rep("autosomal", length(markers))
    out[grepl("^DYS", markers, ignore.case = TRUE)] <- "y-linked"
    out[markers %in% amelogeninMarkers()] <- "amelogenin"
    out
}
