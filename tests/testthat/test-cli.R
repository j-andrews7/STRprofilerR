# The Rapp app lives in the package's top-level exec/ directory, which is only
# reachable via system.file() once the package is installed.
appPath <- function() {
    p <- system.file("exec", "strprofiler.R", package = "STRprofilerR")
    if (nzchar(p) && file.exists(p)) {
        return(p)
    }

    p <- testthat::test_path("..", "..", "exec", "strprofiler.R")
    if (file.exists(p)) {
        return(normalizePath(p, winslash = "/"))
    }
    NA_character_
}

skipUnlessApp <- function() {
    skip_if_not_installed("Rapp")
    skip_if(is.na(appPath()), "Rapp app script not found")
}

runApp <- function(args) {
    utils::capture.output(Rapp::run(appPath(), args))
}

test_that("the app advertises its three commands", {
    skipUnlessApp()
    out <- runApp("--help")

    expect_true(any(grepl("compare", out, fixed = TRUE)))
    expect_true(any(grepl("clastr", out, fixed = TRUE)))
    expect_true(any(grepl("app", out, fixed = TRUE)))
})

test_that("compare help lists every option, in kebab-case", {
    skipUnlessApp()
    out <- paste(runApp(c("compare", "--help")), collapse = "
")

    for (flag in c(
        "--tan-threshold", "--mas-q-threshold", "--mas-r-threshold",
        "--mix-threshold", "--sample-map", "--database", "--sample-col",
        "--marker-col", "--score-amel", "--output-dir"
    )) {
        expect_match(out, flag, fixed = TRUE)
    }

    # penta_fix defaults to TRUE, so Rapp exposes the negative alias.
    expect_match(out, "--no-penta-fix", fixed = TRUE)
})

test_that("clastr help lists every option, in kebab-case", {
    skipUnlessApp()
    out <- paste(runApp(c("clastr", "--help")), collapse = "
")

    for (flag in c(
        "--search-algorithm", "--scoring-mode", "--score-filter",
        "--max-results", "--min-markers"
    )) {
        expect_match(out, flag, fixed = TRUE)
    }
})

test_that("the Python package's underscore flags still work", {
    skipUnlessApp()

    dir <- withr::local_tempdir()
    runApp(c(
        "compare",
        "--tan_threshold", "90",
        "--database", ed("ExampleSTR_database.csv"),
        "--sample_col", "Sample Name",
        "--output_dir", dir,
        ed("ExampleSTR_long.csv")
    ))

    expect_length(list.files(dir, pattern = "^full_summary"), 2L)
})

test_that("compare writes the same results as the R API", {
    skipUnlessApp()

    dir <- withr::local_tempdir()
    runApp(c(
        "compare",
        "--database", ed("ExampleSTR_database.csv"),
        "--sample_col", "Sample Name",
        "-o", dir,
        ed("ExampleSTR_long.csv")
    ))

    summaries <- list.files(dir, pattern = "^full_summary", full.names = TRUE)
    summaries <- summaries[endsWith(summaries, ".csv")]

    fromCli <- read.csv(summaries, check.names = FALSE, colClasses = "character")
    fromApi <- as.data.frame(summary(compareProfiles(
        readSTRProfiles(ed("ExampleSTR_long.csv"), sampleCol = "Sample Name"),
        readSTRProfiles(ed("ExampleSTR_database.csv"), sampleCol = "Sample Name")
    )))

    expect_identical(fromCli$Sample, fromApi$Sample)
    expect_identical(fromCli$topHit, fromApi$topHit)
    expect_identical(fromCli$tanabeMatches, fromApi$tanabeMatches)
})

test_that("the app command reports that the Shiny port is pending", {
    skipUnlessApp()

    expect_error(Rapp::run(appPath(), "app"), "not been ported yet")
})
