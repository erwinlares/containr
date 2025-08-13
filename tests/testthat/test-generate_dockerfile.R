## Check the two assumptions: (1) it is an R project, and (2) there is a renv.lock files listing all file dependencies

test_that("Folder is a proper R project", {
    expect_true(any(grepl("\\.Rproj$", list.files(path = here::here()))))
})


test_that("Project folder contains a .lock file managing package dependencies", {
    expect_true(file.exists(here::here("renv.lock")))
})
