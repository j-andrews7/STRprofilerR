# Ported from the strprofiler Python suite: tests/unit/test_mixing.py

mixedSample <- function() {
    STRProfiles(data.frame(
        Sample = "s",
        mark1 = "11,12", mark2 = "3", mark3 = "13,14",
        mark4 = "5,7,9", mark5 = "5,7,9", mark6 = "5,7,9", mark7 = "5,7,9",
        AMEL = "X",
        stringsAsFactors = FALSE
    ))
}

test_that("flagMixedSamples matches the Python thresholds", {
    # Four markers carry three alleles.
    expect_true(unname(flagMixedSamples(mixedSample(), threeAlleleThreshold = 3)))
    expect_false(unname(flagMixedSamples(mixedSample(), threeAlleleThreshold = 5)))
})

test_that("the threshold is strictly greater-than", {
    # Exactly four three-allele markers: flagged at 3, not at 4.
    expect_true(unname(flagMixedSamples(mixedSample(), threeAlleleThreshold = 3)))
    expect_false(unname(flagMixedSamples(mixedSample(), threeAlleleThreshold = 4)))
})

test_that("two-allele markers never count towards mixing", {
    p <- STRProfiles(data.frame(
        Sample = "s",
        m1 = "1,2", m2 = "3,4", m3 = "5,6", m4 = "7,8", m5 = "9,10",
        stringsAsFactors = FALSE
    ))

    expect_false(unname(flagMixedSamples(p, threeAlleleThreshold = 0)))
})

test_that("flagMixedSamples is named by sample", {
    p <- readSTRProfiles(ed("Example_Batch_File.csv"))
    out <- flagMixedSamples(p)

    expect_type(out, "logical")
    expect_identical(names(out), rownames(p))
})
