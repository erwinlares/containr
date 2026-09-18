# Resolve the Ubuntu version backing a given R version's Rocker image

The Rocker Project ties each image's Ubuntu base OS to the R version's
release date, via what the project's own documentation describes as a
rule of building against the Ubuntu LTS current about 90 days after that
R release: Ubuntu 20.04 backs R 4.0.0-4.1.3, 22.04 backs R 4.2.2-4.3.3,
and 24.04 backs R 4.4.2 and later (confirmed directly against
rocker-project.org and the rocker-versioned2 wiki, 2026-09 – not
assumed). Querying the sysreqs API (C14) against the wrong Ubuntu
release risks both false positives (an apt package name that does not
exist on the actual base image) and false negatives (a renamed or
Ubuntu-version-specific package the lookup misses), for any R version
outside whatever window a hardcoded default happens to match.

## Usage

``` r
.resolve_os_version(x)
```

## Arguments

- x:

  Character. A resolved `r_version`, in the same shapes
  [`.extract_r_version_prefix()`](https://erwinlares.github.io/containr/reference/dot-extract_r_version_prefix.md)
  accepts – a bare major version, a CUDA/Ubuntu-suffixed tag, or the
  non-numeric `"latest"`/`"devel"`.

## Value

A character string Ubuntu version, e.g. `"22.04"`.
