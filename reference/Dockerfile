FROM rocker/r-ver:4.2.0
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y cmake libcurl4-openssl-dev libssl-dev libxml2-dev libgit2-dev libfontconfig1-dev libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev wget gdebi-core libharfbuzz-dev libfribidi-dev && apt-get clean && rm -rf /var/lib/apt/lists/*


WORKDIR /home
COPY renv.lock /home/renv.lock



RUN R -e "install.packages('renv', repos='https://packagemanager.posit.co/cran/latest')"
RUN R -e "renv::restore()"

