# MariaDB in Our Inception Project — Full Explanation

## What MariaDB does in this project

MariaDB is the database service behind WordPress. WordPress does not store posts, users, pages, comments, settings, or passwords inside its own container. It sends database requests to MariaDB.

```text
WordPress/PHP-FPM
       |
       | database connection: mariadb:3306
       v
MariaDB
       |
       | writes database files
       v
/var/lib/mysql
       |
       v
mariadb_data volume
       |
       v
/home/your-login/data/mariadb on the VM
```

MariaDB must be private. The browser never connects to it directly.

```text
Browser  X -> MariaDB
WordPress OK -> MariaDB
```

## Why MariaDB needs its own container

Each Inception service has one clear role:

| Container | Role |
|---|---|
| `nginx` | Receives HTTPS requests from the browser |
| `wordpress` | Runs PHP and WordPress code |
| `mariadb` | Stores and returns WordPress data |

Keeping MariaDB separate gives us:

- Independent restart and debugging.
- A private database network boundary.
- Persistent storage independent from WordPress and NGINX.
- Clear responsibility during evaluation.

## Files that create the MariaDB service

```text
Inception/
├── .gitignore
├── secrets/
│   ├── db_password.txt
│   └── db_root_password.txt
└── srcs/
    ├── .env
    ├── docker-compose.yml
    └── requirements/
        └── mariadb/
            ├── Dockerfile
            ├── conf/mariadb.cnf
            └── tools/entrypoint.sh
```

| File | Why we use it |
|---|---|
| `Dockerfile` | Builds our own MariaDB image instead of using a ready-made one |
| `mariadb.cnf` | Configures the MariaDB server itself |
| `entrypoint.sh` | Performs first-start initialization and launches MariaDB |
| `.env` | Stores non-secret configuration values |
| Secret files | Store passwords outside Dockerfile and Git |
| `docker-compose.yml` | Connects the image, volume, network, secrets, and health check |
| `.gitignore` | Prevents actual password files from being committed |

---

# 1. Dockerfile: build the MariaDB image

## Full file

`srcs/requirements/mariadb/Dockerfile`

```dockerfile
FROM debian:bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        mariadb-client \
        mariadb-server \
    && rm -rf /var/lib/apt/lists/*

COPY conf/mariadb.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["mariadbd"]
```

## `FROM debian:bookworm`

```dockerfile
FROM debian:bookworm
```

Every Docker image starts from a base image. We choose Debian Bookworm.

```text
Debian base
+ MariaDB packages
+ our configuration
+ our entrypoint
= custom MariaDB image
```

We use a fixed tag, `bookworm`, rather than `latest`, so the image is predictable and respects the subject requirement.

## Install MariaDB packages

```dockerfile
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        mariadb-client \
        mariadb-server \
    && rm -rf /var/lib/apt/lists/*
```

This runs while Docker builds the image.

| Command | Why we use it |
|---|---|
| `apt-get update` | Downloads Debian's package list |
| `mariadb-server` | Provides the actual MariaDB server binary, `mariadbd` |
| `mariadb-client` | Provides `mariadb` and `mariadb-admin` commands used for tests and initialization |
| `-y` | Accepts package installation automatically |
| `--no-install-recommends` | Avoids optional packages we do not need |
| `rm -rf /var/lib/apt/lists/*` | Removes temporary package lists to reduce image size |

The `&&` operators mean: continue only if the previous command succeeds.

## Copy our configuration and script

```dockerfile
COPY conf/mariadb.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
```

Copy the project configuration into the location MariaDB reads.

```text
Project file:   conf/mariadb.cnf
Image file:     /etc/mysql/mariadb.conf.d/50-server.cnf
```

```dockerfile
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
```

Copy the startup script into the image and make it executable. Without `chmod +x`, Docker may return `permission denied` when trying to start the container.

## Expose the internal database port

```dockerfile
EXPOSE 3306
```

This documents that MariaDB listens on internal port `3306`.

It does **not** publish the port to the VM or browser. Publishing happens only through Compose `ports:`. MariaDB has no `ports:` section.

## Entrypoint and command

```dockerfile
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["mariadbd"]
```

Together, Docker behaves as if it runs:

```sh
/usr/local/bin/entrypoint.sh mariadbd
```

The entrypoint prepares the database, then starts `mariadbd` as the final process.

## Dockerfile lifecycle

```text
docker compose build
-> Docker reads Dockerfile
-> Debian base image is prepared
-> MariaDB packages are installed
-> config and entrypoint are copied
-> custom image named mariadb is created
```

No WordPress database or password is created here. Those need runtime secrets and a persistent volume, so they belong in `entrypoint.sh`.

---

# 2. MariaDB configuration: `mariadb.cnf`

## Full file

