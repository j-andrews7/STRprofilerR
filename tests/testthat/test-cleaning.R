# Ported from the strprofiler Python suite: tests/unit/test_cleaning.py

test_that("cleanAlleles dedupes, sorts, and strips trailing .0", {
    expect_identical(
        cleanAlleles("10.0,10,13,13.0,14,14 ")[[1L]],
        c("10", "13", "14")
    )
})

test_that("cleanAlleles orders numeric alleles before string alleles", {
    expect_identical(cleanAlleles("Y,X")[[1L]], c("X", "Y"))
    expect_identical(cleanAlleles("X,12,Y,9.3")[[1L]], c("9.3", "12", "X", "Y"))
})

test_that("cleanAlleles preserves genuine decimal alleles", {
    expect_identical(cleanAlleles("31.2,29,17.3")[[1L]], c("17.3", "29", "31.2"))
})

test_that("cleanAlleles does not truncate alleles ending in zero", {
    # strprofiler issue #10: "10" was being turned into "1".
    expect_identical(cleanAlleles("10,20,100")[[1L]], c("10", "20", "100"))
})

test_that("cleanAlleles drops empty tokens", {
    # strprofiler did the same from 0.5.0; through 0.4.2 a trailing comma
    # survived cleaning and the empty string was counted as an allele.
    expect_identical(cleanAlleles("12,")[[1L]], "12")
    expect_identical(cleanAlleles(",")[[1L]], character(0))
    expect_identical(cleanAlleles("")[[1L]], character(0))
    expect_identical(cleanAlleles(NA)[[1L]], character(0))
})

test_that("cleanAlleles folds the case of kept calls", {
    # Scoring compares the cleaned calls literally, so "x" and "X" would
    # otherwise be two alleles that never match. strprofiler 0.5.0 does the same.
    expect_identical(cleanAlleles("X,x")[[1L]], "X")
    expect_identical(cleanAlleles("x,y")[[1L]], c("X", "Y"))
    expect_identical(cleanAlleles("12,x")[[1L]], c("12", "X"))

    # The stored spelling is the one 'keepCalls' gives, not the one typed.
    expect_identical(cleanAlleles("X,x", keepCalls = "x")[[1L]], "x")
})

test_that("cleanAlleles is vectorised and returns a CharacterList", {
    out <- cleanAlleles(c("12,14", "", "X,Y"))
    expect_s4_class(out, "CharacterList")
    expect_length(out, 3L)
    expect_identical(as.integer(S4Vectors::elementNROWS(out)), c(2L, 0L, 2L))
})

test_that("cleanAlleles drops uncallable calls by default", {
    expect_identical(cleanAlleles("OL,11")[[1L]], "11")
    expect_identical(cleanAlleles("12,?")[[1L]], "12")
    expect_identical(cleanAlleles("OL")[[1L]], character(0))
})

test_that("cleanAlleles keeps only repeat counts and the calls in keepCalls", {
    # The assertions of strprofiler 0.5.0's test_cleaning_discards_non_numeric_alleles.
    cases <- list(
        c("12,OL", "12"), c("12,?", "12"), c("12,OL,14", "12,14"),
        c("12,NR", "12"), c("12,ND", "12"), c("12,NA", "12"), c("12,-", "12"),
        c("12,n/a", "12"), c("12,JAX", "12"),
        # float()/as.numeric() accept these, but they are not alleles.
        c("12,nan", "12"), c("12,inf", "12"), c("12,-inf", "12"), c("12,NaN", "12"),
        # The sex markers are real calls and must survive.
        c("X,Y", "X,Y"), c("X,OL", "X"), c("12,X,OL,?", "12,X"),
        c("x,y", "X,Y"), c("X,x", "X")
    )

    for (case in cases) {
        expect_identical(
            cleanAlleles(case[[1L]])[[1L]],
            strsplit(case[[2L]], ",", fixed = TRUE)[[1L]],
            info = case[[1L]]
        )
    }

    # A marker typed only as uncallable is left untyped.
    expect_identical(cleanAlleles("OL")[[1L]], character(0))
    expect_identical(cleanAlleles("?")[[1L]], character(0))
    expect_identical(cleanAlleles("OL,?")[[1L]], character(0))
})

test_that("cleanAlleles matches keepCalls case-insensitively", {
    expect_identical(cleanAlleles("ol,11")[[1L]], "11")
    expect_identical(cleanAlleles("12,y")[[1L]], c("12", "Y"))
})

test_that("keepCalls is user-extensible", {
    # A lab that records "NR" as meaningful can say so.
    expect_identical(cleanAlleles("NR,14", keepCalls = c("X", "Y", "NR"))[[1L]], c("14", "NR"))
})

test_that("keepCalls = character(0) accepts repeat counts only", {
    expect_identical(cleanAlleles("12,X", keepCalls = character(0))[[1L]], "12")
    expect_identical(cleanAlleles("X,Y", keepCalls = character(0))[[1L]], character(0))
})
