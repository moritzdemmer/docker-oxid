  
ARG PHP=7.1
FROM php:$PHP-apache

ARG libs="libfreetype6 libjpeg62-turbo liblz4-tool"
ARG remoteTools="rsync wget openssh-client"
ARG fontTools="fontforge ttfautohint"
ARG editors="less nano"
ARG tools="$editors $fontTools $remoteTools python3-pip nvi iproute2 ack-grep unzip git default-mysql-client sudo npm make"
ARG RUNTIME_PACKAGE_DEPS="$tools msmtp bc locales"

ARG BUILD_PACKAGE_DEPS="libcurl4-openssl-dev libjpeg-dev libpng-dev libxml2-dev"

ARG PHP_EXT_DEPS="curl json xml mbstring zip bcmath soap pdo_mysql gd mysqli"
ARG PECL_DEPS="xdebug"
ARG PHP_MEMORY_LIMIT="-1"

# install dependencies and cleanup (needs to be one step, as else it will cache in the laver)
RUN apt-get update -y \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        $RUNTIME_PACKAGE_DEPS \
        $BUILD_PACKAGE_DEPS \
    && docker-php-ext-configure gd --with-jpeg-dir=/usr/local/ \
    && docker-php-ext-install -j$(nproc) $PHP_EXT_DEPS \
    && pecl install $PECL_DEPS \
    && docker-php-source delete \
    && apt-get clean \
    && apt-get autoremove -y \
    && apt-get purge -y --auto-remove $BUILD_PACKAGE_DEPS \
    && rm -rf /var/lib/apt/lists/*

RUN sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

#install dependencies
RUN pip3 install wheel PyMySQL setuptools boto
RUN pip3 install ansible awscli

# set sendmail for php to msmtp
RUN echo "sendmail_path=/usr/bin/msmtp -t" > /usr/local/etc/php/conf.d/php-sendmail.ini

# remove memory limit
RUN echo "memory_limit = $PHP_MEMORY_LIMIT" > /usr/local/etc/php/conf.d/memory-limit-php.ini

# prepare optional xdebug ini
RUN echo "zend_extension=$(find /usr/local/lib/php/extensions/ -name xdebug.so)" > /usr/optional_xdebug.ini && \
    echo "xdebug.remote_enable=on" >> /usr/optional_xdebug.ini && \
    echo "xdebug.remote_autostart=off" >> /usr/optional_xdebug.ini

# add symlink to provide php also from /usr/bin
RUN ln -s /usr/local/bin/php /usr/bin/php

WORKDIR /var/www/oxid

# install latest composer
RUN curl --silent --show-error https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer

ENV COMPOSER_ALLOW_SUPERUSER=1
ENV COMPOSER_NO_INTERACTION=1
RUN composer global require hirak/prestissimo

RUN sed -i -e "s#/var/www/html#/var/www/OXID/source#g" /etc/apache2/sites-enabled/000-default.conf
RUN sed -i -e "s/AllowOverride None/AllowOverride All/g" /etc/apache2/apache2.conf
RUN a2enmod rewrite
