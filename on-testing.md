# On Testing in containr

## Why testing is complicated here

Most R packages test their functions by calling them and checking the
output. `containr` can do that for
[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
— it writes a text file, and we can read that file and assert on its
contents. But
[`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md),
[`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md),
and
[`list_images()`](https://erwinlares.github.io/containr/reference/list_images.md)
are different. They wrap system commands:

``` bash
podman build -f Dockerfile .
podman tag abc123 registry.doit.wisc.edu/netid/project:1.0.0
podman push registry.doit.wisc.edu/netid/project:1.0.0
podman image ls
```

Testing these functions end-to-end requires a running container daemon,
a real image, and for
[`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md),
a live registry with valid credentials. None of those conditions hold
reliably on GitHub Actions, on CRAN’s check servers, or on a colleague’s
machine who hasn’t set up Podman.

If we wrote naive end-to-end tests for these functions and pushed to
GitHub, every CI run would fail. CRAN would reject the package. The
tests would be useless outside the specific environment where they were
written.

The three-layer strategy solves this by separating what we *can* always
test from what we *can only* test locally.

------------------------------------------------------------------------

## The three layers

### Layer 1 — Argument validation

These tests check that the functions behave correctly before they ever
touch the system. They test the R logic, not the system commands.

**What they test:** - Required arguments error when missing - Invalid
arguments produce informative error messages - The error fires before
any file is written or any command is run

**Why they always run:** These tests have no external dependencies. They
don’t need `podman`, `docker`, a registry, or internet access. They run
identically on your laptop, on GitHub Actions, and on CRAN’s Windows
check server.

**Example:**

``` r

test_that("push_image() errors when image_id is NULL", {
    expect_error(
        push_image(netid = "erwin.lares", project = "container-registry"),
        regexp = "image_id"
    )
})
```

This test never reaches `podman`. It just confirms that
[`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)
catches the missing argument and says something useful about it.

------------------------------------------------------------------------

### Layer 2 — Command construction

These tests check that the *right command* is assembled from the
supplied arguments, without actually running the command. Two mechanisms
make this possible.

**`dry_run = TRUE`**

Every system-facing function in `containr` accepts a `dry_run` argument.
When `TRUE`, the function prints the command it would run — as a
`cli_inform()` message — and returns without executing anything. Tests
capture this message and assert on its content.

``` r

test_that("build_image() dry_run produces podman build command", {
    # ... setup ...
    expect_message(
        build_image(dry_run = TRUE),
        regexp = "podman build"
    )
})
```

`dry_run = TRUE` is not just a convenience feature. It is the primary
mechanism that makes Layer 2 tests possible. Every system-facing
function must implement it.

**`local_mocked_bindings()`**

Even with `dry_run = TRUE`,
[`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md)
still calls
[`.resolve_tool()`](https://erwinlares.github.io/containr/reference/dot-resolve_tool.md)
(to detect whether `podman` or `docker` is available) and
[`.check_tool_responsive()`](https://erwinlares.github.io/containr/reference/dot-check_tool_responsive.md)
(to verify the daemon is running) before it reaches the `dry_run`
branch. On a machine without `podman`, these would fail before the test
even gets to assert anything.

`local_mocked_bindings()` from `testthat` replaces a function with a
fake version for the duration of a single test. When the test ends, the
original function is restored. We use it to replace
[`.resolve_tool()`](https://erwinlares.github.io/containr/reference/dot-resolve_tool.md)
with a function that always returns `"podman"`, and
[`.check_tool_responsive()`](https://erwinlares.github.io/containr/reference/dot-check_tool_responsive.md)
with a function that does nothing:

``` r

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
        build_image(dry_run = TRUE),
        regexp = "podman build"
    )
})
```

With these two mocks in place, the test runs correctly on any machine,
regardless of whether `podman` is installed.

**Why `local_mocked_bindings()` is called inline, not in a helper**

You might expect a helper function like `.mock_tool()` to avoid
repeating the `local_mocked_bindings()` calls in every test. We tried
this and it does not work. `local_mocked_bindings()` registers cleanup
with the *calling frame* — when called inside a helper function, it
cleans up when the helper returns, not when the test ends. The mock
disappears before the test body runs. This is why every test calls
`local_mocked_bindings()` directly.

**Why they always run:**

Layer 2 tests have no real external dependencies.
[`.resolve_tool()`](https://erwinlares.github.io/containr/reference/dot-resolve_tool.md)
and
[`.check_tool_responsive()`](https://erwinlares.github.io/containr/reference/dot-check_tool_responsive.md)
are mocked away, and `dry_run = TRUE` prevents any system command from
executing. These tests run on GitHub Actions, on CRAN, and on any
machine, regardless of what container tools are installed.

------------------------------------------------------------------------

### Layer 3 — Integration

These tests call real system commands against a real container
environment. They are the only tests that confirm the functions actually
work end-to-end.

**Why they are guarded:**

Integration tests for
[`build_image()`](https://erwinlares.github.io/containr/reference/build_image.md)
require `podman` installed and the daemon running. Integration tests for
[`push_image()`](https://erwinlares.github.io/containr/reference/push_image.md)
additionally require a valid registry login. These conditions do not
hold on GitHub Actions or CRAN. Running these tests there would produce
failures that have nothing to do with the code.

We guard Layer 3 tests with an explicit opt-in environment variable:

``` r

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
```

The first guard — `skip_if(nchar(Sys.getenv(...)) == 0)` — skips the
test unless the developer has explicitly set
`CONTAINR_INTEGRATION_TESTS=true` in their environment. Neither
`devtools::test()` nor `devtools::check()` sets this variable, so Layer
3 tests are skipped by default in all automated contexts. The second
guard — `skip_if_not(nchar(Sys.which("podman")) > 0)` — is a safety
check that skips if `podman` is not installed, in case the environment
variable is set on a machine without a container tool.

Note that `skip_on_cran()` was considered but rejected for this purpose.
`devtools::check()` sets `NOT_CRAN=true`, which means `skip_on_cran()`
does not skip during `devtools::check()` — only on actual CRAN servers
and bare `R CMD check` calls from the terminal. The environment variable
approach gives explicit, predictable control regardless of how the tests
are invoked.

**Where they run:**

Layer 3 tests run only when you explicitly opt in before running the
test suite:

``` r

