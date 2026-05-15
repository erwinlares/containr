# tests/testthat/test-container-workflow.R
#
# Testing strategy for functions that call system commands
# =========================================================
#
# Functions that wrap podman/docker cannot be tested end-to-end in a standard
# test suite -- they require a running daemon, real images, and in the case of
# push_image(), a live registry with valid credentials. These are not
# conditions that hold reliably on CI or in a CRAN check environment.
#
# Tests are organized into three layers:
#
# Layer 1 -- Argument validation
#   Pure R checks that run anywhere without system dependencies.
#   Tests that bad arguments error correctly and required arguments are
#   enforced. These always run.
#
# Layer 2 -- Command construction
#   Tests that the correct system command is assembled from the supplied
#   arguments, using dry_run = TRUE and local_mocked_bindings() to intercept
#   .resolve_tool() and .check_tool_responsive() without calling the real
#   tool. These always run.
#
# Layer 3 -- Integration
#   Tests that call real system commands. Guarded with skip_if_not() so they
#   only run when podman is available on the PATH. Never run on CRAN or CI.

# ---------------------------------------------------------------------------
# build_image() -- Layer 1: argument validation
# ---------------------------------------------------------------------------

test_that("build_image() errors when dockerfile does not exist", {
    expect_error(
        build_image(dockerfile = "nonexistent/Dockerfile"),
        regexp = "not found"
    )
})

test_that("build_image() errors when tool is invalid", {
    tmp <- withr::local_tempdir()
    writeLines("FROM rocker/r-ver:4.4.0", file.path(tmp, "Dockerfile"))
    withr::local_dir(tmp)
    expect_error(
        build_image(tool = "singularity"),
        regexp = "podman|docker"
    )
})

test_that("build_image() errors when platform is invalid", {
    tmp <- withr::local_tempdir()
    writeLines("FROM rocker/r-ver:4.4.0", file.path(tmp, "Dockerfile"))
    withr::local_dir(tmp)
    local_mocked_bindings(
        `.resolve_tool`          = function(...) "podman",
        `.check_tool_responsive` = function(...) invisible(NULL),
        .package = "containr"
    )
    expect_error(
        build_image(platform = "linux/mips64"),
        regexp = "not a supported"
    )
})

test_that("build_image() accepts NULL platform without error", {
    tmp <- withr::local_tempdir()
    writeLines("FROM rocker/r-ver:4.4.0", file.path(tmp, "Dockerfile"))
    withr::local_dir(tmp)
    local_mocked_bindings(
        `.resolve_tool`          = function(...) "podman",
        `.check_tool_responsive` = function(...) invisible(NULL),
        .package = "containr"
    )
    expect_no_error(
        build_image(platform = NULL, dry_run = TRUE)
    )
})

test_that("build_image() returns invisible NULL", {
    tmp <- withr::local_tempdir()
    writeLines("FROM rocker/r-ver:4.4.0", file.path(tmp, "Dockerfile"))
    withr::local_dir(tmp)
    local_mocked_bindings(
        `.resolve_tool`          = function(...) "podman",
        `.check_tool_responsive` = function(...) invisible(NULL),
        .package = "containr"
    )
    result <- suppressWarnings(build_image(dry_run = TRUE))
    expect_null(result)
})

# ---------------------------------------------------------------------------
# build_image() -- Layer 2: command construction
# ---------------------------------------------------------------------------

test_that("build_image() dry_run produces podman build command", {
    tmp <- withr::local_tempdir()
    writeLines("FROM rocker/r-ver:4.4.0", file.path(tmp, "Dockerfile"))
    withr::local_dir(tmp)
    local_mocked_bindings(
        `.resolve_tool`          = function(...) "podman",
        `.check_tool_responsive` = function(...) invisible(NULL),
        .package = "containr"
    )
    expect_message(
        suppressWarnings(build_image(dry_run = TRUE)),
        regexp = "podman build"
    )
})

test_that("build_image() dry_run includes -f Dockerfile", {
    tmp <- withr::local_tempdir()
    writeLines("FROM rocker/r-ver:4.4.0", file.path(tmp, "Dockerfile"))
    withr::local_dir(tmp)
    local_mocked_bindings(
        `.resolve_tool`          = function(...) "podman",
        `.check_tool_responsive` = function(...) invisible(NULL),
        .package = "containr"
    )
    expect_message(
        suppressWarnings(build_image(dry_run = TRUE)),
        regexp = "-f Dockerfile"
    )
})

