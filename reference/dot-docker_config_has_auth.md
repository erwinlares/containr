# Check ~/.docker/config.json for a cached auth entry for a registry

Check ~/.docker/config.json for a cached auth entry for a registry

## Usage

``` r
.docker_config_has_auth(
  registry,
  config_path = path.expand("~/.docker/config.json")
)
```

## Arguments

- registry:

  A character string naming the registry hostname.

- config_path:

  A character string. Path to the Docker config file. Defaults to
  `~/.docker/config.json`, the real location – parameterized so tests
  can point this at a temp file with real content instead of mocking
  [`jsonlite::fromJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html)
  across a package boundary.

## Value

Logical. `TRUE` if `registry` appears as a key under `auths` in the
Docker config file, `FALSE` if the file is missing, unreadable,
malformed, or simply has no entry for `registry`.
