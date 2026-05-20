# Resolve which container tool to use

When `tool` is specified explicitly, validates that it is installed and
responsive. When `tool = NULL`, tries each candidate in preference order
(Podman first, then Docker), selecting the first one that is both
installed and responsive. Errors informatively if no tool is available.

## Usage

``` r
.resolve_tool(tool = NULL)
```

## Arguments

- tool:

  A character string (`"podman"` or `"docker"`) or `NULL`.

## Value

A character string, either `"podman"` or `"docker"`.
