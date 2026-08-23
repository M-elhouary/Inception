#!/bin/sh

set -e

WP_PATH="/var/www/html"

DB_NAME="wordpress"
DB_USER="wp_user"
DB_HOST="mariadb"

DB_PASSWORD="$(cat /run/secrets/db_password)"
WP_ADMIN_PASSWORD="$(cat /run/secrets/wp_admin_password)"

WP_URL="${WP_URL:-https://localhost}"
WP_TITLE="${WP_TITLE:-Inception}"
WP_ADMIN_USER="${WP_ADMIN_USER:-admin}"
WP_ADMIN_EMAIL="${WP_ADMIN_EMAIL:-admin@example.com}"

mkdir -p "$WP_PATH"
chown -R www-data:www-data "$WP_PATH"

cd "$WP_PATH"

if [ ! -f "$WP_PATH/wp-load.php" ]; then
    wp core download \
        --allow-root
fi

if [ ! -f "$WP_PATH/wp-config.php" ]; then
    wp config create \
        --dbname="$DB_NAME" \
        --dbuser="$DB_USER" \
        --dbpass="$DB_PASSWORD" \
        --dbhost="$DB_HOST" \
        --allow-root
fi

echo "Waiting for MariaDB..."

until php -r "
\$connection = @new mysqli(
    getenv('DB_HOST'),
    getenv('DB_USER'),
    getenv('DB_PASSWORD'),
    getenv('DB_NAME')
);

exit(\$connection->connect_errno ? 1 : 0);
"; do
    sleep 2
done

echo "MariaDB is ready."

if ! wp core is-installed --allow-root; then
    wp core install \
        --url="$WP_URL" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email \
        --allow-root
fi

chown -R www-data:www-data "$WP_PATH"

exec "$@"