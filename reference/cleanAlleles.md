# Clean and split a vector of allele calls

Splits comma-separated allele strings into their component alleles,
de-duplicating and ordering them consistently.

## Usage

``` r
cleanAlleles(x)
```

## Arguments

- x:

  Character vector of comma-separated allele calls. `NA` is treated as
  an empty call.

## Value

A
[IRanges::CharacterList](https://rdrr.io/pkg/IRanges/man/AtomicList-class.html)
the same length as `x`, each element the cleaned allele vector for the
corresponding input.

## Details

Each element is split on commas and each token trimmed. Tokens that
parse as numbers are de-duplicated numerically, sorted ascending, and
rendered without a trailing `.0`, so `"10.0"` and `"10"` collapse to a
single `"10"` while `"9.3"` is preserved. Tokens that do not parse as
numbers (such as the `X` and `Y` of amelogenin) are de-duplicated,
sorted, and placed after the numeric ones.

Empty tokens are dropped. This is a deliberate divergence from the
`strprofiler` Python package, where a trailing comma (`"12,"`) survives
cleaning and is later counted as a second, empty allele.

## Author

Jared Andrews

## Examples

``` r
cleanAlleles("10.0,10,13,13.0,14,14 ")
#> CharacterList of length 1
#> [[1]] 10 13 14

# Non-numeric alleles sort after numeric ones.
cleanAlleles(c("Y,X", "17.3, 12", "", NA))
#> CharacterList of length 4
#> [[1]] X Y
#> [[2]] 12 17.3
#> [[3]] character(0)
#> [[4]] character(0)
```
