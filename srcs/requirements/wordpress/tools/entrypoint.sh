#!/bin/sh

set -eu

WP_PATH="/var/www/html"

DB_NAME="${DB_NAME:-wordpress}"
DB_USER="${DB_USER:-wp_user}"
DB_HOST="${DB_HOST:-mariadb}"

WP_URL="${WP_URL:-https://mel-houa.42.fr}"
WP_TITLE="${WP_TITLE:-Inception}"
WP_ADMIN_USER="${WP_ADMIN_USER:-mel-houa}"
WP_ADMIN_EMAIL="${WP_ADMIN_EMAIL:-mel-houa@42.fr}"
WP_NORMAL_USER="${WP_NORMAL_USER:-regular_user}"

DB_PASSWORD="$(cat /run/secrets/db_password)"
WP_ADMIN_PASSWORD="$(cat /run/secrets/wp_admin_password)"
WP_NORMAL_PASSWORD="$(cat /run/secrets/wp_normal_password)"

if [ -z "$DB_PASSWORD" ] || [ -z "$WP_ADMIN_PASSWORD" ] || [ -z "$WP_NORMAL_PASSWORD" ]; then
    echo "Error: a required secret is empty" >&2
    exit 1
fi

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

if ! wp user get "$WP_NORMAL_USER" \
    --field=user_login \
    --path="$WP_PATH" \
    --allow-root >/dev/null 2>&1
then
    echo "Creating second (non-administrator) user: $WP_NORMAL_USER"

    wp user create \
        "$WP_NORMAL_USER" \
        "$WP_NORMAL_USER@42.fr" \
        --user_pass="$WP_NORMAL_PASSWORD" \
        --role=subscriber \
        --path="$WP_PATH" \
        --allow-root
fi

chown -R www-data:www-data "$WP_PATH"

echo "Starting PHP-FPM..."

exec "$@"
