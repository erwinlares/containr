
<!-- README.md is generated from README.Rmd. Please edit that file -->

# containr

<!-- badges: start -->

<!-- badges: end -->

The goal of containr is to help automate the process of containerizing R
projects. Its core function, generate_dockerfile(), analyzes an R
project’s environment and dependencies—via renv::renv.lock—and generates
a ready-to-use Dockerfile that encapsulates the computational setup. The
package is designed to assist researchers in building portable and
consistent workflows, ensuring that analyses can be reliably shared,
archived, and rerun across systems.

## Installation

You can install the development version of containr from
[GitHub](https://github.com/) with:

``` r
# install.packages("pak")
pak::pak("erwinlares/containr")
```

## Example

This is a basic example which shows you how to solve a common problem:

``` r
library(containr)
# Generate a Dockerfile with the latest R version and the dependencies listed in renv.lock
generate_dockerfile()

# Generate a Dockerfile with a specific R version 
generate_dockerfile(r_version = "4.3.0")

# Generate a Dockerfile with RStudio server 
generate_dockerfile(r_mode = "rstudio")

# Generate a Dockerfile explaining in step in the process
generate_dockerfile(verbose = TRUE)

# Generate a documented Dockerfile
generate_dockerfile(comments = TRUE)
```
