# Ported from the strprofiler Python suite: tests/unit/test_scoring.py

pyQuery <- function() {
    STRProfiles(data.frame(
        Sample = "q",
        mark1 = "11,12", mark2 = "", mark3 = "13", mark4 = "5,5,7", AMEL = "X",
        stringsAsFactors = FALSE
    ))
}

pyReference <- function() {
    STRProfiles(data.frame(
        Sample = "r",
        mark1 = "11,12", mark2 = "3", mark3 = "13,14", mark4 = "5,7", AMEL = "X",
        stringsAsFactors = FALSE
    ))
}

test_that("scores match the Python reference, amelogenin excluded", {
    s <- scoreProfiles(pyQuery(), pyReference())

    expect_identical(s$nSharedMarkers, 3L)
    expect_identical(s$nSharedAlleles, 5L)
    expect_identical(s$nQueryAlleles, 5L)
    expect_identical(s$nReferenceAlleles, 6L)

    expect_identical(sprintf("%.2f", s$tanabeScore), "90.91")
    expect_identical(s$mastersQueryScore, 100)
    expect_identical(sprintf("%.2f", s$mastersRefScore), "83.33")
})

test_that("scores match the Python reference, amelogenin included", {
    s <- scoreProfiles(pyQuery(), pyReference(), useAmel = TRUE)

    expect_identical(s$nSharedMarkers, 4L)
    expect_identical(s$nSharedAlleles, 6L)
    expect_identical(s$nQueryAlleles, 6L)
    expect_identical(s$nReferenceAlleles, 7L)

    expect_identical(sprintf("%.2f", s$tanabeScore), "92.31")
    expect_identical(s$mastersQueryScore, 100)
    expect_identical(sprintf("%.2f", s$mastersRefScore), "85.71")
})

test_that("untyped markers are excluded from both numerator and denominator", {
    # mark2 is empty in the query, so the reference's lone mark2 allele must not
    # inflate nReferenceAlleles.
    s <- scoreProfiles(pyQuery(), pyReference())

    expect_identical(s$nReferenceAlleles, 6L)
    expect_false(s$nReferenceAlleles == 7L)
})

test_that("duplicate alleles are counted once", {
    # "5,5,7" is two alleles, not three.
    q <- STRProfiles(data.frame(Sample = "q", m = "5,5,7", stringsAsFactors = FALSE))
    r <- STRProfiles(data.frame(Sample = "r", m = "5,7", stringsAsFactors = FALSE))

    expect_identical(scoreProfiles(q, r)$nQueryAlleles, 2L)
})

test_that("the vectorised scorer agrees with a naive pairwise loop", {
    q <- randomProfiles(12, 10, "Q", seed = 1)
    r <- randomProfiles(20, 10, "R", seed = 2)

    for (useAmel in c(FALSE, TRUE)) {
        fast <- as.data.frame(suppressWarnings(scoreProfiles(q, r, useAmel = useAmel)))
        slow <- naiveScore(q, r, useAmel = useAmel)

        key <- function(d) paste(d$query, d$reference)
        slow <- slow[match(key(fast), key(slow)), ]

        expect_identical(fast$nSharedMarkers, slow$nSharedMarkers)
        expect_identical(fast$nSharedAlleles, slow$nSharedAlleles)
        expect_identical(fast$nQueryAlleles, slow$nQueryAlleles)
        expect_identical(fast$nReferenceAlleles, slow$nReferenceAlleles)
        expect_equal(fast$tanabeScore, slow$tanabeScore, tolerance = 1e-9)
        expect_equal(fast$mastersQueryScore, slow$mastersQueryScore, tolerance = 1e-9)
        expect_equal(fast$mastersRefScore, slow$mastersRefScore, tolerance = 1e-9)
    }
})

