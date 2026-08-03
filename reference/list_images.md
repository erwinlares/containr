# List locally available container images

`list_images()` returns a data frame of container images currently
stored in the local image store, as reported by `podman image ls` or
`docker image ls`. This is useful for finding the image ID to pass to
[`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)
after building an image with
[`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md).

## Usage

``` r
list_images(tool_preference = c("podman", "docker"), verbose = FALSE)
```

## Arguments

- tool_preference:

  A non-empty character vector of container tools to try, in order.
  Defaults to `c("podman", "docker")` – Podman first, then Docker.
  Supply a single value (e.g. `"docker"`) to require that specific tool
  rather than auto-detecting.

- verbose:

  Logical. If `TRUE`, prints a progress message before querying the
  local image store. Defaults to `FALSE`.

## Value

A data frame with five columns: `repository`, `tag`, `image_id`,
`created`, and `size`. Rows where both `repository` and `tag` are
`<none>` correspond to untagged images produced by
[`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md)
when no `tag` argument was supplied. The data frame is also printed to
the console. Returns an empty data frame if no images are found.

## Finding your image ID

After calling
[`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md),
run `list_images()` to find the image ID of the image you just built.
Untagged images appear with `<none>` in the `repository` and `tag`
columns – the `image_id` column contains the hash you need to pass to
[`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md):

    imgs <- list_images()
    push_image(
      image_id  = imgs$image_id[1],
      namespace = "erwin.lares",
      project   = "container-registry"
    )

## Examples

``` r
if (FALSE) { # \dontrun{
# List all local images
list_images()

# Capture the result for programmatic use
imgs <- list_images()
imgs$image_id[1]
} # }
```
