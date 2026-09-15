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
    # Divergence from Python, which keeps a trailing comma and later counts
    # the empty string as an allele.
    expect_identical(cleanAlleles("12,")[[1L]], "12")
    expect_identical(cleanAlleles(",")[[1L]], character(0))
    expect_identical(cleanAlleles("")[[1L]], character(0))
    expect_identical(cleanAlleles(NA)[[1L]], character(0))
})

test_that("cleanAlleles is vectorised and returns a CharacterList", {
    out <- cleanAlleles(c("12,14", "", "X,Y"))
    expect_s4_class(out, "CharacterList")
    expect_length(out, 3L)
    expect_identical(as.integer(S4Vectors::elementNROWS(out)), c(2L, 0L, 2L))
})
