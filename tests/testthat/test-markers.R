test_that("harmonizeMarkers resolves the Penta spellings", {
    expect_identical(
        harmonizeMarkers(c("Penta C", "Penta_D", "Penta-E", "vWA")),
        c("PentaC", "PentaD", "PentaE", "vWA")
    )
})

test_that("harmonizeMarkers inverts for CLASTR", {
    expect_identical(
        harmonizeMarkers(c("PentaD", "PentaE", "PentaC"), reverse = TRUE),
        c("Penta D", "Penta E", "Penta C")
    )
})

test_that("harmonizeMarkers accepts user-supplied aliases", {
    expect_identical(
        harmonizeMarkers("AMELOGENIN", extra = c(AMELOGENIN = "AMEL")),
        "AMEL"
    )
    expect_error(harmonizeMarkers("x", extra = "AMEL"), "fully named")
})

test_that("classifyMarkers tags amelogenin and Y-linked markers", {
    expect_identical(
        classifyMarkers(c("AMEL", "Amelogenin", "DYS391", "vWA", "PentaD")),
        c("amelogenin", "amelogenin", "y-linked", "autosomal", "autosomal")
    )
})
