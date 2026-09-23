# Clean and split a vector of allele calls

Splits comma-separated allele strings into their component alleles,
de-duplicating and ordering them consistently.

## Usage

``` r
cleanAlleles(x, keepCalls = c("X", "Y"))
```

## Arguments

- x:

  Character vector of comma-separated allele calls. `NA` is treated as
  an empty call.

- keepCalls:

  Character vector of non-numeric calls that count as alleles, compared
  case-insensitively against each whole token and stored in the spelling
  given here. Exports are not consistent about capitalisation. Pass
  `character(0)` to accept repeat counts only.

## Value

A
[IRanges::CharacterList](https://rdrr.io/pkg/IRanges/man/AtomicList-class.html)
the same length as `x`, each element the cleaned allele vector for the
corresponding input.

## Details

Each element is split on commas and each token trimmed. A token survives
only if it is an allele:

- a finite repeat count, de-duplicated numerically, sorted ascending,
  and rendered without a trailing `.0`, so `"10.0"` and `"10"` collapse
  to a single `"10"` while `"9.3"` is preserved; or

- one of the calls named in `keepCalls`, matched case-insensitively and
  stored in the spelling given there, so `"x"` and `"X"` are one allele
  rather than two that never match. These sort after the numeric
  alleles.

Everything else is discarded: the empty token left by a trailing comma
(`"12,"`), the codes a capillary-electrophoresis export uses for a peak
it could not call (`OL` for one outside the ladder, `?` for one it
declined to type, `NR`, `ND` and the like), and free text. None of them
is an allele, and keeping them makes two profiles that merely failed at
the same marker score as sharing a value; discarding them leaves the
marker untyped, which lowers the shared-marker count instead. `"nan"`
and `"inf"` go the same way, though
[`as.numeric()`](https://rdrr.io/r/base/numeric.html) accepts both.

`keepCalls` defaults to the amelogenin sex markers, the only allele
calls that are not repeat counts.
[`readSTRProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/readSTRProfiles.md)
and
[`STRProfiles()`](https://j-andrews7.github.io/STRprofilerR/reference/STRProfiles.md)
are stricter still and honour `keepCalls` at amelogenin markers only,
since a letter at any other marker is a failed call rather than a sex
call. `strprofiler` 0.5.0 keeps `X`/`Y` at every marker; through 0.4.2
it scored every one of these codes as an ordinary allele.

## Author

Jared Andrews

## Examples

``` r
cleanAlleles("10.0,10,13,13.0,14,14 ")
#> CharacterList of length 1
#> [[1]] 10 13 14

# The sex markers are kept, in one spelling, and sort after numeric alleles.
cleanAlleles(c("Y,X", "17.3, 12", "", NA))
#> CharacterList of length 4
#> [[1]] X Y
#> [[2]] 12 17.3
#> [[3]] character(0)
#> [[4]] character(0)
cleanAlleles("x,X,y")
#> CharacterList of length 1
#> [[1]] X Y

# Uncallable peaks and free text are discarded, leaving a marker untyped.
cleanAlleles("OL,11")
#> CharacterList of length 1
#> [[1]] 11
cleanAlleles(c("OL", "12,NR,ND"))
#> CharacterList of length 2
#> [[1]] character(0)
#> [[2]] 12

# Repeat counts only.
cleanAlleles("12,X", keepCalls = character(0))
#> CharacterList of length 1
#> [[1]] 12
```
