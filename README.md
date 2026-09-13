*This project has been created as part of the 42 curriculum by mel-houa.*

# Inception

## Description

Inception is a system-administration project that teaches containerization and infrastructure design with **Docker** and **Docker Compose**. The goal is to build a small, self-contained web infrastructure running inside a virtual machine, entirely from custom Docker images — no ready-made service images from Docker Hub are allowed (except the Alpine/Debian base).

The final stack exposes a single HTTPS entry point and is composed of three dedicated containers:

| Container | Role | Listens on |
|---|---|---|
| **NGINX** | Reverse proxy + TLS termination, the only public-facing entry point | host port `443` (TLS 1.2 / TLS 1.3) |
| **WordPress + PHP-FPM** | Serves the website and processes PHP; contains no NGINX | internal only |
| **MariaDB** | Private database used by WordPress; not reachable from the host | internal only |

Two dedicated Docker named volumes provide persistence: one for the WordPress database (`/var/lib/mysql`) and one for the WordPress website files (`/var/www/html`). Their data is stored on the VM host under `/home/mel-houa/data`. A dedicated Docker bridge network connects the containers, which communicate by service name.

### Architecture

```
                 HTTPS (443)
                      |
                      v
            +-------------------+
            |      NGINX        |   reverse proxy + TLS
            |  (host: 443)      |
            +-------------------+
                      |
              fastcgi | service name `wordpress:9000`
                      v
            +-------------------+
            | WordPress + PHP   |   wp-cli, php-fpm8.2
            | (internal only)   |
            +-------------------+
                      |
              mariadb | service name `mariadb:3306`
                      v
            +-------------------+
            |     MariaDB       |   private database
            | (internal only)   |
            +-------------------+

  Persistent volumes (host dirs under /home/mel-houa/data):
    wordpress_data  -> /home/mel-houa/data/wordpress
    mariadb_data    -> /home/mel-houa/data/mariadb
```

### Use of Docker and the sources included

Docker is used to isolate each service into its own container, each built from its own `Dockerfile` inside `srcs/requirements/`:

| Service | Container role | Source directory |
|---|---|---|
| MariaDB | Database | `srcs/requirements/mariadb` |
| WordPress + PHP-FPM | Web application | `srcs/requirements/wordpress` |
| NGINX | Reverse proxy + TLS | `srcs/requirements/nginx` |

The included sources are limited to what each service needs: a `Dockerfile`, an entrypoint script under `tools/`, and a configuration file under `conf/`. Secrets and ordinary configuration are stored outside the images and provided at runtime.

Each image starts from `debian:bookworm` and installs only the required packages (`nginx`, `openssl`; `php-fpm` + PHP extensions + `wp-cli`; `mariadb-server`). The `.dockerignore` files ensure `.env`, `secrets`, `.git`, and docs never enter a build context.

### Main design choices

- **One process per container.** Each container runs its real foreground daemon as PID 1 using `exec` (e.g. `mariadbd`, `php-fpm8.2 -F`, `nginx -g "daemon off;"`) so it can receive Docker stop/reload signals correctly. No `tail -f`, `sleep infinity`, or infinite-loop keeps it alive.
- **NGINX as the single entry point.** Only NGINX publishes port `443`. WordPress and MariaDB are internal-only.
- **Persistent volumes.** The two mandatory named volumes are bound to real host directories under `/home/mel-houa/data`, so data survives container recreation.
- **Secrets for credentials.** Passwords live in untracked files under `secrets/`, mounted at runtime under `/run/secrets/`, never baked into an image layer and never committed to Git.
- **Health-gated startup.** MariaDB has a `healthcheck`; WordPress `depends_on` it with `condition: service_healthy`, so WordPress only starts once the database accepts connections.
- **`restart: unless-stopped`.** Containers come back automatically after a crash or a host reboot.

### Comparison: Virtual Machines vs Docker

A **virtual machine** virtualizes the hardware and runs a full guest operating system with its own kernel. It is heavy, starts slowly, and isolates at the kernel boundary. **Docker** is more modern and lightweight: it virtualizes at the operating-system level, sharing the host kernel, but isolating processes, filesystems, and networks in containers. Containers start in seconds and use far fewer resources. However, a container is **not** a virtual machine — it has no kernel of its own and depends on the host kernel.

### Comparison: Secrets vs Environment Variables

**Environment variables** are suitable for non-confidential configuration such as a domain name or a database name; they are visible inside the process environment and can leak into logs or debugging output. **Docker secrets** are mounted as read-only files under `/run/secrets/` and are the recommended place for confidential values such as passwords. Secrets stay out of the image layers, are not committed to Git, and are the correct place for credentials like the WordPress or database admin passwords.

### Comparison: Docker Network vs Host Network

