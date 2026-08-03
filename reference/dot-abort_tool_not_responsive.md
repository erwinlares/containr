# Abort with troubleshooting guidance for an installed-but-unresponsive tool

Shared by
[`.resolve_tool()`](https://erwinlares.github.io/containr/reference/dot-resolve_tool.md)'s
explicit-tool path and
[`.check_tool_responsive()`](https://erwinlares.github.io/containr/reference/dot-check_tool_responsive.md).
Docker and Podman get their own specific, known-good troubleshooting
steps; any other tool name gets generic guidance instead of being forced
through instructions that would be wrong for it (e.g.
`systemctl start docker` for a tool that isn't Docker).

## Usage

``` r
.abort_tool_not_responsive(tool)
```

## Arguments

- tool:

  A character string naming the tool that is installed but not
  responding.

## Value

Called for its side effect of aborting. Never returns.
