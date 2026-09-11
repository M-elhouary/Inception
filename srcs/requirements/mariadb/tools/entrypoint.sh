#!/bin/sh
set -eu

DB_PASSWORD="$(cat /run/secrets/db_password)"
DB_ROOT_PASSWORD="$(cat /run/secrets/db_root_password)"


install -d -m 0755 -o mysql -g mysql /run/mysqld
install -d -m 0755 -o mysql -g mysql /var/lib/mysql

if [ ! -d /var/lib/mysql/mysql ]; then
    mariadb-install-db \
        --user=mysql \
        --datadir=/var/lib/mysql \
        --auth-root-authentication-method=normal


    umask 077

    cat > /tmp/mariadb-init.sql <<SQL
SET SESSION sql_mode = 'NO_BACKSLASH_ESCAPES';
ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_ROOT_PASSWORD';
DELETE FROM mysql.user
WHERE User = 'root'
AND Host <> 'localhost';
CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\`;
CREATE USER IF NOT EXISTS '$MYSQL_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.user WHERE User = '';
FLUSH PRIVILEGES;
SQL

    chown mysql:mysql /tmp/mariadb-init.sql

    exec "$@" \
        --user=mysql \
        --init-file=/tmp/mariadb-init.sql
fi

exec "$@" --user=mysql 