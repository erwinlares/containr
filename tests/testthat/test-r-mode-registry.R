test_that(".r_mode_registry has exactly the four Phase 1 modes, in order", {
    expect_named(
        containr:::.r_mode_registry,
        c("base", "tidyverse", "rstudio", "verse")
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
})

test_that(".r_mode_registry ports are set only for rstudio", {
    reg <- containr:::.r_mode_registry

    expect_equal(reg$rstudio$ports, "8787")
    expect_null(reg$base$ports)
    expect_null(reg$tidyverse$ports)
    expect_null(reg$verse$ports)
})

test_that(".r_mode_registry has no extra_install steps for the four existing modes", {
    reg <- containr:::.r_mode_registry

    for (mode in names(reg)) {
        expect_null(reg[[mode]]$extra_install, info = paste("mode =", mode))
    }
})

test_that(".r_mode_registry copy_root is /home for all four existing modes", {
    reg <- containr:::.r_mode_registry

    for (mode in names(reg)) {
        expect_equal(reg[[mode]]$copy_root, "/home", info = paste("mode =", mode))
    }
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
