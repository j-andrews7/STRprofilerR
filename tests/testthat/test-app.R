skipUnlessAppPackages <- function() {
    skip_if_not_installed("shiny")
    skip_if_not_installed("bslib")
    skip_if_not_installed("DT")
}

mainDb <- function() readSTRProfiles(ed("main_database.csv"))

# The database module's return value, for driving the query modules directly.
fixedDb <- function(p) {
    list(
        profiles = shiny::reactive(p),
        name = shiny::reactive("test"),
        version = shiny::reactive(0L)
    )
}

# A fileInput() value, as Shiny hands it to the server.
upload <- function(path, name = basename(path)) {
    data.frame(name = name, size = file.size(path), type = "", datapath = path, stringsAsFactors = FALSE)
}

firstProfileInputs <- function(p) {
    flat <- as.data.frame(p[1L, ])
    vals <- vapply(markers(p), function(m) flat[[m]][[1L]], character(1))
    stats::setNames(as.list(vals), paste0("marker_", seq_along(vals)))
}

recordedHits <- function() {
    STRprofilerR:::.bindClastrRows(
        STRprofilerR:::.parseClastrResults(
            jsonlite::fromJSON(ed("clastr_response.json"), simplifyVector = FALSE),
            "Query"
        )
    )
}

# The fixtures from strprofiler 0.5.1's tests/unit/test_app_calc.py: identical
# apart from Amelogenin, plus a sample with no valid alleles at all.
amelFixtures <- function() {
    list(
        query = STRProfiles(data.frame(Sample = "Query", Amelogenin = "X", m1 = "12", m2 = "14", m3 = "9")),
        reference = STRProfiles(data.frame(Sample = "Ref", Amelogenin = "X,Y", m1 = "12", m2 = "14", m3 = "9")),
        untyped = STRProfiles(data.frame(Sample = "Untyped", Amelogenin = "", m1 = "OL", m2 = "?", m3 = "NR"))
    )
}


## Table helpers -------------------------------------------------------------

test_that("typed alleles are cleaned, and a query of discarded calls is empty", {
    q <- STRprofilerR:::.queryProfile(c(vWA = "18, 16", TH01 = "7,9.3,OL", FGA = ""))
    expect_identical(flatSample(q, "Query"), c("16,18", "7,9.3", ""))

    expect_null(STRprofilerR:::.queryProfile(c(vWA = "OL", TH01 = "?", FGA = "")))
    expect_null(STRprofilerR:::.queryProfile(c(vWA = "", TH01 = "")))
})

test_that("the single query report puts the query first and filters on the chosen score", {
    db <- mainDb()
    typed <- stats::setNames(unlist(firstProfileInputs(db), use.names = FALSE), markers(db))
    q <- STRprofilerR:::.queryProfile(typed)

    res <- STRprofilerR:::.singleQueryTable(q, db, scoreType = "mastersQuery", threshold = 60)
    tab <- res$table

    expect_identical(tab$Sample[[1L]], "Query")
    expect_identical(tab$Sample[[2L]], rownames(db)[[1L]])
    expect_identical(tab[["Masters Query Score"]][[2L]], 100)
    expect_true(all(tab[["Masters Query Score"]][-1L] >= 60))
    expect_false(is.unsorted(rev(tab[["Masters Query Score"]][-1L])))

    # Only the chosen score is reported, followed by the database's metadata.
    expect_identical(
        colnames(tab)[1:7],
        c("Sample", "Mixed Sample", "Shared Markers", "Shared Alleles", "Masters Query Score", "Center", "Passage")
    )
    expect_false(any(c("Tanabe Score", "Masters Ref Score", "nDroppedCalls") %in% colnames(tab)))
    expect_identical(res$markers, markers(db))
})

