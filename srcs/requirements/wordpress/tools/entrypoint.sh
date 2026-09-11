#!/bin/sh
set -eu

. /usr/local/bin/wordpress.conf

DB_PASSWORD="$(cat /run/secrets/db_password)"
WP_ADMIN_PASSWORD="$(cat /run/secrets/wp_admin_password)"
WP_NORMAL_PASSWORD="$(cat /run/secrets/wp_normal_password)"


mkdir -p "$WP_PATH"
cd "$WP_PATH"

wp() { command wp --allow-root --path="$WP_PATH" "$@"; }

if [ ! -f wp-load.php ]; then
    wp core download
fi

if [ ! -f wp-config.php ]; then
    wp config create --dbname="$DB_NAME" --dbuser="$DB_USER" \
        --dbpass="$DB_PASSWORD" --dbhost="$DB_HOST" --skip-check
fi


if ! wp core is-installed; then
    wp core install --url="$WP_URL" --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" --skip-email
fi

if ! wp user get "$WP_NORMAL_USER" >/dev/null 2>&1; then
    wp user create "$WP_NORMAL_USER" "$WP_NORMAL_USER@42.fr" \
        --user_pass="$WP_NORMAL_PASSWORD" --role=subscriber
fi

chown -R www-data:www-data "$WP_PATH"
exec "$@"