test_that("build_image() dry_run includes -t when tag is supplied", {
    tmp <- withr::local_tempdir()
    writeLines("FROM rocker/r-ver:4.4.0", file.path(tmp, "Dockerfile"))
    withr::local_dir(tmp)
    local_mocked_bindings(
        `.resolve_tool`          = function(...) "podman",
        `.check_tool_responsive` = function(...) invisible(NULL),
        .package = "containr"
    )
    expect_message(
        suppressWarnings(build_image(tag = "my-analysis", dry_run = TRUE)),
        regexp = "-t my-analysis"
    )
})

test_that("build_image() dry_run omits -t when tag is NULL", {
    tmp <- withr::local_tempdir()
    writeLines("FROM rocker/r-ver:4.4.0", file.path(tmp, "Dockerfile"))
    withr::local_dir(tmp)
    local_mocked_bindings(
        `.resolve_tool`          = function(...) "podman",
        `.check_tool_responsive` = function(...) invisible(NULL),
        .package = "containr"
    )
    msg <- capture.output(
        suppressWarnings(build_image(tag = NULL, dry_run = TRUE, verbose = TRUE)),
        type = "message"
    )
    expect_false(any(grepl("-t", msg, fixed = TRUE)))
})

test_that("build_image() dry_run includes --platform when platform is set", {
    tmp <- withr::local_tempdir()
    writeLines("FROM rocker/r-ver:4.4.0", file.path(tmp, "Dockerfile"))
    withr::local_dir(tmp)
    local_mocked_bindings(
        `.resolve_tool`          = function(...) "podman",
        `.check_tool_responsive` = function(...) invisible(NULL),
        .package = "containr"
    )
    expect_message(
        suppressWarnings(build_image(platform = "linux/amd64", dry_run = TRUE)),
        regexp = "--platform linux/amd64"
    )
})

test_that("build_image() dry_run omits --platform when platform is NULL", {
    tmp <- withr::local_tempdir()
    writeLines("FROM rocker/r-ver:4.4.0", file.path(tmp, "Dockerfile"))
    withr::local_dir(tmp)
    local_mocked_bindings(
        `.resolve_tool`          = function(...) "podman",
        `.check_tool_responsive` = function(...) invisible(NULL),
        .package = "containr"
    )
    msg <- capture.output(
        build_image(platform = NULL, dry_run = TRUE, verbose = TRUE),
        type = "message"
    )
    expect_false(any(grepl("--platform", msg, fixed = TRUE)))
})

test_that("build_image() uses podman build with --platform for podman", {
    tmp <- withr::local_tempdir()
    writeLines("FROM rocker/r-ver:4.4.0", file.path(tmp, "Dockerfile"))
    withr::local_dir(tmp)
    local_mocked_bindings(
        `.resolve_tool`          = function(...) "podman",
        `.check_tool_responsive` = function(...) invisible(NULL),
        .package = "containr"
    )
    expect_message(
        suppressWarnings(build_image(platform = "linux/amd64", dry_run = TRUE)),
        regexp = "podman build --platform linux/amd64"
    )
})

test_that("build_image() uses docker build for same-arch docker builds", {
    tmp <- withr::local_tempdir()
    writeLines("FROM rocker/r-ver:4.4.0", file.path(tmp, "Dockerfile"))
    withr::local_dir(tmp)
    local_mocked_bindings(
        `.resolve_tool`          = function(...) "docker",
        `.check_tool_responsive` = function(...) invisible(NULL),
        .package = "containr"
    )
    # Build for the host architecture -- no cross-compilation
    host_arch <- Sys.info()[["machine"]]
    host_platform <- switch(host_arch,
                            "x86_64"  = "linux/amd64",
                            "aarch64" = "linux/arm64",
                            "arm64"   = "linux/arm64",
                            "linux/amd64"
    )
    msg <- capture.output(
        build_image(platform = host_platform, dry_run = TRUE, verbose = TRUE),
        type = "message"
    )
    # Should use plain "docker build", not "docker buildx build"
    expect_true(any(grepl("docker build", msg, fixed = TRUE)))
    expect_false(any(grepl("docker buildx", msg, fixed = TRUE)))
})

