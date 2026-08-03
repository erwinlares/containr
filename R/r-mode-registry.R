# Single source of truth for valid r_mode values.
#
# Before this file existed, r_mode knowledge was tripled: `image_map` in
# generate-dockerfile.R (r_mode -> full Docker image name), `mode_map` in
# get-r-ver-tags.R (r_mode -> image-name suffix only), and `valid_modes` in
# r-ver-exists.R (a plain allow-list, implicitly assumed to agree with the
# other two). The three disagreed on ordering with each other and had no
# shared way to add a new field (ports, an extra install step, a COPY
# destination) without editing all three by hand.
#
# `.r_mode_registry` replaces all three. `names(.r_mode_registry)` is the
# valid-values list everywhere it's needed; `image` is the `FROM` target in
# the generated Dockerfile; `tag_repo` is the Docker Hub repository queried
# for version-tag checking (identical to `image` for every mode so far, but
# kept as its own field because that won't stay true once a mode is built by
# layering an install step onto another mode's base image -- rstudio_shiny,
# for example, uses rocker/rstudio's tags, not a rocker/rstudio_shiny that
# doesn't exist). `ports`, `extra_install`, and `copy_root` aren't used by
# any of the four modes below; they exist now so Phase 2 (shiny_server,
# rstudio_shiny) only adds two new entries rather than restructuring this
# object's shape.
#
# Order is deliberate and is the single source of truth for how each
# consuming function's "valid choices are ..." error message lists them:
# base, tidyverse, rstudio, verse (Phase 1), then shiny_server,
# rstudio_shiny (Phase 2).
#
# shiny_server's tag_repo matches its image ("rocker/shiny") since it's a
# standalone Rocker image. rstudio_shiny's tag_repo is deliberately
# "rocker/rstudio", not a "rocker/rstudio_shiny" that doesn't exist -- the
# combo is built by layering Shiny Server onto rocker/rstudio via
# extra_install, not a separate Docker Hub repository.
#
# min_r_version guards modes that depend on /rocker_scripts/, which only
# exists in images built from the rocker-versioned2 repository (R >= 4.0.0).
# Older tags on the same Docker Hub repos (R <= 3.6.3) are carried over from
# the predecessor rocker-versioned repo and predate rocker_scripts entirely
# -- confirmed directly against rocker-versioned2's own README, not
# assumed. NULL for modes with no such dependency.
.r_mode_registry <- list(
    base = list(
        image         = "rocker/r-ver",
        tag_repo      = "rocker/r-ver",
        ports         = NULL,
        extra_install = NULL,
        copy_root     = "/home",
        min_r_version = NULL
    ),
    tidyverse = list(
        image         = "rocker/tidyverse",
        tag_repo      = "rocker/tidyverse",
        ports         = NULL,
        extra_install = NULL,
        copy_root     = "/home",
        min_r_version = NULL
    ),
    rstudio = list(
        image         = "rocker/rstudio",
        tag_repo      = "rocker/rstudio",
        ports         = "8787",
        extra_install = NULL,
        copy_root     = "/home",
        min_r_version = NULL
    ),
    verse = list(
        image         = "rocker/verse",
        tag_repo      = "rocker/verse",
        ports         = NULL,
        extra_install = NULL,
        copy_root     = "/home",
        min_r_version = NULL
    ),
    shiny_server = list(
        image         = "rocker/shiny",
        tag_repo      = "rocker/shiny",
        ports         = "3838",
        extra_install = NULL,
        copy_root     = "/srv/shiny-server",
        min_r_version = "4.0.0"
    ),
    rstudio_shiny = list(
        image         = "rocker/rstudio",
        tag_repo      = "rocker/rstudio",
        ports         = c("8787", "3838"),
        extra_install = "install_shiny_server.sh",
        copy_root     = "/srv/shiny-server",
        min_r_version = "4.0.0"
    )
)

#' Extract and pad the leading numeric R version from a version string
#'
#' Pulls the leading `X`, `X.Y`, or `X.Y.Z` numeric prefix from a resolved
#' `r_version` string and pads it to three components, so it can be safely
#' compared with `package_version()`. Handles the shapes `resolved_version`
#' can take: a bare major version (`"4"`), CUDA/Ubuntu suffixes
#' (`"4.4.0-cuda12.2-ubuntu22.04"`), and the non-numeric tags `"latest"` and
#' `"devel"`, for which it returns `NA_character_` -- both always resolve to
#' the current rocker-versioned2 image lineage, so callers should treat `NA`
#' here as "no floor applies."
#'
#' @param x Character string. A resolved R version, as produced by
#'   `generate_dockerfile()`'s `r_version`/`"current"` resolution step.
#'
#' @return A three-component version string (e.g. `"4.4.0"`), or
#'   `NA_character_` if `x` has no leading numeric portion.
#'
#' @keywords internal
.extract_r_version_prefix <- function(x) {
    m <- regmatches(x, regexpr("^[0-9]+(\\.[0-9]+){0,2}", x))

    if (length(m) == 0 || nchar(m) == 0) {
        return(NA_character_)
    }

    parts <- strsplit(m, ".", fixed = TRUE)[[1]]
    parts <- c(parts, rep("0", 3))[1:3]
    paste(parts, collapse = ".")
}
