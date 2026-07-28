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
.r_mode_registry <- list(
    base = list(
        image         = "rocker/r-ver",
        tag_repo      = "rocker/r-ver",
        ports         = NULL,
        extra_install = NULL,
        copy_root     = "/home"
    ),
    tidyverse = list(
        image         = "rocker/tidyverse",
        tag_repo      = "rocker/tidyverse",
        ports         = NULL,
        extra_install = NULL,
        copy_root     = "/home"
    ),
    rstudio = list(
        image         = "rocker/rstudio",
        tag_repo      = "rocker/rstudio",
        ports         = "8787",
        extra_install = NULL,
        copy_root     = "/home"
    ),
    verse = list(
        image         = "rocker/verse",
        tag_repo      = "rocker/verse",
        ports         = NULL,
        extra_install = NULL,
        copy_root     = "/home"
    )
)
