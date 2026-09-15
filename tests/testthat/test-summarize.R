scoresFor <- function(...) {
    q <- readSTRProfiles(ed("ExampleSTR_long.csv"), sampleCol = "Sample Name")
    r <- readSTRProfiles(ed("ExampleSTR_database.csv"), sampleCol = "Sample Name")
    list(query = q, scores = scoreProfiles(q, r, ...))
}

test_that("summarizeMatches works without the query profiles", {
    s <- scoresFor()
    out <- summarizeMatches(s$scores)

    expect_identical(colnames(out), c(
        "Sample", "topHit", "nextBest", "tanabeMatches",
        "mastersQueryMatches", "mastersRefMatches"
    ))
    expect_false("mixed" %in% colnames(out))
    expect_identical(out$Sample, c("SampleA", "SampleB"))
})

test_that("supplying profiles adds the mixing flag and alleles", {
    s <- scoresFor()
    out <- summarizeMatches(s$scores, s$query)

    expect_true(all(c("mixed", "marker1", "AMEL") %in% colnames(out)))
    expect_identical(out$mixed, c(FALSE, FALSE))
    expect_identical(out$marker1, c("12,14", "12,14"))
})

test_that("includeAlleles = FALSE keeps the summary narrow", {
    s <- scoresFor()
    out <- summarizeMatches(s$scores, s$query, includeAlleles = FALSE)

    expect_true("mixed" %in% colnames(out))
    expect_false("marker1" %in% colnames(out))
})

test_that("thresholds filter each match column independently", {
    s <- scoresFor()
    out <- summarizeMatches(s$scores, s$query, tanThreshold = 100, masQThreshold = 0)

    expect_identical(out$tanabeMatches, c("Ref_SampleA: 100.00", "Ref_SampleB: 100.00"))
    expect_true(all(grepl("Ref_SampleD", out$mastersQueryMatches, fixed = TRUE)))
})

test_that("scores are shown to two decimal places", {
    s <- scoresFor()
    out <- summarizeMatches(s$scores, s$query)

    expect_true(endsWith(out$nextBest[[1L]], ": 88.89"))
    expect_true(endsWith(out$topHit[[1L]], ": 100.00"))
})

test_that("a query with no surviving comparisons summarises to NA and empty", {
    s <- scoresFor(minScore = 101)
    out <- summarizeMatches(s$scores, s$query)

    expect_true(all(is.na(out$topHit)))
    expect_true(all(is.na(out$nextBest)))
    expect_identical(out$tanabeMatches, c("", ""))
})

test_that("summaries keep every query, including unmatched ones", {
    s <- scoresFor(minScore = 99)
    out <- summarizeMatches(s$scores, s$query)

    expect_identical(nrow(out), nrow(s$query))
})
