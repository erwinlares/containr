# Resolve and validate a Quarto CLI version

Internal helper used by
[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
when `install_quarto = TRUE`. If `quarto_version` is `"latest"`, queries
the Quarto releases API to resolve it to a concrete version at
generation time, so the version actually pinned into the Dockerfile is
recorded rather than left as a moving target. If an explicit version is
supplied, validates its format and confirms a matching GitHub release
actually exists, so a typo or unreleased version fails here rather than
producing a Dockerfile that 404s at build time.

## Usage

``` r
.get_quarto_version(quarto_version = "latest", verbose = FALSE)
```

## Arguments

- quarto_version:

  Character string. Either `"latest"` or an explicit Quarto version,
  e.g. `"1.5.57"`.

- verbose:

  Logical. If `TRUE`, prints progress messages during resolution.
  Defaults to `FALSE`.

## Value

Character string. The resolved version, without a leading `"v"` (e.g.
`"1.5.57"`), suitable for interpolating directly into Quarto's versioned
download URL.
