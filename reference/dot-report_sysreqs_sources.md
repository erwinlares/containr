# Report which package asked for which system library

Looks each package up on its own and prints, for every library, the
packages that reported it. The grouped lookup that builds the `apt-get`
block answers "which libraries", never "because of what", so a library
missing from the image used to leave no trail. Run only in `verbose`
mode, since it makes one request per package, and it never changes what
[`.fetch_sysreqs()`](https://erwinlares.github.io/containr/reference/dot-fetch_sysreqs.md)
returns: a library that shows up here but not in the grouped answer is
named in a message and left for the caller to add through
`install_syslibs`.

## Usage

``` r
.report_sysreqs_sources(packages, os_version, syslibs)
```

## Arguments

- packages:

  Character vector of R package names.

- os_version:

  Character. The release the grouped lookup used.

- syslibs:

  Character vector. The libraries the grouped lookup found.

## Value

`invisible(NULL)`.

## Details

A failure while tracing is reported and otherwise ignored, because the
report is a diagnostic and not part of building the image.