test_that("build_image() uses docker buildx build for cross-arch docker builds", {
    tmp <- withr::local_tempdir()
    writeLines("FROM rocker/r-ver:4.4.0", file.path(tmp, "Dockerfile"))
    withr::local_dir(tmp)
    local_mocked_bindings(
        `.resolve_tool`          = function(...) "docker",
        `.check_tool_responsive` = function(...) invisible(NULL),
        .package = "containr"
    )
    # Pick a platform that differs from the host
    host_arch <- Sys.info()[["machine"]]
    cross_platform <- if (host_arch %in% c("aarch64", "arm64")) {
        "linux/amd64"
    } else {
        "linux/arm64"
    }
    msg <- capture.output(
        suppressWarnings(
            build_image(platform = cross_platform, dry_run = TRUE, verbose = TRUE)
        ),
        type = "message"
    )
    expect_true(any(grepl("docker buildx build", msg, fixed = TRUE)))
})

test_that("build_image() includes --load for docker buildx cross-arch builds", {
    tmp <- withr::local_tempdir()
    writeLines("FROM rocker/r-ver:4.4.0", file.path(tmp, "Dockerfile"))
    withr::local_dir(tmp)
    local_mocked_bindings(
        `.resolve_tool`          = function(...) "docker",
        `.check_tool_responsive` = function(...) invisible(NULL),
        .package = "containr"
    )
    host_arch <- Sys.info()[["machine"]]
    cross_platform <- if (host_arch %in% c("aarch64", "arm64")) {
        "linux/amd64"
    } else {
        "linux/arm64"
    }
    msg <- capture.output(
        suppressWarnings(
            build_image(platform = cross_platform, dry_run = TRUE, verbose = TRUE)
        ),
        type = "message"
    )
    expect_true(any(grepl("--load", msg, fixed = TRUE)))
})

test_that("build_image() warns when cross-compiling", {
    tmp <- withr::local_tempdir()
    writeLines("FROM rocker/r-ver:4.4.0", file.path(tmp, "Dockerfile"))
    withr::local_dir(tmp)
    local_mocked_bindings(
        `.resolve_tool`          = function(...) "podman",
        `.check_tool_responsive` = function(...) invisible(NULL),
        .package = "containr"
    )
    host_arch <- Sys.info()[["machine"]]
    cross_platform <- if (host_arch %in% c("aarch64", "arm64")) {
        "linux/amd64"
    } else {
        "linux/arm64"
    }
    expect_warning(
        build_image(platform = cross_platform, dry_run = TRUE),
        regexp = "emulation"
    )
})

test_that("build_image() does not warn when building for host architecture", {
    tmp <- withr::local_tempdir()
    writeLines("FROM rocker/r-ver:4.4.0", file.path(tmp, "Dockerfile"))
    withr::local_dir(tmp)
    local_mocked_bindings(
        `.resolve_tool`          = function(...) "podman",
        `.check_tool_responsive` = function(...) invisible(NULL),
        .package = "containr"
    )
    host_arch <- Sys.info()[["machine"]]
    host_platform <- switch(host_arch,
                            "x86_64"  = "linux/amd64",
                            "aarch64" = "linux/arm64",
                            "arm64"   = "linux/arm64",
                            "linux/amd64"
    )
    expect_no_warning(
        build_image(platform = host_platform, dry_run = TRUE)
    )
})

# ---------------------------------------------------------------------------
# push_image() -- Layer 1: argument validation
# ---------------------------------------------------------------------------

test_that("push_image() errors when image_id is NULL", {
    expect_error(
        push_image(netid = "erwin.lares", project = "container-registry"),
        regexp = "image_id"
    )
})

test_that("push_image() errors when netid is NULL", {
    expect_error(
        push_image(image_id = "abc123", project = "container-registry"),
        regexp = "netid"
    )
})

test_that("push_image() errors when project is NULL", {
    expect_error(
        push_image(image_id = "abc123", netid = "erwin.lares"),
        regexp = "project"
    )
})

test_that("push_image() warns when tag is 'latest'", {
    local_mocked_bindings(
        `.resolve_tool`          = function(...) "podman",
        `.check_tool_responsive` = function(...) invisible(NULL),
        .package = "containr"
    )
    expect_message(
        push_image(
            image_id    = "abc123",
            netid       = "erwin.lares",
            project     = "container-registry",
            check_login = FALSE,
            dry_run     = TRUE
        ),
        regexp = "latest"
    )
})

test_that("push_image() returns invisible NULL on dry_run", {
    local_mocked_bindings(
        `.resolve_tool`          = function(...) "podman",
        `.check_tool_responsive` = function(...) invisible(NULL),
        .package = "containr"
    )
    result <- suppressMessages(push_image(
        image_id    = "abc123",
        netid       = "erwin.lares",
        project     = "container-registry",
        check_login = FALSE,
        dry_run     = TRUE
    ))
    expect_null(result)
})

