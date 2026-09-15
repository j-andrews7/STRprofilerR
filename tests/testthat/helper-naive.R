# A deliberately literal transcription of the Python scoring loop, used to
# cross-check the vectorised implementation in scoreProfiles().
naiveScore <- function(query, reference, useAmel = FALSE) {
    qa <- alleles(query)
    ra <- alleles(reference)

    mk <- intersect(markers(query), markers(reference))
    if (!useAmel) {
        mk <- mk[classifyMarkers(mk) != "amelogenin"]
    }

    rows <- list()
    for (i in seq_len(nrow(query))) {
        for (k in seq_len(nrow(reference))) {
            nm <- 0L
            nq <- 0L
            nr <- 0L
            shared <- 0L

            for (m in mk) {
                a <- qa[[m]][[i]]
                b <- ra[[m]][[k]]
                if (length(a) > 0L && length(b) > 0L) {
                    nm <- nm + 1L
                    nq <- nq + length(a)
                    nr <- nr + length(b)
                    shared <- shared + length(intersect(a, b))
                }
            }

            rows[[length(rows) + 1L]] <- data.frame(
                query = rownames(query)[i],
                reference = rownames(reference)[k],
                nSharedMarkers = nm,
                nSharedAlleles = shared,
                nQueryAlleles = nq,
                nReferenceAlleles = nr,
                tanabeScore = 100 * 2 * shared / (nq + nr),
                mastersQueryScore = 100 * shared / nq,
                mastersRefScore = 100 * shared / nr,
                stringsAsFactors = FALSE
            )
        }
    }

    out <- do.call(rbind, rows)
    out[is.na(out)] <- NA_real_
    out
}

# Random profiles, with untyped markers and varying allele counts.
randomProfiles <- function(n, nMarkers, prefix, seed) {
    set.seed(seed)
    mk <- paste0("M", seq_len(nMarkers))

    cols <- lapply(mk, function(m) {
        vapply(seq_len(n), function(i) {
            k <- sample(0:3, 1L)
            if (k == 0L) "" else paste(sample(8:20, k), collapse = ",")
        }, character(1))
    })
    names(cols) <- mk

    df <- data.frame(
        Sample = paste0(prefix, seq_len(n)),
        cols,
        check.names = FALSE,
        stringsAsFactors = FALSE
    )
    df$AMEL <- sample(c("X", "X,Y"), n, replace = TRUE)

    STRProfiles(df)
}
