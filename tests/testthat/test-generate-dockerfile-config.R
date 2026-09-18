# tests/testthat/test-generate-dockerfile-config.R
#
# Tests for the config argument (C01): generate_dockerfile() can fill in
# data_file, code_file, and misc_file from a _toolero.yml project manifest,
# but only an argument the caller left NULL, and never silently -- in
# verbose mode it names which arguments came from config rather than from
# the call. These tests write _toolero.yml fixtures by hand rather than
# depending on toolero being installed, since the schema (schema_version,
# folders:, conventions:) is the contract, not the package that usually
# writes it.

# Helper: write a _toolero.yml fixture in the same shape init_project()
# produces -- schema_version, a folders: list with one "- name" per line,
# and an optional conventions: block with one "key: value" per line.
write_toolero_yml <- function(path,
                              folders,
                              conventions    = NULL,
                              schema_version = 1L) {
    lines <- character(0)

    if (!is.null(schema_version)) {
        lines <- c(lines, paste0("schema_version: ", schema_version))
    }

    lines <- c(lines, "folders:")
    if (length(folders) > 0L) {
        lines <- c(lines, paste0("  - ", folders))
    }

    if (!is.null(conventions)) {
        lines <- c(lines, "conventions:")
        lines <- c(lines, paste0("  ", names(conventions), ": ", unlist(conventions)))
    }

    writeLines(lines, path)
    invisible(path)
}


test_that("config = NULL changes nothing (the default)", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    expect_no_error(generate_dockerfile(r_version = "4.3.0", output = tmp))
    lines <- readLines(file.path(tmp, "Dockerfile"))
    # renv.lock is always COPY'd, config or no config -- what config = NULL
    # should leave untouched is any COPY of project content (data_file,
    # code_file, misc_file), so that line has to be excluded here rather
    # than asserting no COPY line exists at all.
    project_copies <- lines[grepl("^COPY ", lines) & !grepl("renv\\.lock", lines)]
    expect_length(project_copies, 0)
})

test_that("data_file, code_file, and misc_file are all derived when the caller supplies none", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    dir.create("data-raw")
    writeLines("a,b", file.path("data-raw", "sample.csv"))
    dir.create("R")
    writeLines("1 + 1", file.path("R", "analysis.R"))
    dir.create("assets")
    writeLines("x", file.path("assets", "logo.png"))

    write_toolero_yml(
        "_toolero.yml",
        folders     = c("data-raw", "data", "R", "scripts", "output/figures",
                        "output/tables", "reports", "assets"),
        conventions = list(output_dir = "output", script_dir = "R", split_dir = "data/jobs")
    )

    generate_dockerfile(r_version = "4.3.0", config = "_toolero.yml", output = tmp)
    lines <- readLines(file.path(tmp, "Dockerfile"))

    # Anchored, but the trailing slash on either side of the COPY is
    # optional -- .validate_file_arg()'s own normalization of a directory
    # path is not part of this test's contract, only that the right
    # directory lands under the right place in copy_root.
    expect_true(any(grepl("^COPY data-raw/?\\s+/home/data-raw/?$", lines)))
    expect_true(any(grepl("^COPY R/?\\s+/home/R/?$", lines)))
    expect_true(any(grepl("^COPY assets/?\\s+/home/assets/?$", lines)))
})

test_that("an explicit file argument is never overridden by config", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    dir.create("R")
    writeLines("1 + 1", file.path("R", "analysis.R"))
    writeLines("x", "override.R")

    write_toolero_yml("_toolero.yml", folders = c("R"))

    generate_dockerfile(
        r_version = "4.3.0",
        config    = "_toolero.yml",
        code_file = "override.R",
        output    = tmp
    )
    lines <- readLines(file.path(tmp, "Dockerfile"))

    expect_true(any(grepl("^COPY override\\.R /home/override\\.R$", lines)))
    expect_false(any(grepl("^COPY R/ ", lines)))
})

test_that("verbose = TRUE reports which arguments came from config", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    dir.create("R")
    writeLines("1 + 1", file.path("R", "analysis.R"))
    write_toolero_yml("_toolero.yml", folders = c("R"))

    expect_message(
        generate_dockerfile(
            r_version = "4.3.0",
            config    = "_toolero.yml",
            verbose   = TRUE,
            output    = tmp
        ),
        "code_file.*not supplied.*_toolero\\.yml"
    )
})

