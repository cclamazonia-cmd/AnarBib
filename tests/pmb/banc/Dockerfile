# Banc PMB (H14) — serveur applicatif selon les « Pré-requis installation
# serveur applicatif PMB 8.1 » (PMB Services, 25/02/2026) : Apache 2.4 +
# mod_php 8.3, extensions listées au § 3, poppler-utils et zip au § 4.
# Les extensions optionnelles (apcu, imagick, ldap, xdiff, yaz) sont laissées
# de côté : le banc sert à importer et exporter des notices, pas à servir un
# OPAC. yaz-marcdump (paquet yaz) est ajouté pour inspecter et transcoder les
# fichiers ISO 2709 exportés.
FROM php:8.3-apache

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libbz2-dev libfreetype6-dev libjpeg62-turbo-dev libpng-dev libwebp-dev \
      libicu-dev libxml2-dev libxslt1-dev libzip-dev \
      poppler-utils zip unzip locales yaz \
 && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
 && docker-php-ext-install -j"$(nproc)" bz2 exif ftp gd intl mysqli soap sockets xsl zip \
 && a2enmod rewrite headers \
 && sed -i 's/^# *fr_FR.UTF-8/fr_FR.UTF-8/' /etc/locale.gen && locale-gen \
 && rm -rf /var/lib/apt/lists/*

COPY php.ini /usr/local/etc/php/conf.d/zz-pmb.ini

# Le code de PMB vient de l'archive officielle, vérifiée par sa somme, et
# appartient à www-data : l'installeur écrit includes/db_param.inc.php et
# opac_css/includes/opac_db_param.inc.php, PMB écrit dans temp/.
ARG PMB_VERSION
ARG PMB_SHA256
COPY --from=pmbdl pmb${PMB_VERSION}.zip /tmp/pmb.zip
RUN echo "${PMB_SHA256}  /tmp/pmb.zip" | sha256sum -c - \
 && unzip -q /tmp/pmb.zip -d /var/www/html \
 && rm /tmp/pmb.zip \
 && chown -R www-data:www-data /var/www/html/pmb
