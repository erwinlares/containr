# Resolve which container tool to use

Checks the PATH for `podman` and `docker`. When `tool = NULL`, prefers
`podman` if both are found. Errors informatively if neither is found.

## Usage

``` r
.resolve_tool(tool = NULL)
```

## Arguments

- tool:

  A character string (`"podman"` or `"docker"`) or `NULL`.

## Value

A character string, either `"podman"` or `"docker"`.
