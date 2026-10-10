# Newest accepted release that is not newer than the requested one

A release newer than the request is never chosen: library names drift in
one direction, and a lookup against a future release would be guessing.

## Usage

``` r
.pick_fallback_release(requested, accepted)
```

## Arguments

- requested:

  Character. The Ubuntu release that was rejected.

- accepted:

  Character vector. The releases `remotes` accepts, from
  `.accepted_releases()`.

## Value

A single release, or `NULL` when none qualifies.
