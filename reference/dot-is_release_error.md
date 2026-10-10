# Is this error `remotes` rejecting the Ubuntu release it was asked about?

[`remotes::system_requirements()`](https://remotes.r-lib.org/reference/system_requirements.html)
checks the release with
[`match.arg()`](https://rdrr.io/r/base/match.arg.html), which produces
"'arg' should be one of ...".

## Usage

``` r
.is_release_error(e)
```

## Arguments

- e:

  A condition object.

## Value

A single logical.
