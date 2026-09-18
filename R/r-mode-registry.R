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
# doesn't exist). `ports` and `extra_install` aren't used by any of the four
# modes below; they exist now so Phase 2 (shiny_server, rstudio_shiny) only
# adds two new entries rather than restructuring this object's shape.
#
# `copy_root` (C24): `NULL` for base, tidyverse, rstudio, and verse, meaning
# "not applicable here -- fall back to whatever home_dir is," the same idiom
# already used for `ports`/`extra_install` on modes that don't need them.
# Those four modes copy data_file/code_file/misc_file to wherever WORKDIR
# points, since that's where a script actually runs and where its relative
# paths resolve, so there is nothing for copy_root to fix independently of
# home_dir. It used to be hardcoded to the literal "/home", which happened
# to agree with home_dir's own default and silently disagreed the moment
# home_dir was set to anything else -- COPY landed at /home while WORKDIR,
# and therefore the running script, sat at home_dir. shiny_server and
# rstudio_shiny keep an explicit, non-NULL copy_root, because Shiny Server's
# app directory is a fixed system location it looks for regardless of
# WORKDIR, not something that should ever track home_dir.
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
        copy_root     = NULL,
        min_r_version = NULL
    ),
    tidyverse = list(
        image         = "rocker/tidyverse",
        tag_repo      = "rocker/tidyverse",
        ports         = NULL,
        extra_install = NULL,
        copy_root     = NULL,
        min_r_version = NULL
    ),
    rstudio = list(
        image         = "rocker/rstudio",
        tag_repo      = "rocker/rstudio",
        ports         = "8787",
        extra_install = NULL,
        copy_root     = NULL,
        min_r_version = NULL
    ),
    verse = list(
        image         = "rocker/verse",
        tag_repo      = "rocker/verse",
        ports         = NULL,
        extra_install = NULL,
        copy_root     = NULL,
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


#' Resolve the Ubuntu version backing a given R version's Rocker image
#'
#' The Rocker Project ties each image's Ubuntu base OS to the R version's
#' release date, via what the project's own documentation describes as a
#' rule of building against the Ubuntu LTS current about 90 days after that
#' R release: Ubuntu 20.04 backs R 4.0.0-4.1.3, 22.04 backs R 4.2.2-4.3.3,
#' and 24.04 backs R 4.4.2 and later (confirmed directly against
#' rocker-project.org and the rocker-versioned2 wiki, 2026-09 -- not
#' assumed). Querying the sysreqs API (C14) against the wrong Ubuntu
#' release risks both false positives (an apt package name that does not
#' exist on the actual base image) and false negatives (a renamed or
#' Ubuntu-version-specific package the lookup misses), for any R version
#' outside whatever window a hardcoded default happens to match.
#'
#' @param x Character. A resolved `r_version`, in the same shapes
#'   `.extract_r_version_prefix()` accepts -- a bare major version, a
#'   CUDA/Ubuntu-suffixed tag, or the non-numeric `"latest"`/`"devel"`.
#'
#' @return A character string Ubuntu version, e.g. `"22.04"`.
#'
#' @keywords internal
.resolve_os_version <- function(x) {
    version_prefix <- .extract_r_version_prefix(x)

    # "latest" and "devel" always track the current rocker-versioned2
    # lineage, which is built against the newest Ubuntu release this
    # mapping knows about.
    if (is.na(version_prefix)) return("24.04")

    v <- package_version(version_prefix)

    if (v >= package_version("4.4.2")) {
        "24.04"
    } else if (v >= package_version("4.2.2")) {
        "22.04"
    } else {
        # Covers 4.0.0-4.1.3 exactly, and everything older as a floor:
        # min_r_version already guards shiny_server/rstudio_shiny at
        # R >= 4.0.0 for an unrelated reason (see this file's own header
        # comment), and no Rocker image below that predates
        # rocker-versioned2 with an Ubuntu release this mapping covers
        # confidently enough to guess further back than 20.04.
        "20.04"
    }
}
