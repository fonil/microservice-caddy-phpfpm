# syntax=docker/dockerfile:1

# STAGE #########################################################

FROM caddy:2.7.6-builder-alpine as caddy-builder

RUN xcaddy build \
    --with github.com/baldinof/caddy-supervisor


# STAGE #########################################################

FROM php:8.3.2-fpm-alpine as base

RUN apk update && apk add --no-cache \
        caddy \
        fcgi \
        nss-tools

# XCaddy requires those ENV vars to store files on proper path
# @see: https://caddy.community/t/caddy-php-fpm-is-not-accessible-from-host/22745
ENV XDG_CONFIG_HOME /config
ENV XDG_DATA_HOME /data

COPY --from=caddy-builder /usr/bin/caddy /usr/sbin/caddy

WORKDIR /code

CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]


# STAGE #########################################################

FROM php:8.3.2-fpm-alpine as build-development-extensions

RUN curl -sSL https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions -o - | sh -s \
        pcov \
        uopz


# STAGE #########################################################

FROM composer as optimize-dependencies

COPY ./src/composer.json ./src/composer.lock /app/

RUN composer install \
    --ignore-platform-reqs \
    --no-ansi \
    --no-autoloader \
    --no-interaction \
    --no-scripts \
    --prefer-dist \
    --no-dev
    
COPY ./src/ /app/

RUN composer dump-autoload \
	--optimize \
	--classmap-authoritative


# STAGE #########################################################

FROM base AS build-production

ENV ENV=PRODUCTION

RUN apk update && apk add --no-cache \
        bash \
    && mkdir /output \ 
    && chown www-data:www-data /output

COPY --from=optimize-dependencies --chown=www-data:www-data /app /code

COPY ./build/usr/local/etc/php-fpm.d/www.conf /usr/local/etc/php-fpm.d/www.conf
RUN sed -i -r "s/USER-NAME/www-data/g" /usr/local/etc/php-fpm.d/www.conf \
    && sed -i -r "s/GROUP-NAME/www-data/g" /usr/local/etc/php-fpm.d/www.conf

COPY ./build/etc/Caddyfile /etc/caddy/Caddyfile


# STAGE #########################################################

FROM base as build-development

ARG HOST_USER_ID=1000
ARG HOST_USER_NAME=host-user-name

ARG HOST_GROUP_ID=1000
ARG HOST_GROUP_NAME=host-group-name

ENV ENV=DEVELOPMENT

COPY --from=composer /usr/bin/composer /usr/bin/composer

COPY --from=build-development-extensions /usr/local/lib/php/extensions/*/* /usr/local/lib/php/extensions/no-debug-non-zts-20230831/
COPY --from=build-development-extensions /usr/local/etc/php/conf.d/* /usr/local/etc/php/conf.d/

RUN apk update && apk add --no-cache \
        bash \
        util-linux

RUN addgroup --gid ${HOST_GROUP_ID} ${HOST_GROUP_NAME} \
    && adduser --shell /bin/bash --uid ${HOST_USER_ID} --ingroup ${HOST_GROUP_NAME} --ingroup www-data --disabled-password --gecos '' ${HOST_USER_NAME}

COPY ./build/usr/local/etc/php-fpm.d/www.conf /usr/local/etc/php-fpm.d/www.conf
RUN sed -i -r "s/USER-NAME/${HOST_USER_NAME}/g" /usr/local/etc/php-fpm.d/www.conf \
    && sed -i -r "s/GROUP-NAME/${HOST_GROUP_NAME}/g" /usr/local/etc/php-fpm.d/www.conf

