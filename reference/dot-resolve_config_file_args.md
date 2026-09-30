# Resolve file arguments from a toolero project config

Internal helper backing
[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)'s
`config` argument. Parses `_toolero.yml` and returns the file arguments
it can derive from the config's declared `folders:` – one element per
argument the file has an opinion about, `NULL` for one it does not.
Never validates that the derived paths actually exist on disk; a stale
or hand-edited config surfaces as the same "does not exist" error from
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

A named list with elements `data_file` and `misc_file`, each a single
character string or `NULL`; and `folders`, a character vector of every
folder the config declares (possibly empty), for deriving the `mkdir -p`
block (C07).

## Details

`code_file` is not among the derived arguments (C32). The analysis
script travels with each cluster job rather than being baked into the
image, so the config's `script_dir` convention is not read at all.
