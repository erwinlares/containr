# tests/testthat/test-sysreqs-fallback.R
#
# .fetch_sysreqs() against a remotes::system_requirements() that rejects
# the Ubuntu release (remotes 2.5.0 stops at "22.04", while R 4.4.2 and
# later are backed by "24.04"), against grouped requests, and the verbose
# per-package report. Every test mocks remotes::system_requirements();
# none touches the network.

# The message remotes raises for an unknown release, as seen on a real
# run: match.arg() lists what it does accept, in curly quotes.
release_error <- function(accepted = c("14.04", "16.04", "18.04", "20.04", "22.04")) {
    stop(
        paste0("'arg' should be one of\n",
               paste0("“", accepted, "”", collapse = ", ")),
        call. = FALSE
    )
}

apt <- function(...) paste0("apt-get install -y ", c(...))


# -- release fallback ---------------------------------------------------------

test_that(".fetch_sysreqs() falls back to the newest accepted release not newer than the request", {
    asked <- character(0)
    local_mocked_bindings(
        system_requirements = function(os, os_release, path = ".", package = NULL, ...) {
            asked <<- c(asked, os_release)
            if (os_release == "24.04") release_error()
            apt("libfontconfig1-dev")
        },
        .package = "remotes"
    )

    expect_message(
        out <- containr:::.fetch_sysreqs("systemfonts", os_version = "24.04"),
        "instead"
    )
    expect_equal(out, "libfontconfig1-dev")
    expect_equal(asked, c("24.04", "22.04"))
})

test_that("the fallback follows whatever remotes says it accepts, not a list kept here", {
    asked <- character(0)
    local_mocked_bindings(
        system_requirements = function(os, os_release, path = ".", package = NULL, ...) {
            asked <<- c(asked, os_release)
            if (os_release != "20.04") release_error(c("18.04", "20.04"))
            apt("libpng-dev")
        },
        .package = "remotes"
    )

    expect_message(
        out <- containr:::.fetch_sysreqs("ragg", os_version = "24.04"),
        "instead"
    )
    expect_equal(out, "libpng-dev")
    expect_equal(asked, c("24.04", "20.04"))
})

test_that(".fetch_sysreqs() says nothing extra when the requested release is accepted", {
    local_mocked_bindings(
        system_requirements = function(...) apt("libpng-dev"),
        .package = "remotes"
    )

    expect_no_message(
        out <- containr:::.fetch_sysreqs("ragg", os_version = "24.04")
    )
    expect_equal(out, "libpng-dev")
})

test_that(".fetch_sysreqs() does not retry after a network failure", {
    calls <- 0L
    local_mocked_bindings(
        system_requirements = function(...) {
            calls <<- calls + 1L
            stop("Could not resolve host: packagemanager.posit.co", call. = FALSE)
        },
        .package = "remotes"
    )

    expect_warning(
        out <- containr:::.fetch_sysreqs("cli", os_version = "24.04"),
        "Could not retrieve system requirements"
    )
    expect_equal(out, character(0))
    expect_equal(calls, 1L)
})

test_that(".fetch_sysreqs() warns, without looping, when no accepted release is old enough", {
    calls <- 0L
    local_mocked_bindings(
        system_requirements = function(...) {
            calls <<- calls + 1L
            release_error(c("22.04", "24.04"))
        },
        .package = "remotes"
    )

    expect_warning(
        out <- containr:::.fetch_sysreqs("cli", os_version = "20.04"),
        "Could not retrieve system requirements"
    )
    expect_equal(out, character(0))
    expect_equal(calls, 1L)
})

test_that(".fetch_sysreqs() warns when the fallback release fails too", {
    asked <- character(0)
    local_mocked_bindings(
        system_requirements = function(os, os_release, ...) {
            asked <<- c(asked, os_release)
            if (os_release == "24.04") release_error()
            stop("Could not resolve host", call. = FALSE)
        },
        .package = "remotes"
    )

    expect_warning(
        out <- containr:::.fetch_sysreqs("cli", os_version = "24.04"),
        "Could not retrieve system requirements"
    )
    expect_equal(out, character(0))
    expect_equal(asked, c("24.04", "22.04"))
})


# -- grouped requests ---------------------------------------------------------

test_that(".fetch_sysreqs() splits very large lockfiles into groups of chunk_size and combines them", {
    sizes <- integer(0)
    local_mocked_bindings(
        system_requirements = function(os, os_release, path = ".", package = NULL, ...) {
            sizes <<- c(sizes, length(package))
            c(apt("libssl-dev"), apt(paste0("lib", package[[1]], "-dev")))
        },
        .package = "remotes"
    )

    pkgs <- paste0("pkg", 1:12)
    out  <- containr:::.fetch_sysreqs(pkgs, os_version = "22.04", chunk_size = 5L)

    expect_equal(sizes, c(5L, 5L, 2L))
    expect_equal(out, c("libssl-dev", "libpkg1-dev", "libpkg6-dev", "libpkg11-dev"))
})

test_that("the default chunk size is 50, so a typical lockfile takes two or three requests", {
    sizes <- integer(0)
    local_mocked_bindings(
        system_requirements = function(os, os_release, path = ".", package = NULL, ...) {
            sizes <<- c(sizes, length(package))
            apt("libssl-dev")
        },
        .package = "remotes"
    )

    containr:::.fetch_sysreqs(paste0("pkg", 1:109), os_version = "22.04")

    expect_equal(sizes, c(50L, 50L, 9L))
})