test_that("verbose = FALSE emits no config-related messages", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    dir.create("R")
    writeLines("1 + 1", file.path("R", "analysis.R"))
    write_toolero_yml("_toolero.yml", folders = c("R"))

    expect_no_message(
        generate_dockerfile(
            r_version = "4.3.0",
            config    = "_toolero.yml",
            verbose   = FALSE,
            output    = tmp
        )
    )
})

test_that("a missing schema_version is treated as schema 1, without warning", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    dir.create("R")
    writeLines("1 + 1", file.path("R", "analysis.R"))
    write_toolero_yml("_toolero.yml", folders = c("R"), schema_version = NULL)

    expect_no_warning(
        generate_dockerfile(r_version = "4.3.0", config = "_toolero.yml", output = tmp)
    )
    lines <- readLines(file.path(tmp, "Dockerfile"))
    expect_true(any(grepl("^COPY R/?\\s+/home/R/?$", lines)))
})

test_that("an unrecognized schema_version warns but is still read on a best-effort basis", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    dir.create("R")
    writeLines("1 + 1", file.path("R", "analysis.R"))
    write_toolero_yml("_toolero.yml", folders = c("R"), schema_version = 2L)

    expect_warning(
        generate_dockerfile(r_version = "4.3.0", config = "_toolero.yml", output = tmp),
        "does not recognize"
    )
    lines <- readLines(file.path(tmp, "Dockerfile"))
    expect_true(any(grepl("^COPY R/?\\s+/home/R/?$", lines)))
})

test_that("a nonexistent config path errors clearly", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)

    expect_error(
        generate_dockerfile(r_version = "4.3.0", config = "nope.yml", output = tmp),
        "not found"
    )
})

test_that("a non-string config errors with a clear message", {
    tmp <- withr::local_tempdir()
    withr::local_dir(tmp)

    expect_error(
        generate_dockerfile(r_version = "4.3.0", config = 123, output = tmp),
        "single character string"
    )
    expect_error(
        generate_dockerfile(r_version = "4.3.0", config = c("a.yml", "b.yml"), output = tmp),
        "single character string"
    )
})

test_that("a config with no folders: entry contributes nothing", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    writeLines("schema_version: 1", "_toolero.yml")

    expect_no_error(
        generate_dockerfile(r_version = "4.3.0", config = "_toolero.yml", output = tmp)
    )
    lines <- readLines(file.path(tmp, "Dockerfile"))
    project_copies <- lines[grepl("^COPY ", lines) & !grepl("renv\\.lock", lines)]
    expect_length(project_copies, 0)
})

test_that("a conventions block missing script_dir falls back to the 'R' default", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    dir.create("R")
    writeLines("1 + 1", file.path("R", "analysis.R"))
    write_toolero_yml(
        "_toolero.yml",
        folders     = c("R"),
        conventions = list(output_dir = "output")
    )

    generate_dockerfile(r_version = "4.3.0", config = "_toolero.yml", output = tmp)
    lines <- readLines(file.path(tmp, "Dockerfile"))
    expect_true(any(grepl("^COPY R/?\\s+/home/R/?$", lines)))
})

test_that("only the folders actually present are derived -- no data-raw or R means no data_file or code_file", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    dir.create("assets")
    writeLines("x", file.path("assets", "logo.png"))
    write_toolero_yml("_toolero.yml", folders = c("assets"))

    generate_dockerfile(r_version = "4.3.0", config = "_toolero.yml", output = tmp)
    lines <- readLines(file.path(tmp, "Dockerfile"))

    expect_true(any(grepl("^COPY assets/?\\s+/home/assets/?$", lines)))
    expect_false(any(grepl("data-raw", lines, fixed = TRUE)))
    expect_false(any(grepl("^COPY R/?\\s", lines)))
})

# ---------------------------------------------------------------------------
# mkdir -p for config-declared folders (C07)
# ---------------------------------------------------------------------------
#
# generate_dockerfile() considered three answers to "the image has no
# output/ directory": do nothing, unconditionally mkdir a toolero-specific
# output/figures + output/tables, or derive the mkdir from folders: only
# when config is supplied. This is the third answer -- these tests cover
# both the presence of the RUN mkdir -p line when config is supplied and
# its absence when it is not.