test_that("single query scores agree with scoreProfiles()", {
    db <- mainDb()
    q <- STRprofilerR:::.queryProfile(c(Amelogenin = "X", CSF1PO = "10,12", D5S818 = "11,12", TH01 = "7,9.3", vWA = "18"))

    tab <- STRprofilerR:::.singleQueryTable(q, db, threshold = 0)$table
    sc <- as.data.frame(scoreProfiles(q, db))

    hit <- tab$Sample[[2L]]
    expect_equal(tab[["Tanabe Score"]][[2L]], round(sc$tanabeScore[sc$reference == hit], 2))
    expect_identical(tab[["Shared Alleles"]][[2L]], sc$nSharedAlleles[sc$reference == hit])
})

test_that("mismatch flags compare cleaned alleles, not typed text", {
    db <- STRProfiles(data.frame(Sample = c("A", "B"), vWA = c("12,14", "12,15"), TH01 = c("7", "7")))
    q <- STRprofilerR:::.queryProfile(c(vWA = "14, 12", TH01 = "7"))

    tab <- STRprofilerR:::.singleQueryTable(q, db, threshold = 0)$table
    flags <- STRprofilerR:::.mismatchFlags(tab, c("vWA", "TH01"))

    expect_identical(tab$vWA, c("12,14", "12,14", "12,15"))
    expect_identical(flags$vWA, c(0L, 0L, 1L))
    expect_identical(flags$TH01, c(0L, 0L, 0L))
})

test_that("the CLASTR report leads with the query and links accessions", {
    q <- STRprofilerR:::.queryProfile(c(Amelogenin = "X", PentaD = "11,13", TH01 = "6,9"))
    res <- STRprofilerR:::.clastrQueryTable(q, recordedHits())
    tab <- res$table

    expect_identical(nrow(tab), 13L)
    expect_identical(colnames(tab)[1:3], c("Accession", "Name", "Score"))
    expect_identical(tab$Accession[[1L]], "Query")
    expect_identical(tab$PentaD[[1L]], "11,13")
    expect_match(tab$Accession[[2L]], "href=\"https://www.cellosaurus.org/CVCL_0320\"", fixed = TRUE)

    # Problematic lines are styled and carry the Cellosaurus note.
    widr <- tab$Accession[tab$Name == "WiDr"][[1L]]
    expect_match(widr, "font-style:oblique", fixed = TRUE)
    expect_match(widr, "title=\"[^\"]*Contaminated")

    # The download keeps clastrQuery()'s own columns.
    expect_identical(colnames(res$download)[1:7], STRprofilerR:::.clastrColumns())
    expect_identical(res$download$accession[[1L]], "Query")
})

test_that("CLASTR text is escaped before it reaches the table", {
    q <- STRprofilerR:::.queryProfile(c(vWA = "16"))
    hits <- S4Vectors::DataFrame(
        query = "Query", accession = "<b>x</b>", name = "n", species = "s", score = 90,
        accessionLink = "https://example.org/\"x", problem = "<script>", vWA = "16"
    )
    link <- STRprofilerR:::.clastrQueryTable(q, hits)$table$Accession[[2L]]

    expect_false(grepl("<b>", link, fixed = TRUE))
    expect_false(grepl("<script>", link, fixed = TRUE))
    expect_match(link, "&lt;b&gt;x&lt;/b&gt;", fixed = TRUE)
})

test_that("a batch naming markers the database lacks is rejected", {
    db <- mainDb()
    q <- STRProfiles(data.frame(Sample = "S1", vWA = "16", NotAMarker = "12", DYS391 = "10"))

    expect_error(STRprofilerR:::.batchCompare(q, db), "'NotAMarker', 'DYS391' are incompatible")
})

test_that("Center and Passage in a batch file are metadata, not incompatible markers", {
    db <- mainDb()
    q <- STRProfiles(data.frame(Sample = "S1", Center = "JAX", Passage = "P2", vWA = "16", TH01 = "7"))

    expect_s4_class(STRprofilerR:::.batchCompare(q, db), "STRComparison")
})