With the default **bridge network**, containers receive their own isolated network namespace and communicate with one another using service names and internal IPs; nothing is exposed to the host unless a port is explicitly published. **Host networking** (`network_mode: host`) shares the host's network stack directly, which removes that isolation and is forbidden by this subject. This project uses a dedicated user-defined bridge network, with only NGINX publishing port `443`.

### Comparison: Docker Volumes vs Bind Mounts

A **Docker named volume** is managed entirely by Docker: you reference it by name and Docker stores it in its own area (or, as here, redirects it to a host path). A **bind mount** maps an arbitrary host directory directly into a container at a chosen path. This subject requires the two persistent storages to be **Docker named volumes**, and their data must live under `/home/mel-houa/data`. Our Compose file declares named volume entries that are backed by host directories for inspection, satisfying both requirements.

## Quick start

1. **Install the prerequisites** (see below).
2. **Create the secret files** (one per credential, one password per line):

   ```bash
   mkdir -p secrets
   printf 'db-password-here\n' > secrets/db_password.txt
   printf 'root-password-here\n' > secrets/db_root_password.txt
   printf 'admin-password-here\n' > secrets/wp_admin_password.txt
   printf 'user-password-here\n' > secrets/wp_user_password.txt
   chmod 600 secrets/*
   ```

   Use a different, strong password for each. These files are ignored by Git (`/secrets/*.txt`) and must never be committed.

3. **Point your domain at the VM** — add the VM's IP (or `127.0.0.1` if browsing on the VM itself) to `/etc/hosts`:

   ```text
   127.0.0.1 mel-houa.42.fr
   ```

4. **Build and start:**

   ```bash
   make
   ```

5. **Open** `https://mel-houa.42.fr` in a browser and accept the self-signed certificate warning.

## Instructions

### Prerequisites

- Linux virtual machine (the whole project runs inside a VM).
- Docker Engine and Docker Compose (with the `docker compose` v2 plugin).
- Root or `sudo` privileges to create the host data directories.

Verify the tools are available:

```bash
docker --version
docker compose version
```

### Configuration reference

Everything is configured from two places — one file of **non-secret** variables and a folder of **secret** files.

**`srcs/.env`** (non-secret configuration, committed):

| Variable | Default | Used by | Purpose |
|---|---|---|---|
| `DOMAIN_NAME` | `mel-houa.42.fr` | NGINX, WordPress | Public domain; must match `/etc/hosts` |
| `MYSQL_DATABASE` | `wordpress` | MariaDB, WordPress | Database name |
| `MYSQL_USER` | `wp_user` | MariaDB, WordPress | Database user name |
| `WP_ADMIN_USER` | `mel-houa` | WordPress | WordPress admin username (created on first boot) |
| `WP_ADMIN_EMAIL` | `mel-houa@student.42.fr` | WordPress | WordPress admin email |
| `WP_NORMAL_USER` | `regular_user` | WordPress | Second WordPress user (subscriber role) |

**`secrets/*.txt`** (secret files, never committed):

| File | Mounted at | Used by | Purpose |
|---|---|---|---|
| `secrets/db_password.txt` | `/run/secrets/db_password` | MariaDB, WordPress | Password of the WordPress database user |
| `secrets/db_root_password.txt` | `/run/secrets/db_root_password` | MariaDB | Password of the MariaDB `root` account |
| `secrets/wp_admin_password.txt` | `/run/secrets/wp_admin_password` | WordPress | WordPress administrator password |
| `secrets/wp_user_password.txt` | `/run/secrets/wp_user_password` | WordPress | WordPress regular-user password |

> **Note:** changing a value in a secret file does not change the password already stored inside MariaDB or WordPress — only re-created volumes pick it up. To re-seed from scratch, use `make re` (or `make fclean && make`).

### Build and run

From the project root:

```bash
make
```

This creates the host data directories under `/home/mel-houa/data` (if missing) and runs:

```bash
docker compose --env-file srcs/.env -f srcs/docker-compose.yml up --build -d
```

### Domain name

Resolve `mel-houa.42.fr` to the VM by adding the VM's IP (or `127.0.0.1` if browsing on the VM itself) to `/etc/hosts`:

```text
127.0.0.1 mel-houa.42.fr
```

### Login accounts

After the stack is up, you can log in at `https://mel-houa.42.fr/wp-admin`:

- Admin: the `WP_ADMIN_USER` value with the password from `secrets/wp_admin_password.txt`.
- Regular user: the `WP_NORMAL_USER` value with the password from `secrets/wp_user_password.txt`.

### Manage the stack

