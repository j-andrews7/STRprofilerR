recordedResponse <- function() {
    jsonlite::fromJSON(ed("clastr_response.json"), simplifyVector = FALSE)
}

parsed <- function() {
    STRprofilerR:::.bindClastrRows(
        STRprofilerR:::.parseClastrResults(recordedResponse(), "Query")
    )
}

test_that("validateClastrMarkers reports only unrecognised markers", {
    expect_identical(
        validateClastrMarkers(c("Amelogenin", "vWA", "marker1", "NotAMarker")),
        c("marker1", "NotAMarker")
    )
    expect_length(validateClastrMarkers(clastrMarkers()), 0L)
})

test_that("validateClastrMarkers ignores the API's own parameter keys", {
    expect_length(
        validateClastrMarkers(c("vWA", "algorithm", "scoreFilter", "includeAmelogenin")),
        0L
    )
})

test_that("the recorded response parses into one row per returned profile", {
    df <- as.data.frame(parsed())

    # 10 results, two of which carry a second profile.
    expect_identical(nrow(df), 12L)
    expect_identical(unique(df$query), "Query")
})

test_that("two-profile results are labelled Best and Worst", {
    df <- as.data.frame(parsed())
    htFull <- df[grepl("^CVCL_0320", df$accession), ]

    expect_identical(htFull$accession, c("CVCL_0320 (Best)", "CVCL_0320 (Worst)"))
    expect_gt(htFull$score[[1L]], htFull$score[[2L]])
    expect_identical(htFull$name, c("HT-29", "HT-29"))
})

test_that("single-profile results keep a bare accession", {
    df <- as.data.frame(parsed())

    expect_true("CVCL_7204" %in% df$accession)
    expect_false(any(grepl("(Best)", df$accession[df$accession == "CVCL_7204"], fixed = TRUE)))
})

test_that("marker names come back in this package's spelling", {
    df <- as.data.frame(parsed())

    expect_true(all(c("PentaD", "PentaE") %in% colnames(df)))
    expect_false(any(c("Penta D", "Penta E") %in% colnames(df)))
    expect_identical(df$PentaD[[1L]], "11,13")
})

test_that("markers absent from a profile are blank, not NA", {
    df <- as.data.frame(parsed())
    markerCols <- setdiff(colnames(df), STRprofilerR:::.clastrColumns())

    expect_false(anyNA(df[, markerCols]))
    expect_true(any(df[, markerCols] == ""))
})

test_that("the problem field carries Cellosaurus contamination notes", {
    df <- as.data.frame(parsed())

    expect_match(df$problem[df$name == "WiDr"][[1L]], "Contaminated")
    expect_identical(df$problem[df$name == "HT-29"][[1L]], "")
})

test_that("accession links point at the bare accession", {
    df <- as.data.frame(parsed())

    expect_identical(
        df$accessionLink[[1L]],
        "https://www.cellosaurus.org/CVCL_0320"
    )
})

test_that("an empty result set yields a zero-row table with the fixed columns", {
    df <- STRprofilerR:::.bindClastrRows(list())

    expect_identical(nrow(df), 0L)
    expect_identical(colnames(df), STRprofilerR:::.clastrColumns())
})

test_that("a response with no results parses to nothing", {
    expect_length(STRprofilerR:::.parseClastrResults(list(results = list()), "Q"), 0L)
})

test_that("profiles are converted to CLASTR's marker spellings", {
    p <- STRProfiles(data.frame(
        Sample = "S1", PentaD = "9,10", vWA = "16", Empty = "",
        stringsAsFactors = FALSE
    ))
    out <- STRprofilerR:::.asClastrProfiles(p)

    expect_identical(names(out), "S1")
    expect_true("Penta D" %in% names(out[["S1"]]))
    expect_false("Empty" %in% names(out[["S1"]]))
    expect_identical(out[["S1"]][["Penta D"]], "9,10")
})

test_that("a bare named vector is accepted as one profile", {
    out <- STRprofilerR:::.asClastrProfiles(c(vWA = "16", TH01 = "8"))

    expect_identical(names(out), "Query")
    expect_identical(out[["Query"]][["vWA"]], "16")
    expect_error(STRprofilerR:::.asClastrProfiles(c("16")), "fully named")
})

test_that("algorithm and scoring mode map to the API's integers", {
    expect_identical(STRprofilerR:::.clastrAlgorithm("tanabe"), 1L)
    expect_identical(STRprofilerR:::.clastrAlgorithm("mastersQuery"), 2L)
    # strprofiler sends 2 here, which silently runs a Masters (query) search.
    expect_identical(STRprofilerR:::.clastrAlgorithm("mastersRef"), 3L)

    expect_identical(STRprofilerR:::.clastrScoringMode("nonEmpty"), 1L)
    expect_identical(STRprofilerR:::.clastrScoringMode("query"), 2L)
    expect_identical(STRprofilerR:::.clastrScoringMode("reference"), 3L)
})

test_that("unrecognised markers warn before the query is sent", {
    p <- STRProfiles(data.frame(Sample = "S1", marker1 = "12", stringsAsFactors = FALSE))

    expect_warning(
        STRprofilerR:::.warnClastrMarkers(names(STRprofilerR:::.asClastrProfiles(p)[["S1"]])),
        "not recognised by CLASTR"
    )
})

test_that("a live CLASTR query returns hits for a known profile", {
    skip_on_cran()
    skip_if_offline()
    skip_if_not_installed("curl")

    profile <- c(
        Amelogenin = "X", CSF1PO = "11,12", D2S1338 = "19,23", D3S1358 = "15,17",
        D5S818 = "11,12", D7S820 = "10", D8S1179 = "10", D13S317 = "11,12",
        D16S539 = "11,12", D18S51 = "13", D19S433 = "14", D21S11 = "29,30",
        FGA = "20,22", PentaD = "11,13", PentaE = "14,16", TH01 = "6,9",
        TPOX = "8,9", vWA = "17,19"
    )

    hits <- clastrQuery(profile, scoreFilter = 90, maxResults = 10)

    expect_s4_class(hits, "DataFrame")
    expect_gt(nrow(hits), 0L)
    expect_true("HT-29" %in% hits$name)
    expect_true(all(hits$score >= 90))
})
