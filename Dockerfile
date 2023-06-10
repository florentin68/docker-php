# PHP 8.2
ARG VERSION=8.2
FROM php:$VERSION-fpm

# Set defaults for variables used by run.sh
# If you change MAX_EXECUTION TIME, also change fastcgi_read_timeout accordingly in nginx!
ENV DEBIAN_FRONTEND=noninteractive \
    TIMEZONE=Europe/Paris \
    MEMORY_LIMIT=256M \
    MAX_EXECUTION_TIME=90 \
    PORT=9000 \
    COMPOSER_HOME=/var/.composer \
    PHP_INI_DIR=/usr/local/etc/php

# PHP extensions
RUN apt-get update -q -y \
 && apt-get install -q -y --force-yes --no-install-recommends \
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
#        less \
#        vim \
#        git \
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
    
# Install and configure php plugins
RUN docker-php-ext-configure mysqli --with-mysqli=mysqlnd \
 && docker-php-ext-configure pdo_mysql --with-pdo-mysql=mysqlnd \
 && docker-php-ext-configure gd --enable-gd-jis-conv \
 && docker-php-ext-install exif gd mbstring intl xsl zip mysqli pdo_mysql \
 && docker-php-ext-enable opcache

# Create Composer directory (cache and auth files)
RUN mkdir -p $COMPOSER_HOME

# Set timezone
RUN echo $TIMEZONE > /etc/timezone && dpkg-reconfigure --frontend noninteractive tzdata

# Create PHP conf.d directory
RUN mkdir -p $PHP_INI_DIR/conf.d

# Use the default production configuration
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Set some php.ini config
RUN echo "date.timezone = $TIMEZONE" >> $PHP_INI_DIR/php.ini \
 && echo "memory_limit = $MEMORY_LIMIT" >> $PHP_INI_DIR/php.ini \
 && echo "realpath_cache_size = 256k" >> $PHP_INI_DIR/php.ini \
 && echo "display_errors = Off" >> $PHP_INI_DIR/php.ini \
 && echo "max_execution_time = $MAX_EXECUTION_TIME" >> $PHP_INI_DIR/php.ini

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

VOLUME /var/www/html
WORKDIR /var/www/html

EXPOSE 9000

# PID file
RUN mkdir -p /var/run/php-fpm
RUN chown -R www-data:www-data /var/run/php-fpm
RUN chmod -R uga+rw /var/run/php-fpm

USER www-data
CMD ["php-fpm", "-F"]