test_that("the batch summary honours the Amelogenin switch (strprofiler 0.5.1)", {
    f <- amelFixtures()

    for (within in c(FALSE, TRUE)) {
        run <- function(useAmel) {
            cmp <- if (within) {
                STRprofilerR:::.batchCompare(c(f$query, f$reference), useAmel = useAmel)
            } else {
                STRprofilerR:::.batchCompare(f$query, f$reference, useAmel = useAmel)
            }
            STRprofilerR:::.batchSummaryTable(cmp)
        }

        expect_identical(run(FALSE)[["Top Match"]][[1L]], "Ref: 100.00")
        expect_identical(run(TRUE)[["Top Match"]][[1L]], "Ref: 88.89")
    }
})

test_that("an unscoreable reference is skipped rather than failing the batch (strprofiler 0.5.1)", {
    f <- amelFixtures()

    s <- suppressWarnings(STRprofilerR:::.batchSummaryTable(
        STRprofilerR:::.batchCompare(f$query, c(f$reference, f$untyped))
    ))
    expect_identical(s[["Top Match"]], "Ref: 100.00")
    expect_identical(s[["Next Best Match"]], "")

    within <- suppressWarnings(STRprofilerR:::.batchSummaryTable(
        STRprofilerR:::.batchCompare(c(f$query, f$reference, f$untyped))
    ))
    rownames(within) <- within$Sample
    expect_identical(within["Query", "Top Match"], "Ref: 100.00")
    expect_identical(within["Query", "Next Best Match"], "")
    expect_identical(within["Untyped", "Top Match"], "")
})

test_that("batch summary columns carry strprofiler's labels", {
    f <- amelFixtures()
    s <- STRprofilerR:::.batchSummaryTable(STRprofilerR:::.batchCompare(f$query, f$reference))

    expect_identical(colnames(s), unname(STRprofilerR:::.BATCH_LABELS))
})

test_that("results render as a DT widget with mismatches highlighted", {
    skip_if_not_installed("DT")
    db <- STRProfiles(data.frame(Sample = c("A", "B"), vWA = c("12,14", "12,15")))
    q <- STRprofilerR:::.queryProfile(c(vWA = "12,14"))
    res <- STRprofilerR:::.singleQueryTable(q, db, threshold = 0)

    w <- STRprofilerR:::.resultsDT(res$table, res$markers, scoreCols = res$scoreCol)

    expect_s3_class(w, "datatables")
    expect_match(as.character(w$x$options$rowCallback), "#ec7a80", fixed = TRUE)
    # Logical flags render as text rather than JavaScript booleans.
    expect_identical(w$x$data[["Mixed Sample"]], c("FALSE", "", ""))
})

test_that("download names are stamped as strprofiler stamps them", {
    t <- as.POSIXct("2026-09-23 14:05:00", tz = "UTC")

    expect_identical(
        STRprofilerR:::.downloadName("STR_Query_Results_", "-", "csv", t),
        "STR_Query_Results_2026-09-23-14h-05m.csv"
    )
    expect_identical(
        STRprofilerR:::.downloadName("STR_Batch_Results_", "_", "xlsx", t),
        "STR_Batch_Results_2026-09-23_14h-05m.xlsx"
    )
})


## Construction --------------------------------------------------------------

test_that("STRprofilerApp builds from the bundled database, a path, or an object", {
    skipUnlessAppPackages()

    expect_s3_class(STRprofilerApp(), "shiny.appobj")
    expect_s3_class(STRprofilerApp(ed("Example_Custom_Database.csv")), "shiny.appobj")
    expect_s3_class(
        STRprofilerApp(readSTRProfiles(ed("ExampleSTR_database.csv"), sampleCol = "Sample Name")),
        "shiny.appobj"
    )
})

test_that("STRprofilerApp fails fast on a bad database", {
    skipUnlessAppPackages()

    expect_error(STRprofilerApp(file.path(tempdir(), "missing.csv")), "File not found")
    expect_error(STRprofilerApp(42), "must be NULL, a file path")
})