test_that("mkdir -p is emitted for every folder declared in config, right after WORKDIR", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    # data-raw and R are also special folder names ("data-raw" derives
    # data_file, "R" is the default script_dir and derives code_file), so
    # both have to actually exist on disk for .validate_file_arg() not to
    # abort -- this also exercises mkdir and a config-derived COPY sharing
    # the same folder without conflict.
    dir.create("data-raw")
    writeLines("a,b", file.path("data-raw", "sample.csv"))
    dir.create("R")
    writeLines("1 + 1", file.path("R", "analysis.R"))

    write_toolero_yml(
        "_toolero.yml",
        folders = c("data-raw", "R", "output/figures", "output/tables")
    )

    generate_dockerfile(r_version = "4.3.0", config = "_toolero.yml", output = tmp)
    lines <- readLines(file.path(tmp, "Dockerfile"))

    mkdir_idx  <- which(grepl("^RUN mkdir -p ", lines))
    expect_length(mkdir_idx, 1)
    mkdir_line <- lines[mkdir_idx]

    expect_match(mkdir_line, "/home/data-raw", fixed = TRUE)
    expect_match(mkdir_line, "/home/R", fixed = TRUE)
    expect_match(mkdir_line, "/home/output/figures", fixed = TRUE)
    expect_match(mkdir_line, "/home/output/tables", fixed = TRUE)

    workdir_idx <- which(grepl("^WORKDIR ", lines))
    expect_length(workdir_idx, 1)
    expect_true(mkdir_idx > workdir_idx)
})

test_that("mkdir -p tracks a custom home_dir", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    write_toolero_yml("_toolero.yml", folders = c("output/figures"))

    generate_dockerfile(
        r_version = "4.3.0",
        config    = "_toolero.yml",
        home_dir  = "/workspace",
        output    = tmp
    )
    lines      <- readLines(file.path(tmp, "Dockerfile"))
    mkdir_line <- lines[grepl("^RUN mkdir -p ", lines)]

    expect_length(mkdir_line, 1)
    expect_match(mkdir_line, "/workspace/output/figures", fixed = TRUE)
    expect_false(grepl("/home/", mkdir_line, fixed = TRUE))
})

test_that("no mkdir -p line when config is not supplied", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    generate_dockerfile(r_version = "4.3.0", output = tmp)
    lines <- readLines(file.path(tmp, "Dockerfile"))
    expect_false(any(grepl("mkdir", lines, fixed = TRUE)))
})

test_that("no mkdir -p line when config has no folders: entry", {
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    writeLines("schema_version: 1", "_toolero.yml")

    generate_dockerfile(r_version = "4.3.0", config = "_toolero.yml", output = tmp)
    lines <- readLines(file.path(tmp, "Dockerfile"))
    expect_false(any(grepl("mkdir", lines, fixed = TRUE)))
})

test_that("mkdir -p includes a folder with no other special meaning to containr", {
    # C07's mkdir is derived from every declared folder, not just the three
    # containr already recognizes for data_file/code_file/misc_file -- a
    # folder like "reports", which containr has no other opinion about,
    # still gets created.
    tmp <- withr::local_tempdir()
    writeLines('{"R":{"Version":"4.3.0"},"Packages":{"cli":{"Package":"cli","Version":"3.6.0"}}}', file.path(tmp, "renv.lock"))
    withr::local_dir(tmp)
    local_mocked_bindings(`.r_ver_exists`  = function(...) TRUE,         .package = "containr")
    local_mocked_bindings(`.fetch_sysreqs` = function(...) character(0), .package = "containr")
    local_mocked_bindings(`status`         = function(...) list(synchronized = TRUE), .package = "renv")

    write_toolero_yml("_toolero.yml", folders = c("reports"))

    generate_dockerfile(r_version = "4.3.0", config = "_toolero.yml", output = tmp)
    lines      <- readLines(file.path(tmp, "Dockerfile"))
    mkdir_line <- lines[grepl("^RUN mkdir -p ", lines)]

    expect_length(mkdir_line, 1)
    expect_match(mkdir_line, "/home/reports", fixed = TRUE)
    project_copies <- lines[grepl("^COPY ", lines) & !grepl("renv\\.lock", lines)]
    expect_length(project_copies, 0)
})
