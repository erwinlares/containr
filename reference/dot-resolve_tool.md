# Resolve which container tool to use

Tries each candidate in `tool_preference`, in order, selecting the first
one that is both installed and responsive. A length-1 `tool_preference`
is treated as an explicit, non-negotiable choice – that single tool is
validated (checked for installation and responsiveness) rather than
treated as a preference order with nothing left to fall back to if it
fails. Errors informatively if no candidate is available.

## Usage

``` r
.resolve_tool(tool_preference = c("podman", "docker"))
```

## Arguments

- tool_preference:

  A non-empty character vector of tool names, tried in order. A single
  value is treated as an explicit choice rather than an order with a
  fallback. Defaults to `c("podman", "docker")`.

## Value

A character string naming the resolved tool.

## Details

`tool_preference` is not validated against a fixed list of known tool
names – anything on the system's PATH that responds to `<tool> info`
with exit code 0 is accepted. This keeps `.resolve_tool()`
forward-compatible with tools this package doesn't yet have dedicated
support for (e.g. Singularity/Apptainer, planned for a later phase)
without a matching validation change here. What is validated is the
*shape* of `tool_preference` itself – it must be a non-empty character
vector with no missing values.
