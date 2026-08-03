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
#   .resolve_tool() without calling the real tool. These always run.
#   (.resolve_tool() itself already checks installation and responsiveness,
#   so build_image()/push_image()/list_images() no longer call
#   .check_tool_responsive() separately -- see the .resolve_tool() section
#   below for tests of that logic directly.)
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

test_that("build_image() errors when tool_preference names a tool that isn't installed", {
    tmp <- withr::local_tempdir()
    writeLines("FROM rocker/r-ver:4.4.0", file.path(tmp, "Dockerfile"))
    withr::local_dir(tmp)
    local_mocked_bindings(
        `.sys_which` = function(x) setNames("", x),
        .package = "containr"
    )
    expect_error(
        build_image(tool_preference = "singularity"),
        regexp = "not installed"
    )
})

test_that("build_image() errors when platform is invalid", {
    tmp <- withr::local_tempdir()
    writeLines("FROM rocker/r-ver:4.4.0", file.path(tmp, "Dockerfile"))
    withr::local_dir(tmp)
    local_mocked_bindings(
        `.resolve_tool` = function(...) "podman",
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
        `.resolve_tool` = function(...) "podman",
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
        `.resolve_tool` = function(...) "podman",
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
        `.resolve_tool` = function(...) "podman",
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
        `.resolve_tool` = function(...) "podman",
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
        `.resolve_tool` = function(...) "podman",
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
        `.resolve_tool` = function(...) "podman",
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
        `.resolve_tool` = function(...) "podman",
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
        `.resolve_tool` = function(...) "podman",
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
        `.resolve_tool` = function(...) "podman",
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
        `.resolve_tool` = function(...) "docker",
        .package = "containr"
    )
    # Build for the host architecture -- no cross-compilation
    host_arch <- Sys.info()[["machine"]]
    host_platform <- switch(host_arch,
                            "x86_64"  = "linux/amd64",
                            "x86-64"  = "linux/amd64",
                            "aarch64" = "linux/arm64",
                            "arm64"   = "linux/arm64",
                            NULL
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
        `.resolve_tool` = function(...) "docker",
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
        `.resolve_tool` = function(...) "docker",
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
        `.resolve_tool` = function(...) "podman",
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
        `.resolve_tool` = function(...) "podman",
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
# build_image() -- Layer 3: integration (skip unless podman available)
# ---------------------------------------------------------------------------
#
# Builds a real, tiny image (alpine, not an R image -- these tests exercise
# build_image()'s own mechanics, not the R install path already covered by
# generate_dockerfile()'s tests) and cleans it up afterward via on.exit(),
# same as the local podman/docker store is left the way these tests found
# it. Tagged with a random suffix so repeated local runs never collide with
# a leftover image from a prior run.

test_that("build_image() successfully builds a real image", {
    skip_if(
        nchar(Sys.getenv("CONTAINR_INTEGRATION_TESTS")) == 0,
        "Set CONTAINR_INTEGRATION_TESTS=true to run integration tests"
    )
    skip_if_not(
        nchar(.sys_which("podman")) > 0,
        "podman not available on this system"
    )

    tmp <- withr::local_tempdir()
    writeLines(c("FROM alpine:latest", "CMD [\"true\"]"), file.path(tmp, "Dockerfile"))
    withr::local_dir(tmp)

    test_tag <- paste0("containr-test-build-image:", as.integer(Sys.time()))
    on.exit(system2("podman", args = c("rmi", "-f", test_tag), stdout = FALSE, stderr = FALSE), add = TRUE)

    expect_no_error(
        build_image(tag = test_tag, platform = NULL)
    )

    inspect_exit <- system2("podman", args = c("image", "inspect", test_tag), stdout = FALSE, stderr = FALSE)
    expect_equal(inspect_exit, 0L)
})

test_that("build_image()'s output is visible to list_images()", {
    skip_if(
        nchar(Sys.getenv("CONTAINR_INTEGRATION_TESTS")) == 0,
        "Set CONTAINR_INTEGRATION_TESTS=true to run integration tests"
    )
    skip_if_not(
        nchar(.sys_which("podman")) > 0,
        "podman not available on this system"
    )

    tmp <- withr::local_tempdir()
    writeLines(c("FROM alpine:latest", "CMD [\"true\"]"), file.path(tmp, "Dockerfile"))
    withr::local_dir(tmp)

    test_tag <- paste0("containr-test-list-images:", as.integer(Sys.time()))
    on.exit(system2("podman", args = c("rmi", "-f", test_tag), stdout = FALSE, stderr = FALSE), add = TRUE)

    build_image(tag = test_tag, platform = NULL)

    images <- list_images()
    expect_true(any(grepl(sub(":.*$", "", test_tag), images$repository, fixed = TRUE)))
})

# ---------------------------------------------------------------------------
# push_image() -- Layer 1: argument validation
# ---------------------------------------------------------------------------

test_that("push_image() errors when image_id is NULL", {
    expect_error(
        push_image(namespace = "erwin.lares", project = "container-registry"),
        regexp = "image_id"
    )
})

test_that("push_image() errors when namespace is NULL", {
    expect_error(
        push_image(image_id = "abc123", project = "container-registry"),
        regexp = "namespace"
    )
})

test_that("push_image() errors when project is NULL", {
    expect_error(
        push_image(image_id = "abc123", namespace = "erwin.lares"),
        regexp = "project"
    )
})

test_that("push_image() warns when tag is 'latest'", {
    local_mocked_bindings(
        `.resolve_tool` = function(...) "podman",
        .package = "containr"
    )
    expect_message(
        push_image(
            image_id    = "abc123",
            namespace   = "erwin.lares",
            project     = "container-registry",
            check_login = FALSE,
            dry_run     = TRUE
        ),
        regexp = "latest"
    )
})

test_that("push_image() returns invisible NULL on dry_run", {
    local_mocked_bindings(
        `.resolve_tool` = function(...) "podman",
        .package = "containr"
    )
    result <- suppressMessages(push_image(
        image_id    = "abc123",
        namespace   = "erwin.lares",
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
        `.resolve_tool` = function(...) "podman",
        .package = "containr"
    )
    msgs <- capture.output(
        push_image(
            image_id    = "974123909a36",
            namespace   = "erwin.lares",
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
        `.resolve_tool` = function(...) "podman",
        .package = "containr"
    )
    msgs <- capture.output(
        push_image(
            image_id    = "974123909a36",
            namespace   = "erwin.lares",
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
        `.resolve_tool` = function(...) "podman",
        .package = "containr"
    )
    msgs <- capture.output(
        push_image(
            image_id    = "974123909a36",
            namespace   = "erwin.lares",
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
# push_image() -- login check (check_login = TRUE)
# ---------------------------------------------------------------------------
#
# No existing test exercised check_login = TRUE at all before this section
# -- every prior push_image() test used check_login = FALSE to bypass the
# login check entirely, which meant the --get-login bug fix itself had no
# coverage. These mock .is_logged_in() directly rather than system2(),
# since .is_logged_in() is now the seam push_image() actually calls.

test_that("push_image() succeeds when .is_logged_in() returns TRUE", {
    local_mocked_bindings(
        `.resolve_tool` = function(...) "podman",
        `.is_logged_in` = function(...) TRUE,
        .package = "containr"
    )
    expect_no_error(
        push_image(
            image_id  = "abc123",
            namespace = "erwin.lares",
            project   = "container-registry",
            dry_run   = TRUE
        )
    )
})

test_that("push_image() errors with DoIT-specific guidance when not logged in to the default registry", {
    local_mocked_bindings(
        `.resolve_tool` = function(...) "podman",
        `.is_logged_in` = function(...) FALSE,
        .package = "containr"
    )
    err <- tryCatch(
        push_image(
            image_id  = "abc123",
            namespace = "erwin.lares",
            project   = "container-registry"
        ),
        error = function(e) conditionMessage(e)
    )
    expect_match(err, "Not logged in")
    expect_match(err, "git.doit.wisc.edu", fixed = TRUE)
})

test_that("push_image() errors with generic guidance when not logged in to a non-default registry", {
    local_mocked_bindings(
        `.resolve_tool` = function(...) "docker",
        `.is_logged_in` = function(...) FALSE,
        .package = "containr"
    )
    err <- tryCatch(
        push_image(
            image_id  = "abc123",
            namespace = "octocat",
            project   = "my-analysis",
            registry  = "ghcr.io"
        ),
        error = function(e) conditionMessage(e)
    )
    expect_match(err, "Not logged in")
    expect_match(err, "ghcr.io")
    expect_match(err, "own documentation")
})

test_that("push_image() skips the login check entirely when check_login = FALSE", {
    local_mocked_bindings(
        `.resolve_tool` = function(...) "podman",
        .package = "containr"
    )
    # .is_logged_in() is deliberately NOT mocked here -- if push_image()
    # called it despite check_login = FALSE, this test would fail with a
    # real (and environment-dependent) system2() call instead of passing.
    expect_no_error(
        push_image(
            image_id    = "abc123",
            namespace   = "erwin.lares",
            project     = "container-registry",
            check_login = FALSE,
            dry_run     = TRUE
        )
    )
})

# ---------------------------------------------------------------------------
# push_image() -- Layer 3: integration (skip unless podman, a real login,
# and an explicit test destination are all available)
# ---------------------------------------------------------------------------
#
# push_image() additionally needs a real login to registry.doit.wisc.edu and
# a real GitLab project to push into -- neither of which this suite can
# supply on its own, and neither of which should be guessed at or
# hardcoded, since that risks pushing a test image to a project this test
# wasn't actually told to use. Guarded by two more environment variables on
# top of CONTAINR_INTEGRATION_TESTS:
#
#   CONTAINR_TEST_NAMESPACE -- your UW-Madison NetID (or the equivalent
#                              identifier for another registry)
#   CONTAINR_TEST_PROJECT   -- a GitLab project you're willing to push a
#                              throwaway test image to
#
# Run `podman login registry.doit.wisc.edu` once beforehand -- this test
# does not attempt to authenticate for you.

test_that("push_image() successfully pushes a real image to the registry", {
    skip_if(
        nchar(Sys.getenv("CONTAINR_INTEGRATION_TESTS")) == 0,
        "Set CONTAINR_INTEGRATION_TESTS=true to run integration tests"
    )
    skip_if_not(
        nchar(.sys_which("podman")) > 0,
        "podman not available on this system"
    )

    test_namespace <- Sys.getenv("CONTAINR_TEST_NAMESPACE")
    test_project   <- Sys.getenv("CONTAINR_TEST_PROJECT")
    skip_if(
        nchar(test_namespace) == 0 || nchar(test_project) == 0,
        "Set CONTAINR_TEST_NAMESPACE and CONTAINR_TEST_PROJECT to run push_image() integration tests"
    )

    tmp <- withr::local_tempdir()
    writeLines(c("FROM alpine:latest", "CMD [\"true\"]"), file.path(tmp, "Dockerfile"))
    withr::local_dir(tmp)

    build_tag <- paste0("containr-test-push-image:", as.integer(Sys.time()))
    on.exit(system2("podman", args = c("rmi", "-f", build_tag), stdout = FALSE, stderr = FALSE), add = TRUE)
    build_image(tag = build_tag, platform = NULL)

    push_tag <- as.character(as.integer(Sys.time()))

    expect_no_error(
        push_image(
            image_id  = build_tag,
            namespace = test_namespace,
            project   = test_project,
            tag       = push_tag
        )
    )
})

# ---------------------------------------------------------------------------
# list_images() -- Layer 1: argument validation
# ---------------------------------------------------------------------------

test_that("list_images() errors when tool_preference names a tool that isn't installed", {
    local_mocked_bindings(
        `.sys_which` = function(x) setNames("", x),
        .package = "containr"
    )
    expect_error(
        list_images(tool_preference = "singularity"),
        regexp = "not installed"
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
        nchar(.sys_which("podman")) > 0,
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
        nchar(.sys_which("podman")) > 0,
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
        nchar(.sys_which("podman")) > 0,
        "podman not available on this system"
    )
    local_mocked_bindings(
        `.resolve_tool` = function(...) "podman",
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

# ---------------------------------------------------------------------------
# .is_responsive() -- internal helper
# ---------------------------------------------------------------------------

test_that(".is_responsive() returns TRUE when tool responds", {
    local_mocked_bindings(
        `system2` = function(...) 0L,
        .package = "base"
    )
    expect_true(.is_responsive("podman"))
})

test_that(".is_responsive() returns FALSE when tool does not respond", {
    local_mocked_bindings(
        `system2` = function(...) 1L,
        .package = "base"
    )
    expect_false(.is_responsive("podman"))
})

# ---------------------------------------------------------------------------
# .docker_config_has_auth() -- internal helper
# ---------------------------------------------------------------------------

test_that(".docker_config_has_auth() returns FALSE when the config file does not exist", {
    tmp_dir      <- withr::local_tempdir()
    missing_path <- file.path(tmp_dir, "config.json")
    expect_false(.docker_config_has_auth("registry.doit.wisc.edu", config_path = missing_path))
})

test_that(".docker_config_has_auth() returns TRUE when the registry has an auths entry", {
    tmp_dir  <- withr::local_tempdir()
    tmp_path <- file.path(tmp_dir, "config.json")
    writeLines('{"auths": {"registry.doit.wisc.edu": {}}}', tmp_path)
    expect_true(.docker_config_has_auth("registry.doit.wisc.edu", config_path = tmp_path))
})

test_that(".docker_config_has_auth() returns FALSE when the registry has no auths entry", {
    tmp_dir  <- withr::local_tempdir()
    tmp_path <- file.path(tmp_dir, "config.json")
    writeLines('{"auths": {"ghcr.io": {}}}', tmp_path)
    expect_false(.docker_config_has_auth("registry.doit.wisc.edu", config_path = tmp_path))
})

test_that(".docker_config_has_auth() returns FALSE when auths is missing entirely", {
    tmp_dir  <- withr::local_tempdir()
    tmp_path <- file.path(tmp_dir, "config.json")
    writeLines('{}', tmp_path)
    expect_false(.docker_config_has_auth("registry.doit.wisc.edu", config_path = tmp_path))
})

test_that(".docker_config_has_auth() returns FALSE when the config file is malformed", {
    tmp_dir  <- withr::local_tempdir()
    tmp_path <- file.path(tmp_dir, "config.json")
    writeLines('{not valid json', tmp_path)
    expect_false(.docker_config_has_auth("registry.doit.wisc.edu", config_path = tmp_path))
})

# ---------------------------------------------------------------------------
# .is_logged_in() -- internal helper
# ---------------------------------------------------------------------------
#
# This is the fix for the --get-login bug: --get-login is Podman-only and
# always failed under Docker (exit 125) regardless of actual login state.
# Podman keeps its native flag; Docker (and, permissively, anything else)
# falls back to .docker_config_has_auth().

test_that(".is_logged_in() uses podman's native --get-login flag for podman", {
    local_mocked_bindings(
        `system2` = function(...) 0L,
        .package = "base"
    )
    expect_true(.is_logged_in("podman", "registry.doit.wisc.edu"))
})

test_that(".is_logged_in() returns FALSE when podman's --get-login exits non-zero", {
    local_mocked_bindings(
        `system2` = function(...) 1L,
        .package = "base"
    )
    expect_false(.is_logged_in("podman", "registry.doit.wisc.edu"))
})

test_that(".is_logged_in() falls back to the Docker config file for docker", {
    local_mocked_bindings(
        `.docker_config_has_auth` = function(...) TRUE,
        .package = "containr"
    )
    expect_true(.is_logged_in("docker", "registry.doit.wisc.edu"))
})

test_that(".is_logged_in() falls back to the Docker config file for an unrecognized tool", {
    # Permissive by design, mirroring .resolve_tool()'s own permissiveness --
    # a tool_preference value containr doesn't have dedicated support for
    # yet still gets a best-effort check rather than an outright error.
    local_mocked_bindings(
        `.docker_config_has_auth` = function(...) FALSE,
        .package = "containr"
    )
    expect_false(.is_logged_in("nerdctl", "ghcr.io"))
})

# ---------------------------------------------------------------------------
# .resolve_tool() -- explicit tool
# ---------------------------------------------------------------------------

test_that(".resolve_tool() returns the tool when explicitly specified and responsive", {
    local_mocked_bindings(
        `.sys_which`      = function(x) setNames("/usr/bin/podman", x),
        `.is_responsive` = function(...) TRUE,
        .package = "containr"
    )
    expect_equal(.resolve_tool("podman"), "podman")
})

test_that(".resolve_tool() errors when explicit tool is not installed", {
    local_mocked_bindings(
        `.sys_which` = function(x) setNames("", x),
        .package = "containr"
    )
    expect_error(
        .resolve_tool("podman"),
        regexp = "not installed"
    )
})

test_that(".resolve_tool() errors when explicit podman is installed but not responsive", {
    local_mocked_bindings(
        `.sys_which`      = function(x) setNames("/usr/bin/podman", x),
        `.is_responsive` = function(...) FALSE,
        .package = "containr"
    )
    expect_error(
        .resolve_tool("podman"),
        regexp = "not responsive"
    )
})

test_that(".resolve_tool() errors when explicit docker is installed but not responsive", {
    local_mocked_bindings(
        `.sys_which`      = function(x) setNames("/usr/bin/docker", x),
        `.is_responsive` = function(...) FALSE,
        .package = "containr"
    )
    expect_error(
        .resolve_tool("docker"),
        regexp = "daemon is not running"
    )
})

# ---------------------------------------------------------------------------
# .resolve_tool() -- auto-detection
# ---------------------------------------------------------------------------

test_that(".resolve_tool() auto-detects podman when both are installed and responsive", {
    local_mocked_bindings(
        `.sys_which`      = function(x) setNames(paste0("/usr/bin/", x), x),
        `.is_responsive` = function(...) TRUE,
        .package = "containr"
    )
    expect_equal(.resolve_tool(), "podman")
})

test_that(".resolve_tool() falls through to docker when podman is installed but not responsive", {
    local_mocked_bindings(
        `.sys_which` = function(x) setNames(paste0("/usr/bin/", x), x),
        `.is_responsive` = function(tool) tool == "docker",
        .package = "containr"
    )
    expect_equal(.resolve_tool(), "docker")
})

test_that(".resolve_tool() falls through to docker when podman is not installed", {
    local_mocked_bindings(
        `.sys_which` = function(x) {
            if (x == "podman") setNames("", x)
            else setNames("/usr/bin/docker", x)
        },
        `.is_responsive` = function(...) TRUE,
        .package = "containr"
    )
    expect_equal(.resolve_tool(), "docker")
})

test_that(".resolve_tool() errors when both are installed but neither is responsive", {
    local_mocked_bindings(
        `.sys_which`      = function(x) setNames(paste0("/usr/bin/", x), x),
        `.is_responsive` = function(...) FALSE,
        .package = "containr"
    )
    expect_error(
        .resolve_tool(),
        regexp = "not responsive"
    )
})

test_that(".resolve_tool() errors when no candidate is installed", {
    local_mocked_bindings(
        `.sys_which` = function(x) setNames("", x),
        .package = "containr"
    )
    expect_error(
        .resolve_tool(),
        regexp = "None of.*found"
    )
})

test_that(".resolve_tool() treats a single unrecognized tool as an explicit choice, not a rejected one", {
    # tool_preference is intentionally permissive -- an unrecognized name
    # like "singularity" is not rejected outright, it just isn't installed
    # (per the mock below), same as any other explicit tool would be.
    local_mocked_bindings(
        `.sys_which` = function(x) setNames("", x),
        .package = "containr"
    )
    expect_error(
        .resolve_tool("singularity"),
        regexp = "not installed"
    )
})

# ---------------------------------------------------------------------------
# .resolve_tool() -- tool_preference structural validation
# ---------------------------------------------------------------------------

test_that(".resolve_tool() rejects a non-character tool_preference", {
    expect_error(.resolve_tool(123),  regexp = "non-empty character vector")
    expect_error(.resolve_tool(TRUE), regexp = "non-empty character vector")
})

test_that(".resolve_tool() rejects an empty or NULL tool_preference", {
    expect_error(.resolve_tool(character(0)), regexp = "non-empty character vector")
    expect_error(.resolve_tool(NULL),         regexp = "non-empty character vector")
})

test_that(".resolve_tool() rejects a tool_preference containing NA", {
    expect_error(.resolve_tool(c("podman", NA)), regexp = "non-empty character vector")
})

# ---------------------------------------------------------------------------
# .resolve_tool() -- custom tool_preference order
# ---------------------------------------------------------------------------

test_that(".resolve_tool() honors a custom tool_preference order", {
    local_mocked_bindings(
        `.sys_which`     = function(x) setNames(paste0("/usr/bin/", x), x),
        `.is_responsive` = function(...) TRUE,
        .package = "containr"
    )
    expect_equal(.resolve_tool(c("docker", "podman")), "docker")
})

test_that(".resolve_tool() reports the exact custom tool_preference when nothing is found", {
    local_mocked_bindings(
        `.sys_which` = function(x) setNames("", x),
        .package = "containr"
    )
    err <- tryCatch(
        .resolve_tool(c("docker", "podman", "singularity")),
        error = function(e) conditionMessage(e)
    )
    expect_match(err, "docker")
    expect_match(err, "podman")
    expect_match(err, "singularity")
})

# ---------------------------------------------------------------------------
# .resolve_tool() -- generic fallback guidance for unrecognized tool names
# ---------------------------------------------------------------------------

test_that(".resolve_tool() gives generic guidance for an unrecognized tool that is installed but unresponsive", {
    local_mocked_bindings(
        `.sys_which`      = function(x) setNames("/usr/local/bin/apptainer", x),
        `.is_responsive` = function(...) FALSE,
        .package = "containr"
    )
    err <- tryCatch(
        .resolve_tool("apptainer"),
        error = function(e) conditionMessage(e)
    )
    expect_match(err, "apptainer")
    expect_match(err, "not responsive")
})

# ---------------------------------------------------------------------------
# .check_tool_responsive() -- internal helper
# ---------------------------------------------------------------------------

test_that(".check_tool_responsive() is silent when the tool responds", {
    local_mocked_bindings(
        `.is_responsive` = function(...) TRUE,
        .package = "containr"
    )
    expect_no_error(.check_tool_responsive("podman"))
})

test_that(".check_tool_responsive() gives specific guidance for docker and podman", {
    local_mocked_bindings(
        `.is_responsive` = function(...) FALSE,
        .package = "containr"
    )
    expect_error(.check_tool_responsive("docker"), regexp = "daemon is not running")
    expect_error(.check_tool_responsive("podman"), regexp = "not responsive")
})

test_that(".check_tool_responsive() falls back to generic guidance for other tools", {
    local_mocked_bindings(
        `.is_responsive` = function(...) FALSE,
        .package = "containr"
    )
    expect_error(
        .check_tool_responsive("apptainer"),
        regexp = "Start the apptainer daemon"
    )
})