test_that("the page carries the navigation, theme, and citation", {
    skipUnlessAppPackages()
    html <- as.character(STRprofilerR:::.appUI())

    for (tab in c("Single Query", "Batch Query", "Database File Management", "Usage Guide")) {
        expect_match(html, tab, fixed = TRUE)
    }
    expect_match(html, "10.1093/bioinformatics/btae713", fixed = TRUE)
    expect_match(html, "strprofilerr/logo.png", fixed = TRUE)
    expect_match(html, paste0("v", as.character(utils::packageVersion("STRprofilerR"))), fixed = TRUE)
})


## Modules -------------------------------------------------------------------

test_that("a database upload replaces the database, and reset restores it", {
    skipUnlessAppPackages()
    ref <- mainDb()

    shiny::testServer(STRprofilerR:::.databaseServer, args = list(initial = ref, initialName = "main_database.csv"), {
        session$setInputs(upload = upload(ed("Example_Custom_Database.csv")))
        expect_identical(nrow(session$returned$profiles()), 5L)
        expect_identical(session$returned$name(), "Example_Custom_Database.csv")
        expect_identical(session$returned$version(), 1L)
        expect_identical(output$count, "Number of Database Samples: 5")

        session$setInputs(reset = 1)
        expect_identical(nrow(session$returned$profiles()), nrow(ref))
        expect_identical(session$returned$name(), "main_database.csv")
        expect_identical(session$returned$version(), 2L)
    })
})

test_that("a failed database upload keeps the current database", {
    skipUnlessAppPackages()
    ref <- mainDb()
    bad <- withr::local_tempfile(fileext = ".csv")
    writeLines(c("Sample,vWA", "A,16", "A,17"), bad)

    shown <- NULL
    local_mocked_bindings(.showErrorModal = function(title, paragraphs) shown <<- title)

    shiny::testServer(STRprofilerR:::.databaseServer, args = list(initial = ref, initialName = "main_database.csv"), {
        session$setInputs(upload = upload(bad, "duplicated.csv"))

        expect_identical(shown, "File Load Error")
        expect_identical(nrow(session$returned$profiles()), nrow(ref))
        expect_identical(session$returned$name(), "main_database.csv")
        expect_identical(session$returned$version(), 0L)
    })
})

test_that("the single query module scores the example profile", {
    skipUnlessAppPackages()
    ref <- mainDb()

    shiny::testServer(STRprofilerR:::.singleQueryServer, args = list(db = fixedDb(ref)), {
        session$setInputs(
            search_type = "database", score_filter = "tanabe", score_threshold = 80,
            mix_threshold = 3, score_amel = FALSE
        )
        do.call(session$setInputs, firstProfileInputs(ref))
        session$setInputs(search = 1)

        tab <- session$returned$results()$table
        expect_identical(tab$Sample[1:2], c("Query", rownames(ref)[[1L]]))
        expect_identical(tab[["Tanabe Score"]][[2L]], 100)

        session$setInputs(reset = 1)
        expect_null(session$returned$results())
    })
})

test_that("an empty single query reports no input rather than scoring", {
    skipUnlessAppPackages()
    ref <- mainDb()

    shiny::testServer(STRprofilerR:::.singleQueryServer, args = list(db = fixedDb(ref)), {
        session$setInputs(
            search_type = "database", score_filter = "tanabe", score_threshold = 80,
            mix_threshold = 3, score_amel = FALSE, marker_1 = "OL"
        )
        session$setInputs(search = 1)
        expect_null(session$returned$results())
    })
})

