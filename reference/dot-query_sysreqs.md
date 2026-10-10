# Ask remotes for system requirements, in groups

Ask remotes for system requirements, in groups

## Usage

``` r
.query_sysreqs(packages, os_version, chunk_size = 50L)
```

## Arguments

- packages:

  Character vector of R package names.

- os_version:

  Character. An Ubuntu release `remotes` accepts.

- chunk_size:

  Positive integer. The most packages per request.

## Value

A character vector of `"apt-get install -y <pkg>"` strings, deduplicated
across requests.
