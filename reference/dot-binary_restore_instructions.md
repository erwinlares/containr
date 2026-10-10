# Dockerfile instructions that restore packages from precompiled binaries

Posit Package Manager serves precompiled Linux binaries at
`.../cran/__linux__/<codename>/<snapshot>`. Restoring from there skips
compilation, which is where almost all of a source restore's time goes.
The binaries are still linked against system libraries, so the `apt-get`
block that
[`.fetch_sysreqs()`](https://erwinlares.github.io/containr/reference/dot-fetch_sysreqs.md)
and `install_syslibs` build is needed just as much as for a source
restore. The `-dev` packages in it also pull in the matching runtime
libraries, for instance `libwebpmux3` through `libwebp-dev`.

## Usage

``` r
.binary_restore_instructions(image_os_version, snapshot = "latest")
```

## Arguments

- image_os_version:

  Character. The Ubuntu release backing the image's `FROM` line, from
  [`.resolve_os_version()`](https://erwinlares.github.io/containr/reference/dot-resolve_os_version.md).

- snapshot:

  Character. `"latest"` or a `"YYYY-MM-DD"` snapshot date.

## Value

A character vector of two `RUN` instructions, or `NULL` when there is no
codename for `image_os_version`, in which case the caller keeps the
source restore.

## Details

The codename must name the Ubuntu release the image is actually built
on, not the release a system-requirements lookup was asked about, since
a binary built for one release is not guaranteed to load on another.
