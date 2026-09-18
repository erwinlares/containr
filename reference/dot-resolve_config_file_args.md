# Resolve file arguments from a toolero project manifest

Internal helper backing
[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)'s
`config` argument. Parses `_toolero.yml` and returns the file arguments
it can derive from the manifest's declared `folders:` – one element per
argument the file has an opinion about, `NULL` for one it does not.
Never validates that the derived paths actually exist on disk; a stale
or hand-edited manifest surfaces as the same "does not exist" error from
[`.validate_file_arg()`](https://erwinlares.github.io/containr/reference/dot-validate_file_arg.md)
that a caller's own typo would, rather than a separate failure mode
here.

## Usage

``` r
.resolve_config_file_args(config)
```

## Arguments

- config:

  Character. Path to a `_toolero.yml` file.

## Value

A named list with elements `data_file`, `code_file`, and `misc_file`,
each a single character string or `NULL`.
