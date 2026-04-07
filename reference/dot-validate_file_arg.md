# Validate a file argument

Internal helper used by
[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
to check that optional file arguments (e.g. `data_file`, `code_file`,
`misc_file`) are valid.

## Usage

``` r
.validate_file_arg(arg_name, value)
```

## Arguments

- arg_name:

  Character string, the name of the argument being checked (used only in
  error messages).

- value:

  A character path to a file, or `NULL`.

## Value

A normalized file path if validation succeeds, or `NULL` if the input
was `NULL`.
