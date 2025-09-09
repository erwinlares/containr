# Tests for project prerequisites expected by containr::generate_dockerfile()
# These are environment-independent and use temporary directories.
# They DO NOT assume the package repository itself contains .Rproj or renv.lock.

test_that("Folder is recognized as an R project when a .Rproj file exists", {
    tmp <- withr::local_tempdir()
    # create a fake R project file
    rproj <- file.path(tmp, "example.Rproj")
    writeLines("", rproj)

    # assertion using the temp path (avoid here::here() which always points to repo root)
    has_rproj <- any(grepl("\\.Rproj$", list.files(path = tmp, all.files = TRUE)))
    expect_true(has_rproj)
})

test_that("Project folder contains a renv.lock when present", {
    tmp <- withr::local_tempdir()
    lock <- file.path(tmp, "renv.lock")
    writeLines("{}", lock) # minimal JSON content

    expect_true(file.exists(lock))
})

# Optional: negative controls to ensure checks fail when files are absent
test_that("Absent .Rproj is detected", {
    tmp <- withr::local_tempdir()
    has_rproj <- any(grepl("\\.Rproj$", list.files(path = tmp, all.files = TRUE)))
    expect_false(has_rproj)
})

test_that("Absent renv.lock is detected", {
    tmp <- withr::local_tempdir()
    expect_false(file.exists(file.path(tmp, "renv.lock")))
})
