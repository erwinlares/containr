# tests/testthat/test-readme-workflow.R
#
# The README's "A first workflow" section is the first code a new user
# meets, and its four steps need a container engine and a registry to run
# end to end -- steps two through four (build_image(), list_images(),
# push_image()) can't run in CI. Step one can: generate_dockerfile() needs
# nothing but a lockfile in a temporary directory, and it's the step that
# generates everything the other three depend on. A test that extracts the
# README's own generate_dockerfile() call, runs it exactly as printed, and
# reads the resulting Dockerfile back would have caught a default-argument
# regression like C08 the moment it shipped, rather than whenever someone
# next happened to copy that exact example.
#
# It reads the README rather than holding a copy of the call, because a
# copy is how the two drift apart again. That means this test can only run
# where README.md is on disk: under devtools::test() and on CI from a
# source checkout, but not from a built tarball where the README may have
# been excluded. It skips rather than fails in that case, which is the
# right trade for a developer-time guard. Pattern copied from toolero's
# tests/testthat/test-readme-workflow.R.


# Helper: pull the first fenced r block out of a named markdown section.
extract_r_block <- function(path, heading) {
    lines <- readLines(path, warn = FALSE)

    start <- which(trimws(lines) == heading)
    if (length(start) == 0L) {
        return(NULL)
    }

    after <- lines[seq.int(start[[1L]] + 1L, length(lines))]
    opens <- which(trimws(after) == "```r")
    if (length(opens) == 0L) {
        return(NULL)
    }

    body  <- after[seq.int(opens[[1L]] + 1L, length(after))]
    close <- which(trimws(body) == "```")
    if (length(close) == 0L) {
        return(NULL)
    }

    body[seq_len(close[[1L]] - 1L)]
}

# Helper: within a block of R source lines, find the first top-level call to
# fn_name and return it as an unevaluated expression. The block as a whole
# mixes generate_dockerfile() with three steps that need a live container
# engine and registry; parsing it and picking out one call by name lets the
# test run exactly what the README prints for step one without also trying
# to run steps two through four.
extract_call <- function(lines, fn_name) {
    exprs <- tryCatch(
        parse(text = paste(lines, collapse = "\n")),
        error = function(e) NULL
    )
    if (is.null(exprs)) {
        return(NULL)
    }

    is_target <- vapply(exprs, function(e) {
        is.call(e) && identical(as.character(e[[1L]]), fn_name)
    }, logical(1))

    if (!any(is_target)) {
        return(NULL)
    }

    exprs[[which(is_target)[[1L]]]]
}


test_that("the README's generate_dockerfile() call runs and produces the promised Dockerfile", {
    skip_on_cran()

    readme <- testthat::test_path("..", "..", "README.md")
    skip_if_not(file.exists(readme), "README.md is not on disk in this build")

    block <- extract_r_block(readme, "## A first workflow")
    skip_if(is.null(block), "could not locate the first workflow block")

    call <- extract_call(block, "generate_dockerfile")
    skip_if(is.null(call), "could not locate a generate_dockerfile() call in the first workflow block")

    # Guard against the extraction silently finding the wrong call, which
    # would turn this into a test that passes by running nothing.
    deparsed <- paste(deparse(call), collapse = " ")
    expect_match(deparsed, "generate_dockerfile", fixed = TRUE)
    expect_match(deparsed, "r_version", fixed = TRUE)
    expect_match(deparsed, "output", fixed = TRUE)

    # Run it somewhere disposable, with the exact files the call's
    # data_file and code_file arguments reference -- so the call runs
    # exactly as printed in the README rather than being edited down to
    # something that no longer matches what a reader would type.
    tmp <- withr::local_tempdir()
    withr::local_dir(tmp)
    writeLines('{"R":{"Version":"4.4.0"},"Packages":{}}', "renv.lock")
    dir.create("data-raw")
    writeLines("a,b\n1,2", file.path("data-raw", "sample.csv"))
    writeLines("1 + 1", "analysis.R")

    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    env <- new.env(parent = globalenv())
    expect_no_error(eval(call, envir = env))

    # The call promises a Dockerfile that pins r_version and copies in the
    # two referenced files -- confirm the artifacts actually arrived.
    expect_true(file.exists(file.path(tmp, "Dockerfile")))
    lines <- readLines(file.path(tmp, "Dockerfile"))
    expect_true(any(grepl("^FROM rocker/r-ver:4\\.4\\.0$", lines)))
    expect_true(any(grepl("^COPY data-raw/sample\\.csv /home/data-raw/sample\\.csv$", lines)))
    expect_true(any(grepl("^COPY analysis\\.R /home/analysis\\.R$", lines)))
})
