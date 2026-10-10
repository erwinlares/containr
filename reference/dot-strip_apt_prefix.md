# Strip the apt-get prefix remotes puts on every answer

Strip the apt-get prefix remotes puts on every answer

## Usage

``` r
.strip_apt_prefix(raw)
```

## Arguments

- raw:

  A character vector of `"apt-get install -y <pkg>"` strings.

## Value

A deduplicated character vector of bare package names.
