# GitHub: https://github.com/rocker-org/shiny
FROM rocker/shiny-verse:3.6.2

RUN apt-get update && apt-get install -y --no-install-recommends \
      default-jdk \
      r-cran-rjava \
      libgdal-dev \
      libproj-dev \
      libcurl4-openssl-dev \
      libssl-dev \
      libxml2-dev \
      libudunits2-dev \
      libgeos-dev \
    && \
    rm -rf /var/lib/apt/lists/*

# Install our custom packages
COPY ./PACKAGES /opt/PACKAGES
RUN cat /opt/PACKAGES | xargs install2.r -s

# Install latest httpuv packages for static assets 400 issue
RUN installGithub.r rstudio/httpuv

# Copy configuration files into the container image
COPY conf/shiny-server.conf  /etc/shiny-server/shiny-server.conf

# Make the ShinyApp available at port 8000
EXPOSE 8000

# Apply a temp fix to /etc/ssl/openssl.cnf to address
# https://github.com/StatCan/shiny/issues/14
COPY openssl_patch/openssl_prefix openssl_patch/openssl_suffix /tmp/
RUN cat /tmp/openssl_prefix /etc/ssl/openssl.cnf /tmp/openssl_suffix > /tmp/openssl.cnf \
    && mv /tmp/openssl.cnf /etc/ssl/openssl.cnf \
    && rm /tmp/openssl_prefix /tmp/openssl_suffix


ENV SUMMARY="Platform for building and running Shiny applications" \
    DESCRIPTION="Shiny application builder."

ENV ARCH=x86_64

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.openshift.s2i.scripts-url="image:///usr/libexec/s2i" \
      io.openshift.expose-services="8000:http" \
      maintainer="Blair Drummond <blair.drummond@canada.ca>"

# Copy further configuration files into the Docker image
COPY install_deps.R /bin/install_deps.R
COPY ./s2i/bin/ /usr/libexec/s2i

ENV R_LIBS_USER=/home/shiny/R

RUN mkdir -p /home/shiny/R \
    && chown -R shiny:shiny /home/shiny /srv/shiny-server
WORKDIR /srv/shiny-server
USER shiny

CMD ["/usr/libexec/s2i/run"]
