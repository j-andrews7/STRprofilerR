loadPair <- function() {
    list(
        query = readSTRProfiles(ed("ExampleSTR_long.csv"), sampleCol = "Sample Name"),
        reference = readSTRProfiles(ed("ExampleSTR_database.csv"), sampleCol = "Sample Name")
    )
}

test_that("compareProfiles scores queries against the reference only", {
    p <- loadPair()
    cmp <- compareProfiles(p$query, p$reference)

    expect_s4_class(cmp, "STRComparison")
    expect_identical(nrow(scores(cmp)), nrow(p$query) * nrow(p$reference))
    expect_setequal(scores(cmp)$reference, rownames(p$reference))
    expect_false(any(scores(cmp)$reference %in% rownames(p$query)))
})

test_that("the summary reports the top hits and threshold matches", {
    p <- loadPair()
    s <- as.data.frame(summary(compareProfiles(p$query, p$reference)))

    expect_identical(s$Sample, c("SampleA", "SampleB"))
    expect_identical(s$topHit, c("Ref_SampleA: 100.00", "Ref_SampleB: 100.00"))
    expect_identical(s$nextBest, c("Ref_SampleB: 88.89", "Ref_SampleA: 88.89"))
    expect_identical(s$mixed, c(FALSE, FALSE))
})

test_that("match columns are ordered by their own score", {
    p <- loadPair()
    s <- as.data.frame(summary(compareProfiles(p$query, p$reference)))

    # SampleB: Masters (query) puts Ref_SampleB (100) before Ref_SampleA (80).
    expect_identical(s$mastersQueryMatches[[2L]], "Ref_SampleB: 100.00; Ref_SampleA: 80.00")
})

test_that("a query with no comparisons summarises to NA rather than erroring", {
    # Python's make_summary indexes positionally and reports "" here (and
    # raised IndexError through strprofiler 0.4.2).
    p <- loadPair()
    cmp <- compareProfiles(p$query, p$reference, minScore = 99.9)
    s <- as.data.frame(summary(cmp))

    expect_identical(s$topHit, c("Ref_SampleA: 100.00", "Ref_SampleB: 100.00"))
    expect_true(all(is.na(s$nextBest)))
})

test_that("an Amelogenin column is scored only when asked for", {
    # strprofiler 0.5.1's test_compare_honors_amel_col. Before 0.5.1 its CLI
    # ignored --amel_col and always scored a column not named AMEL; here any
    # amelogenin spelling is recognised without configuration.
    p <- STRProfiles(data.frame(
        Sample = c("Sample_A", "Sample_B"),
        Amelogenin = c("X", "X,Y"),
        m1 = "12", m2 = "14", m3 = "9"
    ))

    expect_identical(summary(compareProfiles(p))$topHit[[1L]], "Sample_B: 100.00")
    expect_identical(summary(compareProfiles(p, useAmel = TRUE))$topHit[[1L]], "Sample_B: 88.89")
})

test_that("a single profile with no reference is rejected", {
    one <- readSTRProfiles(ed("ExampleSTR_long_1samp.csv"), sampleCol = "Sample Name")

    expect_error(compareProfiles(one), "no reference")
})

test_that("thresholds are carried on the object", {
    p <- loadPair()
    cmp <- compareProfiles(p$query, p$reference, tanThreshold = 95, useAmel = TRUE)

    expect_identical(params(cmp)$tanThreshold, 95)
    expect_true(params(cmp)$useAmel)
    expect_identical(params(cmp)$version, as.character(utils::packageVersion("STRprofilerR")))
})

test_that("writeSTRResults writes the expected file set", {
    p <- loadPair()
    cmp <- compareProfiles(p$query, p$reference)

    dir <- withr::local_tempdir()
    written <- writeSTRResults(cmp, dir, timestamp = as.POSIXct("2026-01-02 03:04:05", tz = "UTC"))

    expect_setequal(names(written), c("summary", "SampleA", "SampleB", "html", "log"))
    expect_true(all(file.exists(written)))
    expect_true(file.exists(file.path(dir, "full_summary.STRprofilerR.20260102.03_04_05.csv")))
    expect_true(file.exists(file.path(dir, "SampleA.STRprofilerR.20260102.03_04_05.csv")))
    expect_true(file.exists(file.path(dir, "STRprofilerR.20260102.03_04_05.log")))
})

