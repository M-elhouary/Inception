*This project has been created as part of the 42 curriculum by mel-houa.*

# Inception

## Description

Inception is a system-administration project that teaches containerization and infrastructure design with **Docker** and **Docker Compose**. The goal is to build a small, self-contained web infrastructure running inside a virtual machine, entirely from custom Docker images — no ready-made service images from Docker Hub are allowed (except the Alpine/Debian base).

The final stack exposes a single HTTPS entry point and is composed of three dedicated containers:

- **NGINX** — the only public-facing entry point, listening on host port `443` with TLS 1.2 / TLS 1.3.
- **WordPress + PHP-FPM** — serves the WordPress website and handles PHP; it contains no NGINX.
- **MariaDB** — the private database used by WordPress; it is not reachable from the host.

Two dedicated Docker named volumes provide persistence: one for the WordPress database (`/var/lib/mysql`) and one for the WordPress website files (`/var/www/html`). Their data is stored on the VM host under `/home/mel-houa/data`. A dedicated Docker bridge network connects the containers, which communicate by service name.

### Use of Docker and the sources included

Docker is used to isolate each service into its own container, each built from its own `Dockerfile` inside `srcs/requirements/`:

| Service | Container role | Source directory |
|---|---|---|
| MariaDB | Database | `srcs/requirements/mariadb` |
| WordPress + PHP-FPM | Web application | `srcs/requirements/wordpress` |
| NGINX | Reverse proxy + TLS | `srcs/requirements/nginx` |

The included sources are limited to what each service needs: a `Dockerfile`, an entrypoint script under `tools/`, and a configuration file under `conf/`. Secrets and ordinary configuration are stored outside the images and provided at runtime.

### Main design choices

- **One process per container.** Each container runs its real foreground daemon as PID 1 using `exec` (e.g. `mariadbd`, `php-fpm8.2 -F`, `nginx -g "daemon off;"`) so it can receive Docker stop/reload signals correctly. No `tail -f`, `sleep infinity`, or infinite-loop keeps it alive.
- **NGINX as the single entry point.** Only NGINX publishes port `443`. WordPress and MariaDB are internal-only.
- **Persistent volumes.** The two mandatory named volumes are bound to real host directories under `/home/mel-houa/data`, so data survives container recreation.
- **Secrets for credentials.** Passwords live in untracked files under `secrets/`, mounted at runtime under `/run/secrets/`, never baked into an image layer and never committed to Git.

### Comparison: Virtual Machines vs Docker

A **virtual machine** virtualizes the hardware and runs a full guest operating system with its own kernel. It is heavy, starts slowly, and isolates at the kernel boundary. **Docker** is more modern and lightweight: it virtualizes at the operating-system level, sharing the host kernel, but isolating processes, filesystems, and networks in containers. Containers start in seconds and use far fewer resources. However, a container is **not** a virtual machine — it has no kernel of its own and depends on the host kernel.

### Comparison: Secrets vs Environment Variables

**Environment variables** are suitable for non-confidential configuration such as a domain name or a database name; they are visible inside the process environment and can leak into logs or debugging output. **Docker secrets** are mounted as read-only files under `/run/secrets/` and are the recommended place for confidential values such as passwords. Secrets stay out of the image layers, are not committed to Git, and are the correct place for credentials like the WordPress or database admin passwords.

### Comparison: Docker Network vs Host Network

With the default **bridge network**, containers receive their own isolated network namespace and communicate with one another using service names and internal IPs; nothing is exposed to the host unless a port is explicitly published. **Host networking** (`network_mode: host`) shares the host's network stack directly, which removes that isolation and is forbidden by this subject. This project uses a dedicated user-defined bridge network, with only NGINX publishing port `443`.

### Comparison: Docker Volumes vs Bind Mounts

A **Docker named volume** is managed entirely by Docker: you reference it by name and Docker stores it in its own area (or, as here, redirects it to a host path). A **bind mount** maps an arbitrary host directory directly into a container at a chosen path. This subject requires the two persistent storages to be **Docker named volumes**, and their data must live under `/home/mel-houa/data`. Our Compose file declares named volume entries that are backed by host directories for inspection, satisfying both requirements.

## Instructions

### Prerequisites

- Linux virtual machine (the whole project runs inside a VM).
- Docker and Docker Compose (with the `docker compose` plugin) installed.
- Root or `sudo` privileges to create the host data directories.

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

### Access

Open `https://mel-houa.42.fr` in a browser. Because the certificate is self-signed, the browser will warn you once; proceed to view the site.

### Manage the stack

```bash
make          # build and start the stack
make logs     # follow the container logs
make ps       # show container status
make down     # stop the stack (keeps data)
make clean    # stop and remove containers, images and volumes
make fclean   # clean + delete the host data under /home/mel-houa/data
make re       # fclean then build and start again
make prune    # remove docker system assets globally (use with caution)
```

### Cleanup

`make down` stops the infrastructure without touching persistent data. Use `make fclean` only when you intentionally want to delete everything, including the WordPress and database data under `/home/mel-houa/data`.

## Resources

- Docker documentation: <https://docs.docker.com/>
- Dockerfile reference: <https://docs.docker.com/engine/reference/builder/>
- Docker Compose reference: <https://docs.docker.com/compose/compose-file/>
- Running services with `daemon off` and foreground processes: <https://docs.docker.com/engine/containers/run/>, NGINX documentation
- MariaDB: <https://mariadb.com/kb/en/>
- WordPress: <https://developer.wordpress.org/>

### How AI was used

AI was used to assist with planning the infrastructure, writing the Dockerfiles and entrypoint scripts, generating the `.env`/Compose wiring and this documentation, and troubleshooting shell and SQL logic. The generated code and configuration were reviewed, syntax-checked with `sh -n`, validated with `docker compose config`, and tested against a running stack before being accepted. AI did not author the design decisions; every choice (such as one-process-per-container, secret handling, and the two persistent volumes) was reviewed and understood.
