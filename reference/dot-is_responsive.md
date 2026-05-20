# Check if a container tool's daemon is responsive (quiet)

Runs `<tool> info` and returns `TRUE` if the exit code is 0, `FALSE`
otherwise. Does not error – used by
[`.resolve_tool()`](https://erwinlares.github.io/containr/reference/dot-resolve_tool.md)
during auto-detection to silently try each tool in preference order.

## Usage

``` r
.is_responsive(tool)
```

## Arguments

- tool:

  A character string, either `"podman"` or `"docker"`.

## Value

Logical. `TRUE` if the tool responded, `FALSE` otherwise.
