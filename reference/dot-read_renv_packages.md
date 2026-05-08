# Read package names from renv.lock

Parses `renv.lock` in the current working directory and returns a
character vector of all package names recorded in the `Packages`
section.

## Usage

``` r
.read_renv_packages(lockfile = "renv.lock")
```

## Arguments

- lockfile:

  A character string. Path to the `renv.lock` file. Defaults to
  `"renv.lock"` in the current working directory.

## Value

A character vector of package names.