Sys.setenv(CONTAINR_INTEGRATION_TESTS = "true")
devtools::test()
Sys.unsetenv("CONTAINR_INTEGRATION_TESTS")
```

They are part of the manual pre-submission checklist — the last
verification step before submitting to CRAN — not part of the automated
CI suite.

**Why CRAN and CI cannot run them:**

When you submit a package to CRAN, CRAN’s servers run `R CMD CHECK` on
your package across multiple platforms — Linux, macOS, and Windows.
These are generic cloud machines with no knowledge of your project, your
institution, or your infrastructure. Concretely, the following
conditions that Layer 3 tests require cannot be met on CRAN or GitHub
Actions:

- `podman` and `docker` are not installed on CRAN’s check servers
- There is no container daemon running
- There is no CHTC account or active session on a CHTC submit node
- There are no credentials for `registry.doit.wisc.edu` — no PAT, no
  cached login
- Network access to `registry.doit.wisc.edu` is not available from
  CRAN’s infrastructure

If Layer 3 tests ran unconditionally, every CRAN submission would fail
with errors that have nothing to do with the package code. The
`skip_if_not()` guard prevents this by silently skipping the tests when
the required environment is absent. From CRAN’s perspective, a skipped
test is acceptable; a failed test is not.

GitHub Actions has the same constraints. The CI workflow runs on
`ubuntu-latest` runners that have no container tools, no CHTC
credentials, and no registry access. Layers 1 and 2 run there and
provide meaningful coverage. Layer 3 is reserved for local pre-release
verification, where all the necessary conditions can actually be met.

------------------------------------------------------------------------

## Supporting tools

### `withr::local_tempdir()`

Creates a temporary directory and registers it for automatic cleanup
when the test ends. Every test that writes files uses this rather than
hardcoding a path, which would leave debris on disk and potentially
interfere with other tests.

``` r

