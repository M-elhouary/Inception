#!/bin/sh
set -eu

: "${MYSQL_DATABASE:?MYSQL_DATABASE is required}"
: "${MYSQL_USER:?MYSQL_USER is required}"

DB_PASSWORD="$(cat /run/secrets/db_password)"
DB_ROOT_PASSWORD="$(cat /run/secrets/db_root_password)"

if [ -z "$DB_PASSWORD" ] || [ -z "$DB_ROOT_PASSWORD" ]; then
    echo "Error: passwords cannot be empty" >&2
    exit 1
fi

case "$MYSQL_DATABASE" in
    *[!A-Za-z0-9_]*)
        echo "Error: invalid MYSQL_DATABASE" >&2
        exit 1
        ;;
esac

case "$MYSQL_USER" in
    *[!A-Za-z0-9_]*)
        echo "Error: invalid MYSQL_USER" >&2
        exit 1
        ;;
esac

install -d -m 0755 -o mysql -g mysql /run/mysqld
install -d -m 0755 -o mysql -g mysql /var/lib/mysql

if [ ! -d /var/lib/mysql/mysql ]; then
    echo "Initializing MariaDB..." 

    mariadb-install-db \
        --user=mysql \
        --datadir=/var/lib/mysql \
        --auth-root-authentication-method=normal

    DB_PASSWORD_SQL="$(printf '%s' "$DB_PASSWORD" | sed "s/'/''/g")"
    DB_ROOT_PASSWORD_SQL="$(printf '%s' "$DB_ROOT_PASSWORD" | sed "s/'/''/g")"

    umask 077

    cat > /tmp/mariadb-init.sql <<SQL
SET SESSION sql_mode = 'NO_BACKSLASH_ESCAPES';
ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_ROOT_PASSWORD_SQL';
CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\`;
CREATE USER IF NOT EXISTS '$MYSQL_USER'@'%' IDENTIFIED BY '$DB_PASSWORD_SQL';
GRANT ALL PRIVILEGES ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%';
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
SQL

    chown mysql:mysql /tmp/mariadb-init.sql

    exec "$@" \
        --user=mysql \
        --init-file=/tmp/mariadb-init.sql
fi

rm -f /tmp/mariadb-init.sql

exec "$@" --user=mysql