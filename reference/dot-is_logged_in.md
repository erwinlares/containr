# Check if the user appears to be logged in to a registry

Podman has a native way to answer this:
`podman login --get-login <registry>` exits 0 if a cached login exists
for that registry and non-zero otherwise. Docker has no equivalent flag
– `docker login --get-login` is not a real Docker CLI option, and
running it always exits with a usage error (typically 125) regardless of
whether the user is actually logged in. Using it for both tools (the
previous behavior) meant Docker users always failed this check, logged
in or not.

## Usage

``` r
.is_logged_in(tool, registry)
```

## Arguments

- tool:

  A character string naming the resolved container tool.

- registry:

  A character string naming the registry hostname.

## Value

Logical. `TRUE` if a cached login appears to exist, `FALSE` otherwise.

## Details

For Docker (and, permissively, any other tool – `tool_preference` isn't
validated against a fixed list, see
[`.resolve_tool()`](https://erwinlares.github.io/containr/reference/dot-resolve_tool.md)),
this instead inspects `~/.docker/config.json` directly for an `auths`
entry matching `registry`. Docker itself has no query subcommand for "am
I logged in to X", so reading its own config file is the standard way
tooling (including most CI actions) checks this. Note that
`docker login` adds a per-registry entry under `auths` even when a
credential helper (`credHelpers`) is configured for that registry, so
this check works correctly in that case too.

This is a best-effort local check, not a guarantee – it confirms a
cached credential *exists*, not that it's still *valid*. An expired
token still leaves an entry in the config file (or Podman's auth store),
so a check that passes here can still fail at push time with
`unauthorized: authentication required`. It also can't detect a login
set up entirely through a global `credsStore` (as opposed to a
per-registry `credHelpers` entry), since Docker defers to the external
credential store for those without writing anything to `auths` – a
narrow, acknowledged gap rather than a silent one.