# ---------------------------------------------------------------------------
# push_image() -- Layer 2: command construction
# ---------------------------------------------------------------------------

test_that("push_image() dry_run produces podman tag command", {
    local_mocked_bindings(
        `.resolve_tool`          = function(...) "podman",
        `.check_tool_responsive` = function(...) invisible(NULL),
        .package = "containr"
    )
    msgs <- capture.output(
        push_image(
            image_id    = "974123909a36",
            netid       = "erwin.lares",
            project     = "container-registry",
            tag         = "1.0.0",
            check_login = FALSE,
            dry_run     = TRUE
        ),
        type = "message"
    )
    expect_true(any(grepl("podman tag", msgs, fixed = TRUE)))
})

test_that("push_image() dry_run produces podman push command", {
    local_mocked_bindings(
        `.resolve_tool`          = function(...) "podman",
        `.check_tool_responsive` = function(...) invisible(NULL),
        .package = "containr"
    )
    msgs <- capture.output(
        push_image(
            image_id    = "974123909a36",
            netid       = "erwin.lares",
            project     = "container-registry",
            tag         = "1.0.0",
            check_login = FALSE,
            dry_run     = TRUE
        ),
        type = "message"
    )
    expect_true(any(grepl("podman push", msgs, fixed = TRUE)))
})

test_that("push_image() assembles correct destination tag", {
    local_mocked_bindings(
        `.resolve_tool`          = function(...) "podman",
        `.check_tool_responsive` = function(...) invisible(NULL),
        .package = "containr"
    )
    msgs <- capture.output(
        push_image(
            image_id    = "974123909a36",
            netid       = "erwin.lares",
            project     = "container-registry",
            tag         = "1.0.0",
            check_login = FALSE,
            dry_run     = TRUE,
            verbose     = TRUE
        ),
        type = "message"
    )
    expect_true(any(grepl(
        "registry.doit.wisc.edu/erwin.lares/container-registry:1.0.0",
        msgs, fixed = TRUE
    )))
})

# ---------------------------------------------------------------------------
# list_images() -- Layer 1: argument validation
# ---------------------------------------------------------------------------

test_that("list_images() errors when tool is invalid", {
    expect_error(
        list_images(tool = "singularity"),
        regexp = "podman|docker"
    )
})

# ---------------------------------------------------------------------------
# list_images() -- Layer 3: integration (skip unless podman available)
# ---------------------------------------------------------------------------

test_that("list_images() returns a data frame with correct columns", {
    skip_if(
        nchar(Sys.getenv("CONTAINR_INTEGRATION_TESTS")) == 0,
        "Set CONTAINR_INTEGRATION_TESTS=true to run integration tests"
    )
    skip_if_not(
        nchar(Sys.which("podman")) > 0,
        "podman not available on this system"
    )
    result <- list_images()
    expect_s3_class(result, "data.frame")
    expect_named(result, c("repository", "tag", "image_id", "created", "size"))
})

test_that("list_images() returns all character columns", {
    skip_if(
        nchar(Sys.getenv("CONTAINR_INTEGRATION_TESTS")) == 0,
        "Set CONTAINR_INTEGRATION_TESTS=true to run integration tests"
    )
    skip_if_not(
        nchar(Sys.which("podman")) > 0,
        "podman not available on this system"
    )
    result <- list_images()
    expect_true(all(vapply(result, is.character, logical(1))))
})

test_that("list_images() returns a data frame even when no images exist", {
    skip_if(
        nchar(Sys.getenv("CONTAINR_INTEGRATION_TESTS")) == 0,
        "Set CONTAINR_INTEGRATION_TESTS=true to run integration tests"
    )
    skip_if_not(
        nchar(Sys.which("podman")) > 0,
        "podman not available on this system"
    )
    local_mocked_bindings(
        `.resolve_tool`          = function(...) "podman",
        `.check_tool_responsive` = function(...) invisible(NULL),
        .package = "containr"
    )
    # Mock system2 to return empty output
    local_mocked_bindings(
        `system2` = function(...) character(0),
        .package = "base"
    )
    result <- list_images()
    expect_s3_class(result, "data.frame")
    expect_equal(nrow(result), 0L)
    expect_named(result, c("repository", "tag", "image_id", "created", "size"))
})
