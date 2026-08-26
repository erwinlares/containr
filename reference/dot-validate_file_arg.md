# Validate a file argument

Internal helper used by
[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
to check that optional file arguments (e.g. `data_file`, `code_file`,
`misc_file`) are valid. Accepts a single path, a character vector of
paths, or a path to a directory (copied whole). Returns each path
relative to the current working directory, which serves as the
Docker/Podman build context.

## Usage

``` r
.validate_file_arg(arg_name, value)
```

## Arguments

- arg_name:

  Character string, the name of the argument being checked (used only in
  error messages).

- value:

  A character vector of paths to files and/or directories, or `NULL`.
  Every element is validated independently, so a vector may freely mix
  files and directories.

## Value

A character vector of paths relative to the current working directory,
one per element of `value`, if validation succeeds, or `NULL` if the
input was `NULL`.
