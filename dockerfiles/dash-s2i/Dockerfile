# Based on sclorg/s2i-python-container
# https://github.com/sclorg/s2i-python-container/blob/master/3.9/Dockerfile.fedora

FROM continuumio/miniconda3:4.8.2

ENV SUMMARY="Platform for building and running Python applications" \
    DESCRIPTION="Python application builder."

ENV ARCH=x86_64

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="Python 3.9" \
      io.openshift.s2i.scripts-url="image:///usr/libexec/s2i" \
      io.openshift.expose-services="8000:http" \
      io.openshift.tags="builder,python,python39,python-39,rh-python39" \
      maintainer="Blair Drummond <blair.drummond@canada.ca>"

ENV USER=app
ARG USER_GID=100
ENV APP_HOME=/home/app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1

# The fix permissions for conda
#COPY fix-permissions /usr/local/bin/fix-permissions
#RUN chmod a+rx /usr/local/bin/fix-permissions

RUN adduser --system --group $USER \
    && mkdir -p $APP_HOME \
    && chown -R $USER:$USER $APP_HOME

RUN chown $USER:$USER_GID /opt/conda
#    && fix-permissions /opt/conda

# the Source-2-image assemble and run script
COPY ./s2i/bin/ /usr/libexec/s2i

WORKDIR $APP_HOME
USER $USER

# Install pandas (require C stuff)
# as well as the webserver stuff.
RUN conda create -n $USER && \
    conda init bash && \
    conda install -n $USER --quiet --yes -c conda-forge \
       meinheld gunicorn \
    && conda clean --all -y -f

EXPOSE 8000

# CMD ["gunicorn", "-k", "egg:meinheld#gunicorn_worker", "app:app", "--bind", "0.0.0.0:8000", "-w", "4"]
CMD ["/usr/libexec/s2i/run"]