| Command | Equivalent to / effect |
|---|---|
| `make` or `make all` | Create data dirs, then build and start the stack detached |
| `make up` | Same as `make` |
| `make ps` | Show container status and health |
| `make logs` | Follow the logs of all containers (`-f`) |
| `make down` | Stop the stack; persistent data is **kept** |
| `make clean` | Stop containers and remove project images; persistent data is kept |
| `make fclean` | Clean + delete the host data under `/home/mel-houa/data` |
| `make re` | `fclean` then build and start again (full clean rebuild) |
| `make prune` | Remove Docker system assets globally (use with caution) |

```bash
make          # build and start the stack
make logs     # follow the container logs
make ps       # show container status
make down     # stop the stack (keeps data)
make clean    # stop containers and remove project images; persistent data is kept
make fclean   # clean + delete the host data under /home/mel-houa/data
make re       # fclean then build and start again
make prune    # remove docker system assets globally (use with caution)
```

### Cleanup

`make down` stops the infrastructure without touching persistent data. Use `make fclean` only when you intentionally want to delete everything, including the WordPress and database data under `/home/mel-houa/data`.

### Useful Docker commands

```bash
# Validate / render the compose configuration
docker compose --env-file srcs/.env -f srcs/docker-compose.yml config

# Check status and health of every container
docker compose --env-file srcs/.env -f srcs/docker-compose.yml ps

# Read logs of a single service
docker compose --env-file srcs/.env -f srcs/docker-compose.yml logs nginx

# Open a shell inside a running container
docker compose --env-file srcs/.env -f srcs/docker-compose.yml exec wordpress sh

# Run a wp-cli command (install a plugin, check the site URL, ...)
docker compose --env-file srcs/.env -f srcs/docker-compose.yml \
  exec wordpress wp option get siteurl --allow-root --path=/var/www/html

# Inspect the TLS certificate inside NGINX
docker compose --env-file srcs/.env -f srcs/docker-compose.yml \
  exec nginx openssl x509 -in /etc/nginx/ssl/inception.crt -noout -subject -dates
```

## Project structure

```
Inception/
├── Makefile                         # all the make targets (up/down/clean/...)
├── secrets/                         # passwords (gitignored, created by you)
│   ├── db_password.txt
│   ├── db_root_password.txt
│   ├── wp_admin_password.txt
│   └── wp_user_password.txt
└── srcs/
    ├── .env                         # non-secret configuration
    ├── docker-compose.yml           # services, volumes, networks, secrets
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/mariadb.cnf     # bind-address, port, datadir
        │   └── tools/entrypoint.sh  # init DB + users on first boot
        ├── nginx/
        │   ├── Dockerfile
        │   ├── conf/nginx.conf      # TLS vhost, PHP fastcgi passthrough
        │   └── (no tools — uses the nginx image CMD)
        └── wordpress/
            ├── Dockerfile
            ├── conf/wordpress.conf  # requires env vars, defines WP_PATH
            └── tools/entrypoint.sh  # downloads WP, creates config + users
```

## Troubleshooting

**`make` fails on the `sudo mkdir` step.** Make sure you have `sudo` privileges, or pre-create the directories yourself: `sudo mkdir -p /home/mel-houa/data/mariadb /home/mel-houa/data/wordpress`.

**`/run/secrets/...: No such file or directory`.** The secret files are missing. Create the four files in `secrets/` as described in [Quick start](#quick-start), then `make`.

**The site shows a proxy error / "502 Bad Gateway".** Either WordPress or MariaDB is still starting. Wait for MariaDB's healthcheck to pass (WordPress starts only afterwards), then check with `make ps` and `docker compose logs wordpress`.

**The browser refuses to connect or shows the wrong certificate.** Confirm the domain in `srcs/.env` matches the `/etc/hosts` entry, that NGINX is the only published port, and that you are using `https://`. The certificate is self-signed — accept the browser warning.

**Password changed in a secret file but login fails.** Already-provisioned volumes keep the old passwords. Reset everything with `make re` (deletes data under `/home/mel-houa/data` too).

**Need a completely clean slate.** `make fclean` removes containers, images, volumes, and the host data directory; then `make` rebuilds everything from scratch.

## Resources

- Docker documentation: <https://docs.docker.com/>
- Dockerfile reference: <https://docs.docker.com/engine/reference/builder/>
- Docker Compose reference: <https://docs.docker.com/compose/compose-file/>
- Running services with `daemon off` and foreground processes: <https://docs.docker.com/engine/containers/run/>, NGINX documentation
- MariaDB: <https://mariadb.com/kb/en/>
- WordPress: <https://developer.wordpress.org/>

### How AI was used

AI was used to assist with planning the infrastructure, writing the Dockerfiles and entrypoint scripts, generating the `.env`/Compose wiring and this documentation, and troubleshooting shell and SQL logic. The generated code and configuration were reviewed, syntax-checked with `sh -n`, validated with `docker compose config`, and tested against a running stack before being accepted. AI did not author the design decisions; every choice (such as one-process-per-container, secret handling, and the two persistent volumes) was reviewed and understood.