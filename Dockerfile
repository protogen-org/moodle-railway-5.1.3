# Official PHP image pinned to a release patched for PHP2Shell (CVE-2026-109618/109619).
# moodlehq/moodle-php-apache had not shipped a patched 8.3 build at the time of this change.
FROM php:8.3.36-apache-bookworm

# Fail the build if PHP is older than the PHP2Shell fix
RUN php -r 'exit(version_compare(PHP_VERSION, "8.3.36", "<") ? 1 : 0);' \
 || (echo "PHP $(php -r 'echo PHP_VERSION;') is vulnerable to PHP2Shell; need >= 8.3.36" && exit 1)

# PHP extensions required by Moodle 5.1 (Postgres backend)
COPY --from=mlocati/php-extension-installer:2 /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions pgsql intl zip gd soap exif opcache \
 && apt-get update && apt-get install -y --no-install-recommends git \
 && rm -rf /var/lib/apt/lists/*

# Moodle-required PHP settings
RUN cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
 && { echo 'max_input_vars = 5000'; \
      echo 'memory_limit = 256M'; \
      echo 'upload_max_filesize = 100M'; \
      echo 'post_max_size = 100M'; } > "$PHP_INI_DIR/conf.d/moodle.ini"

# Clone Moodle 5.1.3 by tag and remove .git to reduce image size
RUN git clone --depth 1 -b v5.1.3 https://github.com/moodle/moodle.git /var/www/moodle \
 && rm -rf /var/www/moodle/.git \
 && chown -R www-data:www-data /var/www/moodle

ENV APACHE_DOCUMENT_ROOT=/var/www/moodle/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
 && sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