test_that("a single CLASTR query goes through clastrQuery and leads with the query", {
    skipUnlessAppPackages()
    ref <- mainDb()
    sent <- NULL
    local_mocked_bindings(clastrQuery = function(x, ...) {
        sent <<- list(x = x, args = list(...))
        recordedHits()
    })

    shiny::testServer(STRprofilerR:::.singleQueryServer, args = list(db = fixedDb(ref)), {
        session$setInputs(
            search_type = "clastr", score_filter = "mastersRef", score_threshold = 70,
            mix_threshold = 3, score_amel = TRUE
        )
        do.call(session$setInputs, firstProfileInputs(ref))
        session$setInputs(search = 1)

        expect_identical(sent$args$algorithm, "mastersRef")
        expect_identical(sent$args$scoreFilter, 70)
        expect_true(sent$args$includeAmelogenin)
        expect_identical(rownames(sent$x), "Query")

        res <- session$returned$results()
        expect_identical(res$table$Accession[[1L]], "Query")
        expect_identical(nrow(res$table), 13L)
    })
})

test_that("the batch module compares a file against the database and within itself", {
    skipUnlessAppPackages()
    ref <- mainDb()

    shiny::testServer(STRprofilerR:::.batchQueryServer, args = list(db = fixedDb(ref)), {
        session$setInputs(
            search_type = "database", score_amel = FALSE, mix_threshold = 3,
            tan_threshold = 80, mas_q_threshold = 80, mas_r_threshold = 80
        )
        session$setInputs(file = upload(ed("Example_Batch_File.csv")))
        session$setInputs(run = 1)

        tab <- session$returned$results()$table
        expect_identical(tab$Sample, c("Sample_A", "Sample_B", "Sample_C"))
        expect_identical(tab[["Top Match"]][[1L]], "J000077451: 100.00")

        # Changing the search type clears rather than re-runs.
        session$setInputs(search_type = "file")
        expect_null(session$returned$results())

        session$setInputs(run = 2)
        tab <- session$returned$results()$table
        expect_identical(tab[["Top Match"]][[1L]], "Sample_C: 38.10")
    })
})

batchError <- function(path) {
    shown <- NULL
    local_mocked_bindings(
        .showErrorModal = function(title, paragraphs) shown <<- list(title = title, text = paragraphs)
    )

    shiny::testServer(STRprofilerR:::.batchQueryServer, args = list(db = fixedDb(mainDb())), {
        session$setInputs(
            search_type = "database", score_amel = FALSE, mix_threshold = 3,
            tan_threshold = 80, mas_q_threshold = 80, mas_r_threshold = 80
        )
        session$setInputs(file = upload(path))
        session$setInputs(run = 1)
        expect_null(session$returned$results())
    })
    shown
}

test_that("the batch module rejects a file with markers the database lacks", {
    skipUnlessAppPackages()
    f <- withr::local_tempfile(fileext = ".csv")
    writeLines(c("Sample,vWA,NotAMarker", "S1,16,12"), f)

    shown <- batchError(f)
    expect_identical(shown$title, "Batch Query Error")
    expect_true(any(grepl("'NotAMarker' are incompatible", shown$text, fixed = TRUE)))
})

test_that("the batch module names the sample column when a file cannot be read", {
    skipUnlessAppPackages()

    # This file's sample column is "Sample Name".
    shown <- batchError(ed("ExampleSTR_database.csv"))
    expect_true(any(grepl("Ensure column header: 'Sample'", shown$text, fixed = TRUE)))
})

test_that("a batch CLASTR search queries each profile and keeps the parameters", {
    skipUnlessAppPackages()
    ref <- mainDb()
    queried <- character(0)
    local_mocked_bindings(clastrQuery = function(x, ...) {
        queried <<- c(queried, rownames(x))
        hits <- recordedHits()
        hits$query <- rownames(x)
        hits
    })

    shiny::testServer(STRprofilerR:::.batchQueryServer, args = list(db = fixedDb(ref)), {
        session$setInputs(search_type = "clastr", score_amel = FALSE, score_filter = "tanabe", score_threshold = 80)
        session$setInputs(file = upload(ed("Example_Batch_File.csv")))
        session$setInputs(run = 1)

        res <- session$returned$results()
        expect_identical(queried, c("Sample_A", "Sample_B", "Sample_C"))
        expect_identical(res$kind, "clastr")
        expect_identical(unique(res$hits$query), queried)
        expect_identical(res$params$algorithm, "tanabe")
    })
})
