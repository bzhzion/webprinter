FROM php:8.2-apache

RUN apt-get update \
    && apt-get install -y cups-client sane-utils sane-airscan \
    && a2enmod rewrite \
    && rm -rf /var/lib/apt/lists/*

RUN { \
        echo 'display_errors = Off'; \
        echo 'display_startup_errors = Off'; \
        echo 'log_errors = On'; \
        echo 'error_reporting = E_ALL'; \
        echo 'max_execution_time = 180'; \
    } > /usr/local/etc/php/conf.d/webprinter.ini

# sane-airscan ships /etc/sane.d/airscan.conf owned by root; www-data (PHP)
# needs to rewrite it from the configured scanner list before each scan.
RUN touch /etc/sane.d/airscan.conf \
    && chown www-data:www-data /etc/sane.d/airscan.conf

WORKDIR /var/www/html

COPY . /var/www/html

RUN chown -R www-data:www-data /var/www/html

# Version resolue depuis le tag git par la CI : exposee via health.php sur presentation
# de X-Health-Token. Elle ne sert PAS au cache-busting du CSS (voir plus bas).
ARG APP_VERSION=dev
ENV APP_VERSION=$APP_VERSION

# Cache-busting du CSS : empreinte tiree du CONTENU du fichier, jamais de la version. Cette
# valeur est lisible publiquement, et une empreinte de version se renverse en hachant toutes
# les vX.Y.Z plausibles (de l'ordre de cent mille), ce qui redonnerait la version que health.php ne
# livre que sur jeton. Calculee apres le COPY du fichier.
# Ancre sur le guillemet fermant pour rester idempotent si la commande est rejouee.
RUN ASSET_V=$(sha256sum /var/www/html/style.css | cut -c1-8) && sed -i "s|\"style\.css\"|\"style.css?v=${ASSET_V}\"|g" /var/www/html/*.php

EXPOSE 80