tmp <- withr::local_tempdir()
# tmp is now something like /tmp/RtmpXXXXXX/testdir
# It will be deleted automatically when the test_that() block exits
```

### `withr::local_dir()`

Changes the working directory for the duration of the test and restores
it when the test ends.
[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
looks for `renv.lock` in [`getwd()`](https://rdrr.io/r/base/getwd.html),
so tests that call it must set the working directory to wherever the
test’s `renv.lock` was written.

``` r

tmp <- withr::local_tempdir()
writeLines('{"R":{"Version":"4.4.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
withr::local_dir(tmp)
# getwd() is now tmp — generate_dockerfile() will find renv.lock here
```

Critically,
[`withr::local_dir()`](https://withr.r-lib.org/reference/with_dir.html)
must be called directly inside the `test_that()` block, not inside a
helper function, for the same reason as `local_mocked_bindings()` — it
registers cleanup with the calling frame.

### `local_mocked_bindings()`

Temporarily replaces a function binding for the duration of a test. Used
in Layer 2 tests to intercept
[`.resolve_tool()`](https://erwinlares.github.io/containr/reference/dot-resolve_tool.md)
and
[`.check_tool_responsive()`](https://erwinlares.github.io/containr/reference/dot-check_tool_responsive.md)
so tests run without a real container tool installed.

The `.package` argument specifies which package’s namespace the binding
lives in. For `containr`’s internal helpers:

``` r

local_mocked_bindings(
    `.resolve_tool` = function(...) "podman",
    .package = "containr"
)
```

For functions in other packages, such as
[`renv::status()`](https://rstudio.github.io/renv/reference/status.html),
the package name changes accordingly:

``` r

local_mocked_bindings(
    `status` = function(...) list(synchronized = TRUE),
    .package = "renv"
)
```

Note that you pass just the function name (`status`), not the qualified
name
([`renv::status`](https://rstudio.github.io/renv/reference/status.html)).
The `.package` argument tells `local_mocked_bindings()` where to find
the binding.

### The minimal `renv.lock` fixture

[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
requires an `renv.lock` in the current working directory. In tests, we
write a minimal valid lockfile — one that satisfies the JSON structure
`renv` expects but contains no packages:

``` r

writeLines('{"R":{"Version":"4.4.0"},"Packages":{}}', file.path(tmp, "renv.lock"))
```

This is enough for
[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
to pass the lockfile check and for
[`.read_renv_packages()`](https://erwinlares.github.io/containr/reference/dot-read_renv_packages.md)
to return `character(0)` (no packages), which combined with the
`.fetch_sysreqs` mock produces a Dockerfile with only the `curl`
baseline library installed.

------------------------------------------------------------------------

## The renv.lock requirement and CI

[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
validates that `renv.lock` exists before doing anything else. This was a
deliberate design decision: a Dockerfile generated without a lockfile
would produce a container with no R packages installed, which is almost
certainly not what the researcher wants.

The consequence for testing is that any test calling
[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
must either write a `renv.lock` fixture or mock the validation step. We
chose to write the fixture — it tests the real code path and makes the
test behavior easier to reason about than a mock that skips the
validation.

This is also why `withr::local_dir(tmp)` appears in almost every
[`generate_dockerfile()`](https://erwinlares.github.io/containr/reference/generate_dockerfile.md)
test. The lockfile must be in
[`getwd()`](https://rdrr.io/r/base/getwd.html), and
[`getwd()`](https://rdrr.io/r/base/getwd.html) during tests is the
`tests/testthat/` directory — not the project root where the real
`renv.lock` lives. Changing the working directory to the temp directory
puts the fixture lockfile in the right place.

------------------------------------------------------------------------

## Summary

| Layer | What it tests | Requires | Runs on CI | Runs on CRAN | Guard |
|----|----|----|----|----|----|
| 1 | Argument validation | Nothing | Yes | Yes | none |
| 2 | Command construction | `dry_run`, mocks | Yes | Yes | none |
| 3 | End-to-end execution | podman, registry | No | No | `CONTAINR_INTEGRATION_TESTS=true` |

The goal is to maximize what we can verify automatically while being
honest about what requires a real environment. Layers 1 and 2 give us
high confidence that the logic is correct. Layer 3 confirms it works in
practice before we ship.
