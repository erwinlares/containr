# Extract and pad the leading numeric R version from a version string

Pulls the leading `X`, `X.Y`, or `X.Y.Z` numeric prefix from a resolved
`r_version` string and pads it to three components, so it can be safely
compared with
[`package_version()`](https://rdrr.io/r/base/numeric_version.html).
Handles the shapes `resolved_version` can take: a bare major version
(`"4"`), CUDA/Ubuntu suffixes (`"4.4.0-cuda12.2-ubuntu22.04"`), and the
non-numeric tags `"latest"` and `"devel"`, for which it returns
`NA_character_` – both always resolve to the current rocker-versioned2
image lineage, so callers should treat `NA` here as "no floor applies."

## Usage

``` r
.extract_r_version_prefix(x)
```

## Arguments

- x:

  Character string. A resolved R version, as produced by
  [`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)'s
  `r_version`/`"current"` resolution step.

## Value

A three-component version string (e.g. `"4.4.0"`), or `NA_character_` if
`x` has no leading numeric portion.
