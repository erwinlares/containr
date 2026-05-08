# Check that the container tool daemon is responsive

Runs `<tool> info` and checks the exit code. Errors informatively if the
tool is found but not responsive – typically because the daemon is not
running.

## Usage

``` r
.check_tool_responsive(tool)
```

## Arguments

- tool:

  A character string, either `"podman"` or `"docker"`.

## Value

Called for its side effects. Returns `invisible(NULL)`.
