# Ubuntu releases named in a `match.arg()` error

The error `remotes` raises for an unknown release lists the releases it
does accept, for instance "'arg' should be one of 14.04, 16.04, 18.04,
20.04, 22.04" with curly quotes around each. This reads them back out of
the message, so the list never has to be copied into this package.

## Usage

``` r
.accepted_releases(e)
```

## Arguments

- e:

  A condition object.

## Value

A character vector of releases such as `"22.04"`, possibly empty.
