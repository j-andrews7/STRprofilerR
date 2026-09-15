# Path to a bundled example file.
ed <- function(f) system.file("extdata", f, package = "STRprofilerR")

# Collapse one sample's alleles back to comma-joined strings, in marker order.
flatSample <- function(x, sample) {
    unname(vapply(
        as.list(alleles(x)[sample, ]),
        function(z) S4Vectors::unstrsplit(z, ","),
        character(1)
    ))
}