test_that(".fetch_sysreqs() returns character(0) for no packages without calling remotes", {
    local_mocked_bindings(
        system_requirements = function(...) stop("should not be called"),
        .package = "remotes"
    )
    expect_equal(containr:::.fetch_sysreqs(character(0), os_version = "24.04"),
                 character(0))
})


# -- reading the accepted releases --------------------------------------------

test_that(".accepted_releases() reads the list out of the match.arg() message", {
    f <- containr:::.accepted_releases

    curly <- tryCatch(release_error(), error = identity)
    expect_equal(f(curly), c("14.04", "16.04", "18.04", "20.04", "22.04"))

    plain <- simpleError("'arg' should be one of '20.04', '22.04'")
    expect_equal(f(plain), c("20.04", "22.04"))

    expect_equal(f(simpleError("Could not resolve host")), character(0))
})

test_that(".pick_fallback_release() picks the newest accepted release that is not newer", {
    f <- containr:::.pick_fallback_release
    accepted <- c("14.04", "16.04", "18.04", "20.04", "22.04")

    expect_equal(f("24.04", accepted), "22.04")
    expect_equal(f("22.10", accepted), "22.04")
    expect_equal(f("21.04", accepted), "20.04")
    expect_equal(f("24.04", rev(accepted)), "22.04")
    expect_null(f("12.04", accepted))
    expect_null(f("24.04", character(0)))
    expect_null(f("not-a-version", accepted))
})

test_that(".is_release_error() recognises the match.arg() message and nothing else", {
    expect_true(containr:::.is_release_error(simpleError("'arg' should be one of 'a', 'b'")))
    expect_false(containr:::.is_release_error(simpleError("Could not resolve host")))
})


# -- the verbose per-package report -------------------------------------------

# Single-package calls answer for that package; a grouped call answers with
# the union, the way the real service does.
traceable_remotes <- function(grouped_extra = character(0)) {
    by_pkg <- list(
        ragg        = c("libfreetype6-dev", "libpng-dev"),
        systemfonts = c("libfreetype6-dev", "libfontconfig1-dev"),
        cli         = character(0)
    )

    function(os, os_release, path = ".", package = NULL, ...) {
        libs <- unique(unlist(by_pkg[package], use.names = FALSE))
        if (length(package) > 1L) libs <- libs[!libs %in% grouped_extra]
        apt(libs)
    }
}

test_that("verbose mode names the packages behind each library", {
    local_mocked_bindings(system_requirements = traceable_remotes(), .package = "remotes")

    msgs <- testthat::capture_messages(
        out <- containr:::.fetch_sysreqs(c("ragg", "systemfonts", "cli"),
                                         os_version = "22.04", verbose = TRUE)
    )
    txt <- paste(msgs, collapse = "\n")

    expect_match(txt, "libfreetype6-dev: ragg, systemfonts", fixed = TRUE)
    expect_match(txt, "libpng-dev: ragg", fixed = TRUE)
    expect_match(txt, "libfontconfig1-dev: systemfonts", fixed = TRUE)
    expect_match(txt, "2 of 3 packages", fixed = TRUE)
    expect_setequal(out, c("libfreetype6-dev", "libpng-dev", "libfontconfig1-dev"))
})

test_that("the per-package report never changes what is returned, and flags a mismatch", {
    local_mocked_bindings(
        system_requirements = traceable_remotes(grouped_extra = "libpng-dev"),
        .package = "remotes"
    )

    msgs <- testthat::capture_messages(
        out <- containr:::.fetch_sysreqs(c("ragg", "systemfonts", "cli"),
                                         os_version = "22.04", verbose = TRUE)
    )
    txt <- paste(msgs, collapse = "\n")

    expect_false("libpng-dev" %in% out)
    expect_match(txt, "did not return", fixed = TRUE)
    expect_match(txt, "libpng-dev", fixed = TRUE)
    expect_match(txt, "install_syslibs", fixed = TRUE)
})

test_that("without verbose, each package is not looked up separately", {
    calls <- 0L
    inner <- traceable_remotes()
    local_mocked_bindings(
        system_requirements = function(...) {
            calls <<- calls + 1L
            inner(...)
        },
        .package = "remotes"
    )

    containr:::.fetch_sysreqs(c("ragg", "systemfonts", "cli"), os_version = "22.04")

    expect_equal(calls, 1L)
})

test_that("a failure while tracing is reported and does not lose the result", {
    local_mocked_bindings(
        system_requirements = function(os, os_release, path = ".", package = NULL, ...) {
            if (length(package) == 1L) stop("rate limited", call. = FALSE)
            apt("libpng-dev")
        },
        .package = "remotes"
    )

    msgs <- testthat::capture_messages(
        out <- containr:::.fetch_sysreqs(c("ragg", "cli"), os_version = "22.04",
                                         verbose = TRUE)
    )

    expect_equal(out, "libpng-dev")
    expect_match(paste(msgs, collapse = "\n"), "Could not trace", fixed = TRUE)
})

test_that(".invert_sysreqs() turns package -> libraries into library -> packages", {
    f <- containr:::.invert_sysreqs

    expect_equal(
        f(list(ragg = c("libpng-dev", "libfreetype6-dev"),
               systemfonts = "libfreetype6-dev",
               cli = character(0))),
        list(`libfreetype6-dev` = c("ragg", "systemfonts"),
             `libpng-dev`       = "ragg")
    )
    expect_equal(f(list(cli = character(0))), list())
})
