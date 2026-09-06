# Inception — Developer Documentation

This document explains how to set up, build, and manage the project from a developer perspective.

## Prerequisites and setup from scratch

- A Linux virtual machine.
- Docker Engine and Docker Compose (the modern `docker compose` v2 plugin).
- `sudo` privileges.

Verify the tools are available:

```bash
docker --version
docker compose version
```

### Configure the local files

1. **`srcs/.env`** — edit it and replace the values with your own login. It contains **non-secret** configuration only. For this project:

   ```env
   LOGIN=mel-houa
   DOMAIN_NAME=mel-houa.42.fr
   DATA_PATH=/home/mel-houa/data
   MYSQL_DATABASE=wordpress
   MYSQL_USER=wp_user
   WP_ADMIN_USER=mel-houa
   WP_ADMIN_EMAIL=mel-houa@42.fr
   WP_NORMAL_USER=regular_user
   ```

2. **`secrets/`** — create a plain-text file per credential, one password per line (no trailing newline required):

   ```text
   secrets/db_password.txt
   secrets/db_root_password.txt
   secrets/wp_admin_password.txt
   secrets/wp_user_password.txt
   ```

   Set restrictive permissions:

   ```bash
   chmod 600 secrets/*.txt
   ```

   These files are matched by `.gitignore` (`/secrets/*.txt`) and must **never** be committed. Removing passwords from a later commit does not remove them from history; if one is ever committed, rotate the password and rewrite history.

3. The `.dockerignore` files inside each `srcs/requirements/*/` ensure `.env`, `secrets`, `.git`, and documentation are excluded from the build contexts.

## How to build and launch

From the project root, the Makefile drives Docker Compose:

```bash
make
```

`make up` performs, in this order:

1. Creates the host directories `/home/mel-houa/data/mariadb` and `/home/mel-houa/data/wordpress`.
2. Runs `docker compose --env-file srcs/.env -f srcs/docker-compose.yml up --build -d`.

Each service is built from its own `Dockerfile` and its image is named after the service. The Makefile targets are:

| Target | Behavior |
|---|---|
| `make` / `make up` | Build and start the stack |
| `make down` | Stop the stack (keeps data) |
| `make logs` | Follow logs |
| `make ps` | Show status |
| `make clean` | `down` + remove images (`--rmi all`) and volumes |
| `make fclean` | `clean` + delete `/home/mel-houa/data` |
| `make re` | `fclean` then `make` |
| `make prune` | `docker system prune -af` (global; use with care) |

## Useful commands for containers, images, networks and volumes

```bash
docker compose --env-file srcs/.env -f srcs/docker-compose.yml config   # validate/render config
docker compose --env-file srcs/.env -f srcs/docker-compose.yml ps       # status + health
docker compose --env-file srcs/.env -f srcs/docker-compose.yml logs -f  # live logs
docker compose --env-file srcs/.env -f srcs/docker-compose.yml exec wordpress wp option get siteurl --allow-root --path=/var/www/html
docker image ls
docker network inspect srcs_inception
docker volume ls
docker volume inspect srcs_mariadb_data srcs_wordpress_data
```

The WordPress CLI (`wp`) is available inside the `wordpress` container and is used by the entrypoint to download, configure, and install WordPress and to create the users.

## Where the data is stored and how persistence works

Two **Docker named volumes** provide persistence:

- `srcs_mariadb_data` → mounted at `/var/lib/mysql` inside the MariaDB container.
- `srcs_wordpress_data` → mounted at `/var/www/html` inside the WordPress and NGINX containers.

Both named volumes are configured with `driver_opts` binding them to real host directories:

```text
/home/mel-houa/data/mariadb
/home/mel-houa/data/wordpress
```

The MariaDB entrypoint initializes the database **only on the first start** (when the internal `mysql` system database is absent). On later starts it skips initialization, so the database, the WordPress files, the WordPress installation, and both WordPress users survive container deletion and recreation. `make down` and plain `docker compose down` preserve this data; only `make clean`/`make fclean` (which use `--volumes` and remove the host directories) delete it.
