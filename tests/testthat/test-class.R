smallProfiles <- function(samples, ...) {
    STRProfiles(data.frame(Sample = samples, ..., stringsAsFactors = FALSE))
}

test_that("c() unions markers and stacks samples", {
    a <- smallProfiles(c("A1", "A2"), m1 = c("12", "13"), m2 = c("14", "15"))
    b <- smallProfiles("B1", m2 = "16", m3 = "17")

    both <- c(a, b)

    expect_identical(rownames(both), c("A1", "A2", "B1"))
    expect_setequal(markers(both), c("m1", "m2", "m3"))

    # A marker absent from one input is untyped there, not empty-but-typed.
    # Sample identity lives in the row names, so index the DataFrame by row.
    expect_length(alleles(both)["A1", ][["m3"]][[1L]], 0L)
    expect_identical(alleles(both)["B1", ][["m3"]][[1L]], "17")
    expect_identical(alleles(both)["A2", ][["m2"]][[1L]], "15")
})

test_that("c() rejects overlapping sample names", {
    a <- smallProfiles("S1", m1 = "12")
    b <- smallProfiles("S1", m1 = "13")

    expect_error(c(a, b), "Duplicated sample names across objects")
})

test_that("c() with a single argument is a no-op", {
    a <- smallProfiles(c("A1", "A2"), m1 = c("12", "13"))

    expect_identical(as.data.frame(c(a)), as.data.frame(a))
})

test_that("c() keeps sample metadata, filling gaps with NA", {
    a <- STRProfiles(data.frame(
        Sample = "A1", Center = "JAX", m1 = "12", stringsAsFactors = FALSE
    ))
    b <- smallProfiles("B1", m1 = "13")

    both <- c(a, b)

    expect_identical(sampleData(both)$Center, c("JAX", NA))
})

test_that("markerData tracks how many samples were typed at each marker", {
    p <- smallProfiles(c("A", "B", "C"), m1 = c("12", "", "13"), m2 = c("", "", "14"))

    expect_identical(markerData(p)$nTyped, c(2L, 1L))
})

test_that("nTyped is recomputed on subsetting", {
    p <- smallProfiles(c("A", "B", "C"), m1 = c("12", "", "13"))

    expect_identical(markerData(p[c("B", "C"), ])$nTyped, 1L)
})

test_that("a manual marker class survives subsetting", {
    p <- smallProfiles(c("A", "B"), m1 = c("12", "13"), m2 = c("14", "15"))
    markerData(p)$class[markers(p) == "m1"] <- "y-linked"

    expect_identical(markerData(p[1, ])$class, c("y-linked", "autosomal"))
})

test_that("replacement methods validate the object", {
    p <- smallProfiles(c("A", "B"), m1 = c("12", "13"))

    sampleData(p) <- S4Vectors::DataFrame(Center = c("X", "Y"), row.names = c("A", "B"))
    expect_identical(p$Center, c("X", "Y"))

    bad <- S4Vectors::DataFrame(Center = "X", row.names = "A")
    expect_error(sampleData(p) <- bad, "one row per row of 'alleles'")
})

test_that("assigning alleles resyncs markerData", {
    p <- smallProfiles(c("A", "B"), m1 = c("12", "13"))

    al <- alleles(p)
    al[["AMEL"]] <- cleanAlleles(c("X", "X,Y"))
    alleles(p) <- al

    expect_identical(markers(p), c("m1", "AMEL"))
    expect_identical(markerData(p)["AMEL", "class"], "amelogenin")
})

test_that("the object rejects a mismatched markerData", {
    p <- smallProfiles(c("A", "B"), m1 = c("12", "13"))

    expect_error(
        markerData(p) <- S4Vectors::DataFrame(class = "autosomal", row.names = "nope"),
        "must match 'colnames"
    )
})

test_that("dim, dimnames, and show agree with the contents", {
    p <- readSTRProfiles(ed("ExampleSTR_database.csv"), sampleCol = "Sample Name")

    expect_identical(dim(p), c(5L, 6L))
    expect_identical(dimnames(p), list(rownames(p), markers(p)))
    expect_output(show(p), "class: STRProfiles")
    expect_output(show(p), "samples(5)", fixed = TRUE)
})

test_that("provenance records the inputs and options", {
    p <- readSTRProfiles(ed("ExampleSTR_database.csv"), sampleCol = "Sample Name")
    prov <- provenance(p)

    expect_identical(basename(prov$files), "ExampleSTR_database.csv")
    expect_identical(prov$options$sampleCol, "Sample Name")
    expect_true(prov$options$pentaFix)
    expect_s3_class(prov$timestamp, "POSIXct")
})