test_that("chunking does not change the result", {
    q <- randomProfiles(12, 8, "Q", seed = 3)
    r <- randomProfiles(9, 8, "R", seed = 4)

    whole <- suppressWarnings(scoreProfiles(q, r, chunkSize = 1000L))
    chunked <- suppressWarnings(scoreProfiles(q, r, chunkSize = 3L))

    expect_identical(as.data.frame(whole), as.data.frame(chunked))
})

test_that("all-against-all drops self comparisons", {
    p <- readSTRProfiles(ed("ExampleSTR_database.csv"), sampleCol = "Sample Name")
    s <- scoreProfiles(p)

    expect_false(any(s$query == s$reference))
    expect_identical(nrow(s), nrow(p) * (nrow(p) - 1L))
})

test_that("pairs with no shared markers score NA and warn once", {
    q <- STRProfiles(data.frame(Sample = "q", m1 = "1,2", m2 = "", stringsAsFactors = FALSE))
    r <- STRProfiles(data.frame(Sample = "r", m1 = "", m2 = "3,4", stringsAsFactors = FALSE))

    expect_warning(s <- scoreProfiles(q, r), "no markers in common")
    expect_identical(s$nSharedMarkers, 0L)
    expect_true(is.na(s$tanabeScore))
    expect_true(is.na(s$mastersQueryScore))
    expect_true(is.na(s$mastersRefScore))
})

test_that("profiles with no markers in common are rejected", {
    q <- STRProfiles(data.frame(Sample = "q", m1 = "1,2", stringsAsFactors = FALSE))
    r <- STRProfiles(data.frame(Sample = "r", zz = "3,4", stringsAsFactors = FALSE))

    expect_error(scoreProfiles(q, r), "No markers in common")
})

test_that("amelogenin-only overlap is rejected when amelogenin is excluded", {
    q <- STRProfiles(data.frame(Sample = "q", AMEL = "X", m1 = "1", stringsAsFactors = FALSE))
    r <- STRProfiles(data.frame(Sample = "r", AMEL = "X", zz = "1", stringsAsFactors = FALSE))

    expect_error(scoreProfiles(q, r), "No markers left to score")
    expect_silent(scoreProfiles(q, r, useAmel = TRUE))
})

test_that("minScore filters pairs", {
    q <- readSTRProfiles(ed("ExampleSTR_long.csv"), sampleCol = "Sample Name")
    r <- readSTRProfiles(ed("ExampleSTR_database.csv"), sampleCol = "Sample Name")

    s <- scoreProfiles(q, r, minScore = 90)

    expect_true(all(s$tanabeScore >= 90))
    expect_lt(nrow(s), nrow(scoreProfiles(q, r)))
})

test_that("results are ordered by query, then Tanabe descending", {
    q <- readSTRProfiles(ed("ExampleSTR_long.csv"), sampleCol = "Sample Name")
    r <- readSTRProfiles(ed("ExampleSTR_database.csv"), sampleCol = "Sample Name")
    s <- scoreProfiles(q, r)

    expect_identical(unique(s$query), rownames(q))
    for (g in split(s$tanabeScore, s$query)) {
        expect_false(is.unsorted(rev(g)))
    }
})

test_that("scoreQuery accepts a bare named vector", {
    r <- readSTRProfiles(ed("ExampleSTR_database.csv"), sampleCol = "Sample Name")

    s <- scoreQuery(c(marker1 = "12,14", marker2 = "12", marker4 = "13", AMEL = "X"), r)

    expect_identical(unique(s$query), "Query")
    expect_identical(nrow(s), nrow(r))
    expect_error(scoreQuery(c("12,14"), r), "fully named")
})

test_that("an empty query or reference gives an empty result, not an error", {
    p <- readSTRProfiles(ed("ExampleSTR_database.csv"), sampleCol = "Sample Name")
    empty <- p[integer(0), ]

    expect_identical(nrow(empty), 0L)
    expect_identical(nrow(scoreProfiles(empty, p)), 0L)
    expect_identical(nrow(scoreProfiles(p, empty)), 0L)
    expect_identical(colnames(scoreProfiles(empty, p)), colnames(scoreProfiles(p)))
})
