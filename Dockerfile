ARG         base=alpine

###

FROM        ${base} as build

ARG         version=
ARG         repo=

RUN         apk add --no-cache --virtual .build-deps \
                build-base && \
            wget -O - https://github.com/${repo}/archive/refs/tags/v${version}.tar.gz | tar xz

###

FROM        ${base}

COPY        --from=build /usr/local/bin /usr/local/bin
COPY        --from=build /usr/local/include /usr/local/include
COPY        --from=build /usr/local/lib /usr/local/lib