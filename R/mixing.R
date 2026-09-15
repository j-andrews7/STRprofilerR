#' Flag potentially mixed samples
#'
#' Flags samples showing signs of mixing or contamination, based on how many
#' markers carry more alleles than a single diploid genome can explain.
#'
#' @details
#' A marker is counted when it has **more than two** alleles. A sample is
#' flagged when the number of such markers is **strictly greater than**
#' `threeAlleleThreshold`. With the default of 3, a sample needs four or more
#' three-allele markers before it is flagged.
#'
#' This is a screening heuristic, not a test. A flagged sample warrants a look
#' at its electropherogram; an unflagged one is not evidence of purity.
#'
#' @param x A [STRProfiles] object.
#' @param threeAlleleThreshold Number of markers with more than two alleles
#'   tolerated before a sample is flagged.
#'
#' @return A named logical vector, one element per sample.
#'
#' @author Jared Andrews
#'
#' @seealso [compareProfiles()], which reports this alongside the scores.
#'
#' @examples
#' p <- readSTRProfiles(
#'     system.file("extdata", "Example_Batch_File.csv", package = "STRprofilerR")
#' )
#'
#' flagMixedSamples(p)
#'
#' # A stricter threshold flags fewer samples.
#' flagMixedSamples(p, threeAlleleThreshold = 5)
#'
#' @export
flagMixedSamples <- function(x, threeAlleleThreshold = 3) {
    stopifnot(is(x, "STRProfiles"))

    al <- alleles(x)
    past <- integer(nrow(al))
    for (j in seq_len(ncol(al))) {
        past <- past + (as.integer(S4Vectors::elementNROWS(al[[j]])) > 2L)
    }

    stats::setNames(past > threeAlleleThreshold, rownames(al))
}