`srcs/requirements/mariadb/conf/mariadb.cnf`

```ini
[mariadbd]
bind-address = 0.0.0.0
port = 3306
datadir = /var/lib/mysql
socket = /run/mysqld/mysqld.sock
pid-file = /run/mysqld/mysqld.pid
```

## Server configuration section

```ini
[mariadbd]
```

This means: the settings below belong to the MariaDB server process.

`[mysqld]` is also often accepted because it is the historical MySQL server name. We use `[mariadbd]` because that is the MariaDB server binary name.

## Network interface and port

```ini
bind-address = 0.0.0.0
port = 3306
```

`0.0.0.0` means MariaDB listens on all interfaces inside the container. This allows WordPress, which will be on the same Docker network, to connect to:

```text
mariadb:3306
```

This is still private because Docker Compose does not publish port `3306` to the host.

```text
Listening on 0.0.0.0 + no published port
= private Docker-network access only
```

## Database data directory

```ini
datadir = /var/lib/mysql
```

MariaDB stores all database data here. Compose mounts the persistent volume on this exact path:

```yaml
volumes:
  - mariadb_data:/var/lib/mysql
```

This is the most important persistence connection:

```text
MariaDB writes to /var/lib/mysql
-> Docker volume mariadb_data
-> /home/your-login/data/mariadb on the VM
```

## Local socket and PID file

```ini
socket = /run/mysqld/mysqld.sock
pid-file = /run/mysqld/mysqld.pid
```

The socket is a local file used for communication inside the MariaDB container. The health check can use it without exposing a network port.

The PID file contains the identifier of the running MariaDB process. It helps service tools know which process is running.

---

# 3. Configuration and secrets

## `.env`: ordinary configuration

`srcs/.env`

```env
LOGIN=your-login
DOMAIN_NAME=your-login.42.fr
DATA_PATH=/home/your-login/data

MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
```

| Variable | Why we need it |
|---|---|
| `LOGIN` | Your 42 login |
| `DOMAIN_NAME` | The final website domain used by NGINX later |
| `DATA_PATH` | Parent path for persistent host data |
| `MYSQL_DATABASE` | The database MariaDB creates for WordPress |
| `MYSQL_USER` | The restricted account WordPress uses |

Compose reads `.env` for `${VARIABLE}` substitution. We explicitly pass only `MYSQL_DATABASE` and `MYSQL_USER` into the MariaDB container.

## Secret files: passwords

```text
secrets/db_password.txt
secrets/db_root_password.txt
```

| File | Who uses it | Why |
|---|---|---|
| `db_password.txt` | WordPress and MariaDB | Password for `wpuser` |
| `db_root_password.txt` | MariaDB administrator commands | Password for MariaDB root |

These must contain different, non-empty passwords.

Compose mounts them at runtime:

```text
/run/secrets/db_password
/run/secrets/db_root_password
```

The files must not be committed to Git:

```gitignore
secrets/*.txt
!secrets/*.txt.example
```

The first rule ignores real secrets. The second rule allows safe template files such as `db_password.txt.example`.

---

# 4. Runtime logic: `entrypoint.sh`

## Why the entrypoint exists

Dockerfile instructions run at image-build time. At that moment, Docker has no mounted volume and no Docker secrets.

The entrypoint runs when the container starts. At that moment it can access:

```text
Environment variables from Compose
Secret files under /run/secrets
Persistent volume mounted at /var/lib/mysql
```

Therefore it is the correct place to initialize the database.

## Full file

`srcs/requirements/mariadb/tools/entrypoint.sh`

```sh
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
```

## Safe shell mode

```sh
#!/bin/sh
set -eu
```

`/bin/sh` is enough because the script uses standard shell syntax.

| Option | Meaning |
|---|---|
| `-e` | Stop the script when a command fails |
| `-u` | Stop the script when an undefined variable is used |

This avoids continuing with incomplete configuration.

## Required environment values

```sh
: "${MYSQL_DATABASE:?MYSQL_DATABASE is required}"
: "${MYSQL_USER:?MYSQL_USER is required}"
```

The `:` command normally does nothing. Here, it validates the variables.

If `MYSQL_DATABASE` is missing or empty, the script exits with a clear message before it tries to create an invalid database.

## Read the secrets

```sh
DB_PASSWORD="$(cat /run/secrets/db_password)"
DB_ROOT_PASSWORD="$(cat /run/secrets/db_root_password)"
```

`$(...)` runs a command and stores its output in a variable.

```text
secret file -> cat -> shell variable -> used only at runtime
```

The following condition rejects empty secrets:

```sh
if [ -z "$DB_PASSWORD" ] || [ -z "$DB_ROOT_PASSWORD" ]; then
```

`-z` means empty string. `||` means or. If either password is empty, the container stops safely.

