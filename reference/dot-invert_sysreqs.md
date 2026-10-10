# Turn "package -\> libraries" into "library -\> packages"

Turn "package -\> libraries" into "library -\> packages"

## Usage

``` r
.invert_sysreqs(traced)
```

## Arguments

- traced:

  A named list. Each element is the character vector of libraries one
  package reported.

## Value

A named list: each element is the character vector of packages that
reported the library it is named after, libraries in alphabetical order.
Empty when no package reported anything.
