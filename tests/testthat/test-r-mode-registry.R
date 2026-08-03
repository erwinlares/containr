test_that(".r_mode_registry has exactly the six modes, in order", {
    expect_named(
        containr:::.r_mode_registry,
        c("base", "tidyverse", "rstudio", "verse", "shiny_server", "rstudio_shiny")
    )
})

test_that(".r_mode_registry entries have the expected image and tag_repo", {
    reg <- containr:::.r_mode_registry

    expect_equal(reg$base$image,      "rocker/r-ver")
    expect_equal(reg$base$tag_repo,   "rocker/r-ver")

    expect_equal(reg$tidyverse$image,    "rocker/tidyverse")
    expect_equal(reg$tidyverse$tag_repo, "rocker/tidyverse")

    expect_equal(reg$rstudio$image,    "rocker/rstudio")
    expect_equal(reg$rstudio$tag_repo, "rocker/rstudio")

    expect_equal(reg$verse$image,    "rocker/verse")
    expect_equal(reg$verse$tag_repo, "rocker/verse")

    expect_equal(reg$shiny_server$image,    "rocker/shiny")
    expect_equal(reg$shiny_server$tag_repo, "rocker/shiny")

    # rstudio_shiny's tag_repo is deliberately "rocker/rstudio" -- there's
    # no separate rocker/rstudio_shiny image on Docker Hub, since the combo
    # is built by layering an install script onto rocker/rstudio.
    expect_equal(reg$rstudio_shiny$image,    "rocker/rstudio")
    expect_equal(reg$rstudio_shiny$tag_repo, "rocker/rstudio")
})

test_that(".r_mode_registry ports are set for rstudio, shiny_server, and rstudio_shiny only", {
    reg <- containr:::.r_mode_registry

    expect_equal(reg$rstudio$ports, "8787")
    expect_equal(reg$shiny_server$ports, "3838")
    expect_equal(reg$rstudio_shiny$ports, c("8787", "3838"))
    expect_null(reg$base$ports)
    expect_null(reg$tidyverse$ports)
    expect_null(reg$verse$ports)
})

test_that(".r_mode_registry has no extra_install steps except rstudio_shiny", {
    reg <- containr:::.r_mode_registry

    for (mode in setdiff(names(reg), "rstudio_shiny")) {
        expect_null(reg[[mode]]$extra_install, info = paste("mode =", mode))
    }

    expect_equal(reg$rstudio_shiny$extra_install, "install_shiny_server.sh")
})

test_that(".r_mode_registry copy_root is /home for the four Phase 1 modes, /srv/shiny-server for the two Phase 2 modes", {
    reg <- containr:::.r_mode_registry

    for (mode in c("base", "tidyverse", "rstudio", "verse")) {
        expect_equal(reg[[mode]]$copy_root, "/home", info = paste("mode =", mode))
    }

    for (mode in c("shiny_server", "rstudio_shiny")) {
        expect_equal(reg[[mode]]$copy_root, "/srv/shiny-server", info = paste("mode =", mode))
    }
})

test_that(".r_mode_registry min_r_version is set only for shiny_server and rstudio_shiny", {
    reg <- containr:::.r_mode_registry

    expect_equal(reg$shiny_server$min_r_version,  "4.0.0")
    expect_equal(reg$rstudio_shiny$min_r_version, "4.0.0")

    for (mode in c("base", "tidyverse", "rstudio", "verse")) {
        expect_null(reg[[mode]]$min_r_version, info = paste("mode =", mode))
    }
})

test_that(".extract_r_version_prefix() extracts and pads the leading numeric version", {
    expect_equal(containr:::.extract_r_version_prefix("4.4.0"), "4.4.0")
    expect_equal(containr:::.extract_r_version_prefix("4.4.0-cuda12.2-ubuntu22.04"), "4.4.0")
    expect_equal(containr:::.extract_r_version_prefix("4.4.0-ubuntu22.04"), "4.4.0")
    expect_equal(containr:::.extract_r_version_prefix("4"), "4.0.0")
    expect_equal(containr:::.extract_r_version_prefix("3.6.3"), "3.6.3")
    expect_true(is.na(containr:::.extract_r_version_prefix("latest")))
    expect_true(is.na(containr:::.extract_r_version_prefix("devel")))
})

test_that("tidystudio no longer resolves as a valid r_mode anywhere", {
    expect_false("tidystudio" %in% names(containr:::.r_mode_registry))

    expect_error(
        containr:::.r_ver_exists("4.3.0", r_mode = "tidystudio"),
        "not a valid"
    )
    expect_error(
        containr:::.get_r_ver_tags(r_mode = "tidystudio"),
        "not a valid"
    )
    # r_mode is validated before generate_dockerfile() touches the
    # filesystem, so this errors on the invalid mode without needing a
    # temp renv.lock.
    expect_error(
        generate_dockerfile(r_mode = "tidystudio"),
        "not a valid"
    )
})