## Validate names before SQL

```sh
case "$MYSQL_DATABASE" in
    *[!A-Za-z0-9_]*)
```

This rejects names containing characters outside letters, numbers, and underscores.

```text
wordpress      valid
wordpress_db   valid
wordpress-db   rejected
wordpress db   rejected
```

We validate names because the script inserts them into SQL commands.

## Prepare MariaDB directories

```sh
install -d -m 0755 -o mysql -g mysql /run/mysqld
install -d -m 0755 -o mysql -g mysql /var/lib/mysql
```

| Part | Meaning |
|---|---|
| `install -d` | Create a directory if it does not exist |
| `-m 0755` | Give standard directory permissions |
| `-o mysql` | Set owner to the `mysql` Linux user |
| `-g mysql` | Set group to `mysql` |

MariaDB needs `/run/mysqld` for its socket and PID file. It needs `/var/lib/mysql` for its data.

## First-start check

```sh
if [ ! -d /var/lib/mysql/mysql ]; then
```

MariaDB creates the internal `mysql` system database after it is initialized.

```text
Missing /var/lib/mysql/mysql -> empty volume -> initialize
Existing /var/lib/mysql/mysql -> existing database -> skip setup
```

This is what makes the entrypoint idempotent for normal restarts: it does not recreate the WordPress database each time.

## Create MariaDB system tables

```sh
mariadb-install-db \
    --user=mysql \
    --datadir=/var/lib/mysql \
    --auth-root-authentication-method=normal
```

This creates MariaDB's own internal tables inside the persistent data directory. It prepares the server so it can later execute SQL to create our WordPress database and user.

## Make SQL-safe password copies

```sh
DB_PASSWORD_SQL="$(printf '%s' "$DB_PASSWORD" | sed "s/'/''/g")"
```

An apostrophe has special meaning in SQL strings. This transforms one apostrophe into two, which represents a literal apostrophe inside an SQL value.

The original secret variable is unchanged. The copied value is used only in SQL.

## Create the temporary initialization SQL file

```sh
umask 077
cat > /tmp/mariadb-init.sql <<SQL
...
SQL
```

`umask 077` makes new files private by default. The heredoc writes the SQL lines into `/tmp/mariadb-init.sql`.

This file is temporary and exists only in the container filesystem. It is not inside the persistent database volume and is not a project source file.

The SQL performs these actions:

| SQL action | Why we use it |
|---|---|
| `ALTER USER root` | Gives the MariaDB root account a password |
| `CREATE DATABASE` | Creates the database WordPress will use |
| `CREATE USER` | Creates `wpuser`, the account WordPress will use |
| `GRANT` | Limits `wpuser` to the WordPress database |
| `DROP DATABASE test` | Removes the default test database |
| `FLUSH PRIVILEGES` | Reloads account and permission information |

```sql
GRANT ALL PRIVILEGES ON `wordpress`.* TO 'wpuser'@'%';
```

This means:

```text
wpuser may work with every table in wordpress
wpuser may not administer unrelated databases
```

`'%'` permits connections from a reachable container host. It does not expose MariaDB to the browser because Docker does not publish port `3306`.

## Let MariaDB execute the initialization file

```sh
chown mysql:mysql /tmp/mariadb-init.sql

exec "$@" \
    --user=mysql \
    --init-file=/tmp/mariadb-init.sql
```

MariaDB runs as the Linux `mysql` user, so the SQL file must be readable by that user.

From the Dockerfile, `$@` contains `mariadbd`. On first start, the final command is therefore:

```sh
exec mariadbd --user=mysql --init-file=/tmp/mariadb-init.sql
```

MariaDB reads the temporary file during startup, executes the SQL, then continues serving database requests.

## Later starts

When the data directory already exists, the first-start block is skipped:

```sh
rm -f /tmp/mariadb-init.sql
exec "$@" --user=mysql
```

The temporary SQL file is removed if it remains in a restarted container. MariaDB starts without `--init-file`, so it does not repeat database creation.

## Why `exec` is important

`exec` replaces the shell script process with the MariaDB server.

```text
entrypoint.sh starts as PID 1
-> exec mariadbd
-> mariadbd replaces the shell and becomes PID 1
```

If MariaDB stops, the container stops. Docker then applies the restart policy.

---

# 5. Docker Compose: connect all runtime resources

## Full MariaDB section

`srcs/docker-compose.yml`