test_that("the per-sample table leads with the query and lists every reference", {
    p <- loadPair()
    cmp <- compareProfiles(p$query, p$reference)

    dir <- withr::local_tempdir()
    written <- writeSTRResults(cmp, dir, formats = "csv")
    tbl <- read.csv(written[["SampleA"]], check.names = FALSE)

    expect_identical(tbl$Sample[[1L]], "SampleA")
    expect_true(tbl$querySample[[1L]])
    expect_true(is.na(tbl$tanabeScore[[1L]]))
    expect_setequal(tbl$Sample[-1L], rownames(p$reference))

    # Reference alleles travel with each row.
    expect_identical(tbl$marker1[tbl$Sample == "Ref_SampleE"], "14")
})

test_that("the summary CSV round-trips", {
    p <- loadPair()
    cmp <- compareProfiles(p$query, p$reference)

    dir <- withr::local_tempdir()
    written <- writeSTRResults(cmp, dir, formats = "csv", perSample = FALSE)
    back <- read.csv(written[["summary"]], check.names = FALSE, colClasses = "character")

    expect_identical(back$Sample, as.data.frame(summary(cmp))$Sample)
    expect_identical(back$topHit, as.data.frame(summary(cmp))$topHit)
})

test_that("the log records parameters and versions", {
    p <- loadPair()
    cmp <- compareProfiles(p$query, p$reference, tanThreshold = 77)

    dir <- withr::local_tempdir()
    written <- writeSTRResults(cmp, dir, formats = "csv", perSample = FALSE)
    txt <- readLines(written[["log"]])

    expect_true(any(grepl("Tanabe threshold: 77", txt, fixed = TRUE)))
    expect_true(any(grepl(as.character(utils::packageVersion("STRprofilerR")), txt, fixed = TRUE)))
    expect_true(any(grepl("ExampleSTR_database.csv", txt, fixed = TRUE)))
})

test_that("file names are sanitised but sample names are not", {
    df <- data.frame(
        Sample = c("HT-29/P3", "B"), m1 = c("12", "12"), m2 = c("13", "14"),
        stringsAsFactors = FALSE
    )
    cmp <- compareProfiles(STRProfiles(df))

    dir <- withr::local_tempdir()
    written <- writeSTRResults(cmp, dir, formats = "csv")

    expect_true(any(grepl("HT-29_P3.STRprofilerR", basename(written), fixed = TRUE)))
    expect_identical(read.csv(written[["HT-29/P3"]])$Sample[[1L]], "HT-29/P3")
})

test_that("strHTMLTable writes a standalone file", {
    f <- withr::local_tempfile(fileext = ".html")
    strHTMLTable(head(iris), f)

    expect_true(file.exists(f))
    expect_gt(file.size(f), 100)
})

test_that("the static HTML fallback escapes markup", {
    html <- STRprofilerR:::.staticHTMLTable(
        data.frame(a = "<script>x</script>", stringsAsFactors = FALSE), "T"
    )

    expect_false(any(grepl("<script>", html, fixed = TRUE)))
    expect_true(any(grepl("&lt;script&gt;", html, fixed = TRUE)))
})

test_that("the HTML table is a single self-contained file", {
    p <- loadPair()
    cmp <- compareProfiles(p$query, p$reference)

    dir <- withr::local_tempdir()
    writeSTRResults(cmp, dir, formats = "html")

    # saveWidget() otherwise leaves a "<name>_files" dependency directory here.
    expect_length(list.dirs(dir, recursive = FALSE), 0L)
    expect_length(list.files(dir), 2L) # html + log
})
