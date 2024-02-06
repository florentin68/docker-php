# PHP 8.2
ARG VERSION=8.2
FROM php:$VERSION-fpm-bullseye

LABEL authors="Florentin Munsch <flo.m68@gmailc.om>"
LABEL company="KMSF"
LABEL website="www.munschflorentin.fr"
LABEL version="1.1"

ARG UID=82 \
    GID=82

# Set defaults for variables used by run.sh
# If you change MAX_EXECUTION TIME, also change fastcgi_read_timeout accordingly in nginx!
ENV DEBIAN_FRONTEND=noninteractive \
    UID=${UID} \
    GID=${GID} \
    TZ=Europe/Paris \
    MEMORY_LIMIT=256M \
    MAX_EXECUTION_TIME=90 \
    PORT=9000 \
    COMPOSER_HOME=/var/.composer \
    PHP_INI_DIR=/usr/local/etc/php

# PHP extensions
RUN apt-get update -q -y \
 && apt-get install -q -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages --no-install-recommends \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libxpm-dev \
        libpng-dev \
        libicu-dev \
        libxslt1-dev \
        libonig-dev \
        mariadb-client \
        curl \
        wget \
        ca-certificates \
        apt-utils \
#        less \
#        vim \
#        git \
#        shadow \
        acl \
        sudo \
        tree \
        libzip-dev \
        unzip \
        && rm -rf /var/lib/apt/lists/*

# Redis
RUN pecl install redis \
    && pecl install xdebug \
    && docker-php-ext-enable redis xdebug

# Memcached
RUN apt-get update && apt-get install -y libmemcached-dev zlib1g-dev \
    && pecl install memcached \
    && docker-php-ext-enable memcached

# APCu
RUN pecl install apcu \
    && docker-php-ext-enable apcu \
    && pecl clear-cache
    #&& touch $PHP_INI_DIR/conf.d/apcu.ini \
    #&& echo "apc.enabled=1" >> $PHP_INI_DIR/conf.d/apcu.ini \
    #&& echo "apc.enable_cli=1" >> $PHP_INI_DIR/conf.d/apcu.ini

# Install and configure php plugins
RUN docker-php-ext-configure mysqli --with-mysqli=mysqlnd \
 && docker-php-ext-configure pdo_mysql --with-pdo-mysql=mysqlnd \
 && docker-php-ext-configure gd --enable-gd-jis-conv --with-freetype --with-jpeg \
 && docker-php-ext-install exif gd mbstring intl xsl zip mysqli pdo_mysql \
 && docker-php-ext-enable opcache 
# && docker-php-ext-configure pgsql \
# && docker-php-ext-install pgsql pdo_pgsql

# Create Composer directory (cache and auth files)
RUN mkdir -p $COMPOSER_HOME

# Set timezone
RUN echo $TZ > /etc/timezone && dpkg-reconfigure --frontend $DEBIAN_FRONTEND tzdata

# Create PHP conf.d directory
RUN mkdir -p $PHP_INI_DIR/conf.d

# Use the default production configuration
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Set some php.ini config
RUN sed -i "s@^;date.timezone =@date.timezone = $TZ@" $PHP_INI_DIR/php.ini \
 && sed -i "s@^memory_limit = 128M@memory_limit = $MEMORY_LIMIT@" $PHP_INI_DIR/php.ini \
 && sed -i "s@^max_execution_time = 30@max_execution_time = $MAX_EXECUTION_TIME@" $PHP_INI_DIR/php.ini

# Use the default development configuration
RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"

# Disable daemonizeing php-fpm
RUN sed -i "s@^;daemonize = yes*@daemonize = no@" /usr/local/etc/php-fpm.conf

# Add pid file to be able to restart php-fpm
RUN sed -i "s@^\[global\]@\[global\]\n\npid = /var/run/php-fpm/php-fpm.pid@" /usr/local/etc/php-fpm.conf

# Set listen socket for php-fpm
RUN sed -i "s@^listen = 127.0.0.1:9000@listen = $PORT@" /usr/local/etc/php-fpm.d/www.conf.default \
 && sed -i "s@^user = nobody@user = www-data@" /usr/local/etc/php-fpm.d/www.conf.default \
 && sed -i "s@^group = nobody@group = www-data@" /usr/local/etc/php-fpm.d/www.conf.default

# Get Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin && mv /usr/local/bin/composer.phar /usr/local/bin/composer

#ADD config/opcache.ini $PHP_INI_DIR/conf.d/docker-php-ext-opcache.ini

# Create user, directories and update permissions
RUN usermod -u $UID www-data && groupmod -g $GID www-data \
    && mkdir -p /var/www \
    && chown -R www-data:www-data /var/www \
    && rm -rf /var/log/* \
    && chown -R www-data:www-data /var/log

VOLUME /var/www

WORKDIR /var/www

EXPOSE 9000

# PID file
RUN mkdir -p /var/run/php-fpm
RUN chown -R www-data:www-data /var/run/php-fpm
RUN chmod -R uga+rw /var/run/php-fpm

USER www-data:www-data

# Start PHP FPM
CMD ["php-fpm", "-F"]