```yaml
services:
  mariadb:
    build:
      context: ./requirements/mariadb
      dockerfile: Dockerfile
    image: mariadb
    container_name: mariadb
    restart: unless-stopped

    environment:
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}

    secrets:
      - db_password
      - db_root_password

    volumes:
      - mariadb_data:/var/lib/mysql

    networks:
      - inception

    healthcheck:
      test:
        - CMD-SHELL
        - >-
          MYSQL_PWD=$$(cat /run/secrets/db_root_password)
          mariadb-admin --user=root --protocol=socket
          --socket=/run/mysqld/mysqld.sock ping --silent
      interval: 5s
      timeout: 3s
      retries: 10
      start_period: 15s

networks:
  inception:
    driver: bridge

volumes:
  mariadb_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${DATA_PATH}/mariadb

secrets:
  db_password:
    file: ../secrets/db_password.txt
  db_root_password:
    file: ../secrets/db_root_password.txt
```

## Service name and build

```yaml
services:
  mariadb:
```

`mariadb` is both the Compose service name and the internal hostname available to other containers.

```yaml
build:
  context: ./requirements/mariadb
  dockerfile: Dockerfile
image: mariadb
```

Compose builds the custom image from our folder. `image: mariadb` gives that finished image the required name.

## Restart policy

```yaml
restart: unless-stopped
```

If the main MariaDB process crashes, Docker starts the container again. If a developer intentionally stops it, Docker leaves it stopped.

## Pass normal configuration

```yaml
environment:
  MYSQL_DATABASE: ${MYSQL_DATABASE}
  MYSQL_USER: ${MYSQL_USER}
```

Compose reads the values from `.env` and makes them available inside the container. We pass only what MariaDB needs.

## Mount secrets

```yaml
secrets:
  - db_password
  - db_root_password
```

This mounts the declared secret files under `/run/secrets`. It avoids placing actual passwords in the Dockerfile or Compose YAML.

## Mount persistent data

```yaml
volumes:
  - mariadb_data:/var/lib/mysql
```

MariaDB sees the volume at its configured `datadir`.

```text
Container path: /var/lib/mysql
Named volume:   mariadb_data
Host path:      ${DATA_PATH}/mariadb
```

The top-level volume configuration maps the named Docker volume to the required host directory.

## Private network

```yaml
networks:
  - inception
```

This attaches MariaDB to the private bridge network. WordPress will join the same network and connect to `mariadb:3306`.

There is deliberately no:

```yaml
ports:
  - "3306:3306"
```

MariaDB must not be public.

## Health check

```yaml
healthcheck:
  test:
    - CMD-SHELL
    - >-
      MYSQL_PWD=$$(cat /run/secrets/db_root_password)
      mariadb-admin --user=root --protocol=socket
      --socket=/run/mysqld/mysqld.sock ping --silent
```

The health check runs a local MariaDB ping through the socket. It proves the database is ready to accept commands.

`$$` becomes `$` inside the container. Compose needs the double dollar so it does not try to expand the shell command itself.

| Setting | Meaning |
|---|---|
| `interval: 5s` | Run the check every five seconds |
| `timeout: 3s` | One check may use at most three seconds |
| `retries: 10` | Mark unhealthy after ten failed checks |
| `start_period: 15s` | Give MariaDB time to initialize before failures count |

---

# 6. How every part works together

## Image build

```text
docker compose build
-> Dockerfile starts from Debian
-> MariaDB packages are installed
-> mariadb.cnf and entrypoint.sh are copied
-> image named mariadb is created
```

## First container start

```text
docker compose up
-> Compose creates the private network
-> Compose mounts secrets at /run/secrets
-> Compose mounts mariadb_data at /var/lib/mysql
-> entrypoint validates configuration and reads secrets
-> entrypoint detects an empty data directory
-> mariadb-install-db creates system tables
-> entrypoint creates a private temporary SQL file
-> mariadbd executes the SQL file once
-> root password, WordPress database, and wpuser are created
-> MariaDB becomes healthy
```

## Later restart

```text
MariaDB container restarts
-> same volume is mounted
-> /var/lib/mysql/mysql already exists
-> entrypoint skips initialization
-> mariadbd starts normally
-> existing WordPress data remains
```

## When WordPress arrives later

```text
WordPress starts
-> reads its database credentials
-> connects to mariadb:3306
-> MariaDB checks wpuser and db_password
-> MariaDB grants access only to the wordpress database
-> WordPress can read and save website data
```

## Security boundaries

```text
Browser
  |
  | HTTPS:443 only
  v
NGINX
  |
  v
WordPress
  |
  | private Docker network: mariadb:3306
  v
MariaDB
```

The browser does not see the database hostname, socket, secret files, or port `3306`.

## What must remain true during evaluation

- MariaDB is built from our Dockerfile, not a ready-made MariaDB image.
- Passwords are not in the Dockerfile or Git repository.
- MariaDB is not published to the host with `ports`.
- Data survives container recreation because it is in the volume.
- WordPress uses `mariadb`, not `localhost`, as the database hostname.
- The initialization SQL runs only on first start.
- `mariadbd` is the final PID 1 process.
