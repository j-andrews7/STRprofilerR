# Ported from the strprofiler Python suite:
#   tests/unit/test_ingress.py and tests/unit/test_database.py

paths <- function() c(ed("ExampleSTR_long.csv"), ed("ExampleSTR.xlsx"))

test_that("mixed long/wide ingest applies the sample map and penta fix", {
    skip_if_not_installed("readxl")

    p <- readSTRProfiles(
        paths(),
        sampleCol = "Sample Name",
        sampleMap = ed("SampleMap_exp.csv"),
        pentaFix = TRUE
    )

    expect_identical(rownames(p), c("SampleA", "SampleB", "Sample1", "Sample33"))
    expect_setequal(
        markers(p),
        c("marker1", "marker2", "marker4", "PentaE", "AMEL", "marker3", "PentaD")
    )
})

test_that("sample names are untouched when no sample map is supplied", {
    skip_if_not_installed("readxl")

    p <- readSTRProfiles(paths(), sampleCol = "Sample Name", pentaFix = TRUE)

    expect_identical(rownames(p), c("SampleA", "SampleB", "Sample1", "Sample3"))
})

test_that("pentaFix = FALSE keeps the original marker spellings apart", {
    skip_if_not_installed("readxl")

    p <- readSTRProfiles(
        paths(),
        sampleCol = "Sample Name",
        sampleMap = ed("SampleMap_exp.csv"),
        pentaFix = FALSE
    )

    expect_setequal(
        markers(p),
        c("marker1", "marker2", "marker4", "Penta D", "Penta E", "AMEL", "marker3", "PentaD")
    )
})

test_that("alleles are parsed correctly across both layouts", {
    skip_if_not_installed("readxl")

    p <- readSTRProfiles(
        paths(),
        sampleCol = "Sample Name",
        sampleMap = ed("SampleMap_exp.csv"),
        pentaFix = TRUE
    )
    ordered <- p[, c("marker1", "marker2", "marker4", "PentaD", "PentaE", "AMEL", "marker3")]

    expect_identical(
        flatSample(ordered, "SampleA"),
        c("12,14", "12", "13", "9,10", "12,14", "X", "")
    )
    expect_identical(
        flatSample(ordered, "Sample33"),
        c("12,18,19", "20,25,29", "", "10,11,12", "10,13,18", "X,Y", "10,11,16")
    )
})

test_that("database files ingest with the expected samples and markers", {
    p <- readSTRProfiles(ed("ExampleSTR_database.csv"), sampleCol = "Sample Name")

    expect_identical(
        rownames(p),
        c("Ref_SampleA", "Ref_SampleB", "Ref_SampleC", "Ref_SampleD", "Ref_SampleE")
    )
    expect_setequal(
        markers(p),
        c("marker1", "marker2", "marker4", "PentaD", "PentaE", "AMEL")
    )

    ordered <- p[, c("marker1", "marker2", "marker4", "PentaD", "PentaE", "AMEL")]
    expect_identical(
        flatSample(ordered, "Ref_SampleA"),
        c("12,14", "12", "13", "9,10", "12,14", "X")
    )
    expect_identical(
        flatSample(ordered, "Ref_SampleE"),
        c("14", "13", "13,15", "13", "12,15", "X,Y")
    )
})

test_that("Center and Passage are metadata, not markers", {
    p <- readSTRProfiles(ed("main_database.csv"))

    expect_false(any(c("Center", "Passage") %in% markers(p)))
    expect_identical(colnames(sampleData(p)), c("Center", "Passage"))
})

test_that("a lone comma is read as an untyped marker", {
    p <- readSTRProfiles(ed("main_database.csv"))

    # J000077591 has a literal "," in D2S1338 in the stock database.
    expect_length(alleles(p)[["D2S1338"]][["J000077591"]], 0L)
})

test_that("duplicate sample names are rejected", {
    df <- data.frame(Sample = c("A", "A"), vWA = c("16", "17"))

    expect_error(STRProfiles(df), "Duplicated sample names")
})

test_that("a missing sample column reports the available columns", {
    expect_error(
        readSTRProfiles(ed("ExampleSTR_long.csv"), sampleCol = "Nope"),
        "'Nope'"
    )
})

test_that("unsupported extensions are rejected", {
    f <- withr::local_tempfile(fileext = ".docx")
    file.create(f)

    expect_error(readSTRProfiles(f), "is not supported")
})

test_that("profiles round-trip through data.frame and disk", {
    p <- readSTRProfiles(ed("ExampleSTR_database.csv"), sampleCol = "Sample Name")

    expect_identical(as.data.frame(STRProfiles(as.data.frame(p))), as.data.frame(p))

    f <- withr::local_tempfile(fileext = ".csv")
    writeSTRProfiles(p, f)
    back <- readSTRProfiles(f)

    expect_identical(rownames(back), rownames(p))
    expect_identical(markers(back), markers(p))
    expect_identical(as.data.frame(back), as.data.frame(p))
})

test_that("subsetting keeps the annotations aligned", {
    p <- readSTRProfiles(ed("main_database.csv"))
    sub <- p[1:3, markerData(p)$class != "amelogenin"]

    expect_identical(dim(sub), c(3L, length(markers(p)) - 1L))
    expect_identical(rownames(markerData(sub)), markers(sub))
    expect_identical(rownames(sampleData(sub)), rownames(sub))
    expect_false("Amelogenin" %in% markers(sub))
})

test_that("unknown subscripts are reported by name", {
    p <- readSTRProfiles(ed("ExampleSTR_database.csv"), sampleCol = "Sample Name")

    expect_error(p["Nope", ], "Unknown sample")
    expect_error(p[, "Nope"], "Unknown marker")
})
