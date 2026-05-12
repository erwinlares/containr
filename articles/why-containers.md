# From renv to containers: why recording your R packages may not be enough

![toolero hex sticker](figures/logo.png)

## You already care about reproducibility

If you are reading this vignette, you probably already know why
reproducibility matters in research. You track your code with git. You
use `renv` to record which R packages your project depends on. You may
even share your code with collaborators or post it alongside a
manuscript. You have, in other words, already done more than most.

This vignette is for researchers who want to go one step further. Maybe
you are collaborating with someone whose machine behaves differently
from yours. Maybe you want to move an analysis from your laptop to a
computing cluster and you are not sure how to make sure it still runs.
Maybe you have had the experience of returning to an old project months
later and finding that something no longer works — a package updated, a
dependency changed, and the analysis quietly broke.

The question this vignette tries to answer is: if `renv` already records
your R packages, what else could go wrong? And why might a container be
the answer?

## What renv does — and does not do

`renv` is excellent at what it does. It records the R packages your
project uses — their names, versions, and sources — in a `renv.lock`
file. When a collaborator runs
[`renv::restore()`](https://rstudio.github.io/renv/reference/restore.html),
they get the same package versions you used. That is a genuine
reproducibility guarantee, and it covers the most common source of “it
worked on my machine” problems.

But `renv` records the R package layer. Below that layer sits everything
else the analysis depends on: the R version itself, the operating
system, the system libraries that R packages compile against, and any
external tools the analysis calls. `renv` does not capture any of those.
It cannot — that is not what it was designed to do.

In practice this means that
[`renv::restore()`](https://rstudio.github.io/renv/reference/restore.html)
is not always sufficient. Consider a few scenarios that R users
encounter regularly.

A collaborator tries to restore your environment on a different
operating system. A package that compiled cleanly on macOS requires a
system library that is not installed by default on Linux. The restore
fails, and the error message points to a C compiler or a missing header
file rather than anything obviously R-related.

You install a newer version of R and try to rerun an analysis from six
months ago. Most packages restore fine, but one package was compiled
against a system library that has since been updated. The behavior
changes subtly — or the package simply fails to load.

You want to run your analysis on a computing cluster. The cluster runs
Linux. Your laptop runs macOS. Your `renv.lock` is intact, but the
runtime environment is fundamentally different. The analysis that runs
cleanly on your machine may not run at all on the cluster without
additional setup.

None of these failures are caused by careless coding. They are caused by
the gap between what `renv` captures and what a running R analysis
actually depends on.

## What a container adds

A container is a lightweight, self-contained unit that packages an
application together with the environment it needs to run. For an R
analysis, that means not just the R packages but also the R version, the
operating system libraries, the system tools, and the configuration that
ties everything together.

When you run a containerized analysis, you are not running it on your
operating system directly. You are running it inside a controlled
environment that is defined by a recipe — a `Dockerfile` — and that
recipe can be shared, versioned, archived, and run on any machine that
can execute containers.

The key difference from `renv` is the level of the stack being captured.
`renv` records the R package layer. A container captures the entire
runtime environment, from the base operating system up through the R
installation and package library.

It is worth being precise about what this means in practice. A container
does not guarantee that your analysis produces the same numerical
results on every machine — floating-point arithmetic and hardware
differences can still introduce variation at the margins. What it does
guarantee is that the software environment is identical: the same R
version, the same package versions, the same system libraries. That is a
much stronger reproducibility guarantee than `renv` alone can provide.

## The Dockerfile as a reproducibility artifact

The recipe for a container is a plain text file called a `Dockerfile`.
It specifies a base image — typically a Linux distribution with R
pre-installed — and then a sequence of instructions: install system
libraries, install R packages, copy files, set the working directory.

A `Dockerfile` is a reproducibility artifact in the same way that
`renv.lock` is. It can be committed to version control, shared with
collaborators, archived with a publication, and used to reconstruct the
analysis environment at any point in the future. Unlike `renv.lock`,
which only records R packages, the `Dockerfile` records the full stack.

Here is what a minimal `Dockerfile` for an R project might look like:

``` dockerfile
FROM rocker/r-ver:4.4.0
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /home
COPY renv.lock /home/renv.lock

RUN R -e "install.packages('renv', repos='https://packagemanager.posit.co/cran/latest')"
RUN R -e "renv::restore()"
```

Writing this by hand is tedious and error-prone. You have to know which
system libraries your R packages need, which base image to use, and how
to structure the installation steps. `containr` automates this: it reads
your `renv.lock`, infers the system library requirements, and writes the
`Dockerfile` for you.

## Where containr fits

`containr` is not a containerization framework. It is a practical tool
that connects the R workflow researchers already use to the container
workflow they need when a project is ready to move beyond a single
machine.

The connection point is `renv.lock`. If you already use `renv` — and if
you are reading this, you probably do — then `containr` needs almost
nothing else from you. It reads the lockfile, works out what the project
needs at the system level, and produces a `Dockerfile` you can build and
push without leaving R.

In other words, `renv` and containers are not alternatives. They are
complementary layers of the same reproducibility stack. `renv` handles
the R package layer. A container handles everything below it. Using both
together gives you a reproducibility guarantee that neither can provide
alone.

## What comes next

The companion vignette, *A first containerization workflow with
containr*, walks through the complete workflow: generating a
`Dockerfile` from your `renv.lock`, building the container image,
listing local images, and pushing the image to a registry. If you are
ready to containerize a project, that is the right place to start.

If you are not yet sure whether containerization is the right step for
your project, the framing in this vignette may be enough for now. You
can return to `containr` when the moment arrives — when you are
preparing to share an analysis, archive a workflow, or move an analysis
to a computing cluster. The `renv.lock` you already have is the starting
point.
