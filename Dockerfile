ARG         base=alpine3.16

###

FROM        ${base} as superset-base

ARG         version=2.0.0
ARG         repo=apache/superset

RUN         wget -O - https://github.com/${repo}/archive/refs/tags/${version}.tar.gz | tar xz

WORKDIR     superset-${version}

###

FROM        superset-base as superset-py

# ENV         PYTHONPATH=/usr/lib/python3.10/site-packages:$PYTHONPATH

RUN         apk add --no-cache --virtual .build-deps \
                build-base \
                python3-dev \
                py3-pip \
                py3-numpy \
                py3-pandas \
                py3-apache-arrow \
                libpq-dev \
                libffi-dev \
                linux-headers \
                rust \
                cargo \
                # postgresql-dev \
                # cython \
                # gfortran \
                # libbsd-dev \
                # openblas-dev \
                # default-libmysqlclient-dev \
                # libsasl2-dev \
                # libecpg-dev \
                && \
            sed -i 's|numpy==1.22.1|numpy==1.22.3|g' requirements/base.txt && \
            sed -i 's|numpy==1.22.1|numpy==1.22.3|g' setup.py && \
            sed -i 's|pandas==1.3.4|pandas>=1.3.2|g' requirements/base.txt && \
            sed -i 's|pyarrow==5.0.0|pyarrow==8.0.0|g' requirements/base.txt && \
            sed -i 's|pyarrow>=5.0.0, <6.0|pyarrow>=5.0.0, <=8.0|g' setup.py && \
            pip install -v -r requirements/docker.txt && \
            pip install -v -e .

# WORKDIR     /app

# RUN         mkdir -p superset/translations && \
#             flask fab babel-compile --target /usersuperset/translations

###

FROM        superset-base as superset-node
# FROM        node:16 AS superset-node

WORKDIR     /app

COPY        superset-frontend/package.json /app/superset-frontend/
RUN         cd /app \
            mkdir -p superset/static \
            touch superset/static/version_info.json


RUN         mkdir -p /app/superset-frontend
RUN         mkdir -p /app/superset/assets

COPY        ./docker/frontend-mem-nag.sh /
COPY        ./superset-frontend /app/superset-frontend

RUN         /frontend-mem-nag.sh && \
            cd /app/superset-frontend && \
            npm ci

# This seems to be the most expensive step
RUN         cd /app/superset-frontend && \
            npm run build && \
            rm -rf node_modules

###

FROM        ${base}

ENV         LANG=C.UTF-8
ENV         LC_ALL=C.UTF-8
ENV         FLASK_ENV=production
ENV         FLASK_APP="superset.app:create_app()"
ENV         PYTHONPATH="/app/pythonpath"
ENV         SUPERSET_HOME="/app/superset_home"
ENV         SUPERSET_PORT=8088

EXPOSE      ${SUPERSET_PORT}/tcp
HEALTHCHECK CMD curl -f "http://localhost:$SUPERSET_PORT/health"

WORKDIR     /app

RUN         apk add --virtual .run-deps \
                build-essential \
                default-libmysqlclient-dev \
                libsasl2-modules-gssapi-mit \
                libpq-dev \
                libecpg-dev \


                # 1.19.4
            useradd --user-group -d ${SUPERSET_HOME} -m --no-log-init --shell /bin/bash superset

COPY        --from=superset-base --chown=superset /app/superset
COPY        --from=superset-base --chown=superset ./docker/docker-bootstrap.sh /app/docker/
COPY        --from=superset-base --chown=superset ./docker/docker-init.sh /app/docker/
COPY        --from=superset-base --chown=superset ./docker/docker-ci.sh /app/docker/
COPY        --from=superset-base --chown=superset ./docker/run-server.sh /usr/bin/
COPY        --from=superset-py --chown=superset /usr/local/lib/python3.8/site-packages/ /usr/local/lib/python3.8/site-packages/
COPY        --from=superset-py --chown=superset /usr/local/bin/gunicorn /usr/local/bin/celery /usr/local/bin/flask /usr/bin/
COPY        --from=superset-node --chown=superset /app/superset/static/assets /app/superset/static/assets
COPY        --from=superset-node --chown=superset /app/superset-frontend /app/superset-frontend

USER        superset

# RUN         chmod a+x /app/docker/*.sh
# CMD         /app/docker/docker-ci.sh
RUN         chmod a+x /usr/bin/run-server.sh
CMD         /usr/bin/run-server.sh
RUN         chmod a+x /app/docker/*.sh
CMD         /app/docker/docker-ci.sh