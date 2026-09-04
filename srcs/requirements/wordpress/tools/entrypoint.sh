#!/bin/sh

set -e

WP_PATH="/var/www/html"

DB_NAME="${DB_NAME:-wordpress}"
DB_USER="${DB_USER:-wp_user}"
DB_HOST="${DB_HOST:-mariadb}"

WP_URL="${WP_URL:-https://localhost}"
WP_TITLE="${WP_TITLE:-Inception}"
WP_ADMIN_USER="${WP_ADMIN_USER:-smohamed}"
WP_ADMIN_EMAIL="${WP_ADMIN_EMAIL:-admin@example.com}"

DB_PASSWORD="$(cat /run/secrets/db_password)"
WP_ADMIN_PASSWORD="$(cat /run/secrets/wp_admin_password)"

export DB_NAME
export DB_USER
export DB_HOST
export DB_PASSWORD

mkdir -p "$WP_PATH"

cd "$WP_PATH"

if [ ! -f "$WP_PATH/wp-load.php" ]; then
    echo "Downloading WordPress..."

    wp core download \
        --path="$WP_PATH" \
        --allow-root
fi

if [ ! -f "$WP_PATH/wp-config.php" ]; then
    echo "Creating wp-config.php..."

    wp config create \
        --path="$WP_PATH" \
        --dbname="$DB_NAME" \
        --dbuser="$DB_USER" \
        --dbpass="$DB_PASSWORD" \
        --dbhost="$DB_HOST" \
        --skip-check \
        --allow-root
fi

echo "Waiting for MariaDB..."

until php -r '
    $connection = @new mysqli(
        getenv("DB_HOST"),
        getenv("DB_USER"),
        getenv("DB_PASSWORD"),
        getenv("DB_NAME")
    );

    if ($connection->connect_errno) {
        exit(1);
    }

    $connection->close();
    exit(0);
'; do
    sleep 2
done

echo "MariaDB is ready."

if ! wp core is-installed \
    --path="$WP_PATH" \
    --allow-root
then
    echo "Installing WordPress..."

    wp core install \
        --path="$WP_PATH" \
        --url="$WP_URL" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email \
        --allow-root
fi

chown -R www-data:www-data "$WP_PATH"

echo "Starting PHP-FPM..."

exec "$@"