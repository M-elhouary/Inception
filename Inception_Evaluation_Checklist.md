# Inception — Subject and Evaluation Checklist

Use this checklist before requesting an evaluation. It is based on the Inception subject and the usual correction-sheet evaluation flow. Always treat the exact subject and correction sheet delivered with your project as authoritative.

## Status legend

- `[ ]` Not checked
- `[x]` Verified
- `[!]` Problem found
- `[N/A]` Not applicable

For every checked item, record the command or evidence used. Do not mark an item complete only because the configuration looks correct.

---

## 1. Preliminary checks — stop the evaluation if one fails

- [ ] The project is executed inside a virtual machine.
- [ ] The repository was cloned fresh for the test.
- [ ] The repository contains a `Makefile` at its root.
- [ ] All required configuration files are inside `srcs/`.
- [ ] `srcs/docker-compose.yml` exists.
- [ ] The project builds and starts with `make`.
- [ ] The build completes without an error.
- [ ] No ready-made service image is pulled. Only Alpine or Debian may be used as a base image.
- [ ] Each mandatory service has its own Dockerfile.
- [ ] Dockerfiles are built through `docker-compose.yml` and the Makefile.
- [ ] No Dockerfile uses the `latest` tag.
- [ ] No password, credential, token, or API key exists in a Dockerfile.
- [ ] No real password, credential, token, or API key is tracked anywhere in the Git repository.
- [ ] Git history was also checked for previously committed credentials.
- [ ] Environment variables are used for non-secret configuration.
- [ ] A `.env` file is used and is not committed when it contains local configuration that must remain private.
- [ ] Confidential values are stored locally through properly configured Docker secrets.
- [ ] Containers do not use `network_mode: host`.
- [ ] Containers do not use `links` or `--link`.
- [ ] No container is kept alive using `tail -f`, `sleep infinity`, `while true`, an interactive shell, or a similar hack.
- [ ] Each container runs its real foreground service as PID 1.
- [ ] The project does not use an infinite loop as its entrypoint or command.
- [ ] NGINX is the only external entry point into the infrastructure.
- [ ] Only host port `443` is published.
- [ ] The mandatory part is complete before any bonus is evaluated.

Useful checks:

```bash
git ls-files
git log --all --oneline
git log -p --all
docker compose --env-file srcs/.env -f srcs/docker-compose.yml config
docker compose --env-file srcs/.env -f srcs/docker-compose.yml build --no-cache
docker compose --env-file srcs/.env -f srcs/docker-compose.yml ps
docker image ls
docker network ls
docker volume ls
```

> Never print secret contents during an evaluation or automated audit.

---

## 2. Expected project structure

- [ ] Root contains `Makefile`.
- [ ] Root contains `README.md`.
- [ ] Root contains `USER_DOC.md`.
- [ ] Root contains `DEV_DOC.md`.
- [ ] Root contains the local `secrets/` directory or clear instructions for creating it.
- [ ] `srcs/.env` exists locally or an example/template explains how to create it.
- [ ] `srcs/docker-compose.yml` exists.
- [ ] `srcs/requirements/mariadb/Dockerfile` exists.
- [ ] `srcs/requirements/mariadb/conf/` contains the MariaDB configuration.
- [ ] `srcs/requirements/mariadb/tools/` contains its initialization script.
- [ ] `srcs/requirements/wordpress/Dockerfile` exists.
- [ ] `srcs/requirements/wordpress/conf/` and/or `tools/` contains its configuration and startup logic.
- [ ] `srcs/requirements/nginx/Dockerfile` exists.
- [ ] `srcs/requirements/nginx/conf/` contains its configuration.
- [ ] Build contexts exclude unnecessary and confidential files, preferably with `.dockerignore` files.

---

## 3. Makefile

- [ ] The default target builds and launches the complete stack.
- [ ] The Makefile invokes Docker Compose using `srcs/docker-compose.yml`.
- [ ] Required host data directories are created under `/home/<login>/data` before startup, if required by the chosen volume configuration.
- [ ] `make` is idempotent: executing it again does not corrupt or reinstall the project.
- [ ] A target exists to stop the project without deleting persistent data.
- [ ] A target exists to rebuild the project.
- [ ] Cleanup targets have clearly separated behavior for containers/images and persistent data.
- [ ] Destructive cleanup is explicit and does not accidentally delete an unrelated or unresolved path.
- [ ] The login and data path are consistent with `.env` and Compose.

Suggested manual tests:

```bash
make
make
make down
make
make logs
make ps
```

---

## 4. Docker images and Dockerfiles

- [ ] Every service uses the penultimate stable Alpine or Debian release required by the subject version.
- [ ] Every service image is built locally.
- [ ] Package-manager caches are removed after installation.
- [ ] Only packages required by the service are installed.
- [ ] `--no-install-recommends` is used with `apt-get` where appropriate.
- [ ] Configuration and entrypoint files are copied explicitly.
- [ ] Entrypoint scripts are executable.
- [ ] `ENTRYPOINT` and `CMD` use exec/JSON form where appropriate.
- [ ] Shell entrypoints end with `exec "$@"` or execute the actual daemon directly.
- [ ] No secret is copied into an image layer.
- [ ] No unnecessary port is published.
- [ ] Image and container names are clear and do not accidentally rely on external official service images.

Inspection commands:

```bash
docker compose --env-file srcs/.env -f srcs/docker-compose.yml images
docker image history <image-name>
docker inspect <container-name>
docker exec <container-name> ps aux
```

---

## 5. Docker Compose architecture

- [ ] Exactly one mandatory container runs NGINX.
- [ ] Exactly one mandatory container runs WordPress with PHP-FPM.
- [ ] Exactly one mandatory container runs MariaDB.
- [ ] Services use locally built images.
- [ ] All mandatory containers belong to the dedicated Docker network.
- [ ] Service names provide internal DNS resolution (`mariadb`, `wordpress`, `nginx`).
- [ ] Only NGINX has a `ports:` mapping.
- [ ] MariaDB uses only internal port `3306`, with no host publication.
- [ ] PHP-FPM uses only internal port `9000`, with no host publication.
- [ ] Every mandatory container has an automatic restart policy.
- [ ] Startup dependencies do not replace real readiness checks.
- [ ] WordPress waits until MariaDB can accept an authenticated connection.
- [ ] Compose configuration resolves successfully with the intended `.env` file.
- [ ] Domain, login, paths, database names, and usernames are consistent across all files.

Commands:

```bash
docker compose --env-file srcs/.env -f srcs/docker-compose.yml config
docker compose --env-file srcs/.env -f srcs/docker-compose.yml ps
docker inspect nginx wordpress mariadb
docker port nginx
docker port wordpress
docker port mariadb
```

Expected externally published port:

```text
nginx: 443/tcp
wordpress: none
mariadb: none
```

---

## 6. Docker network

- [ ] A user-defined Docker bridge network exists.
- [ ] The network is declared explicitly in Compose.
- [ ] All three mandatory containers are attached to it.
- [ ] Communication uses service names, not hardcoded container IP addresses.
- [ ] NGINX reaches WordPress on port `9000`.
- [ ] WordPress reaches MariaDB on port `3306`.
- [ ] MariaDB is not reachable directly from the host through a published port.
- [ ] Host networking and deprecated links are absent.

Commands:

```bash
docker network inspect <project-network>
docker exec nginx getent hosts wordpress
docker exec wordpress getent hosts mariadb
```

---

## 7. NGINX and TLS

- [ ] NGINX is installed and configured inside its own container.
- [ ] The NGINX container does not contain WordPress or MariaDB.
- [ ] NGINX listens on port `443` with SSL enabled.
- [ ] TLS 1.2 and/or TLS 1.3 are enabled.
- [ ] TLS 1.0 and TLS 1.1 are rejected.
- [ ] The certificate and private key exist inside the NGINX container.
- [ ] The certificate identifies `<login>.42.fr`, preferably in both CN and Subject Alternative Name.
- [ ] The certificate private key is not publicly tracked.
- [ ] PHP requests are forwarded to `wordpress:9000` through FastCGI.
- [ ] `SCRIPT_FILENAME` is configured correctly.
- [ ] Static WordPress files are served from the shared website volume.
- [ ] NGINX runs in the foreground.
- [ ] HTTP port 80 is not published and is not required.
- [ ] The website works at `https://<login>.42.fr`.

Commands:

```bash
curl -kI https://<login>.42.fr
openssl s_client -connect <login>.42.fr:443 -servername <login>.42.fr
openssl s_client -connect <login>.42.fr:443 -tls1_2
openssl s_client -connect <login>.42.fr:443 -tls1_3
openssl s_client -connect <login>.42.fr:443 -tls1
```

The last command should fail if TLS 1.0 is disabled correctly.

---

## 8. MariaDB

- [ ] MariaDB is installed in its own container.
- [ ] The container does not contain NGINX.
- [ ] MariaDB listens on the internal Docker network.
- [ ] The database directory is stored in the database volume.
- [ ] Initialization happens only when the database volume is empty.
- [ ] The configured WordPress database is created.
- [ ] A dedicated database user is created for WordPress.
- [ ] The WordPress database user has the necessary privileges on only the intended database.
- [ ] The MariaDB root account has a non-empty secret password.
- [ ] The default test database is removed.
- [ ] Passwords are read from Docker secrets and are not hardcoded.
- [ ] SQL values are safely validated or escaped before generating initialization SQL.
- [ ] MariaDB runs as its real foreground daemon.
- [ ] MariaDB becomes healthy after startup.
- [ ] Data survives container deletion and recreation.

Commands:

```bash
docker exec mariadb mariadb-admin ping
docker exec mariadb mariadb -u root -p -e "SHOW DATABASES;"
docker exec mariadb mariadb -u root -p -e "SELECT User,Host FROM mysql.user;"
docker exec mariadb mariadb -u root -p -e "SHOW GRANTS FOR '<db-user>'@'%';"
```

Enter passwords interactively. Do not place them directly on the command line.

---

## 9. WordPress and PHP-FPM

- [ ] WordPress and PHP-FPM are installed in their own container.
- [ ] The WordPress container does not contain NGINX.
- [ ] PHP-FPM listens on port `9000` on the Docker network.
- [ ] PHP-FPM runs in the foreground.
- [ ] WordPress files are stored in the website volume.
- [ ] `wp-config.php` uses the configured database name, user, password, and `mariadb` host.
- [ ] WordPress installation is idempotent.
- [ ] WordPress waits for a real authenticated MariaDB connection before installation.
- [ ] WordPress is installed with the correct `https://<login>.42.fr` URL.
- [ ] The administrator username does not contain `admin` or `administrator`, regardless of letter case.
- [ ] The administrator password comes from a secret.
- [ ] A second, non-administrator WordPress user exists.
- [ ] The second user's password comes from a secret.
- [ ] The two WordPress users have different usernames.
- [ ] The website front page loads.
- [ ] `/wp-admin` loads and the administrator can sign in.
- [ ] The regular user exists and has the intended non-administrator role.
- [ ] WordPress content remains after containers are recreated.

Commands:

```bash
docker exec wordpress wp core is-installed --allow-root --path=/var/www/html
docker exec wordpress wp option get siteurl --allow-root --path=/var/www/html
docker exec wordpress wp user list --allow-root --path=/var/www/html
docker exec wordpress php-fpm8.2 -t
```

Adapt the PHP-FPM binary version if another supported base distribution provides a different version.

---

## 10. Volumes and persistence

- [ ] There are two distinct named volumes for the mandatory part.
- [ ] One volume stores `/var/lib/mysql`.
- [ ] One volume stores `/var/www/html`.
- [ ] Persistent data is stored under `/home/<login>/data` on the host as required by the subject.
- [ ] The exact implementation is compatible with the current subject's named-volume and bind-mount rules.
- [ ] No anonymous volume accidentally replaces a required named volume.
- [ ] Deleting and recreating containers does not delete WordPress or database data.
- [ ] Stopping and starting the VM does not delete the data.
- [ ] A deliberate full-clean operation is the only normal command that deletes persistent data.

Persistence test:

1. Create a WordPress post or page with unique text.
2. Record the two WordPress users.
3. Stop and remove only the containers.
4. Start the stack again.
5. Confirm that the post and both users still exist.

Commands:

```bash
docker volume ls
docker volume inspect <database-volume>
docker volume inspect <wordpress-volume>
sudo find /home/<login>/data -maxdepth 3 -type d
docker compose --env-file srcs/.env -f srcs/docker-compose.yml down
make
```

> Subject versions can differ on the wording around named volumes and bind mounts. Follow the exact PDF and correction sheet supplied for your project, and be ready to explain your implementation.

---

## 11. Domain name and host configuration

- [ ] The domain is exactly `<login>.42.fr`.
- [ ] The domain resolves to the VM running the project.
- [ ] `/etc/hosts` or DNS is configured correctly.
- [ ] The domain used by NGINX matches the WordPress URL.
- [ ] The domain used by the TLS certificate matches the project domain.
- [ ] Access through the required domain works after a fresh start.

Local example:

```text
127.0.0.1 <login>.42.fr
```

Use the VM's IP instead of `127.0.0.1` when the browser runs outside the VM.

---

## 12. Secrets and environment variables

- [ ] Non-confidential values are kept as environment variables.
- [ ] Confidential values are stored in separate local secret files.
- [ ] Compose declares every required secret.
- [ ] Each service receives only the secrets it needs.
- [ ] Scripts read secrets from `/run/secrets/<name>`.
- [ ] Secret files are ignored by Git.
- [ ] Secret files are not currently tracked.
- [ ] Secret files never appeared in Git history, or history was securely cleaned and exposed values rotated.
- [ ] Secret files are not copied into Docker images.
- [ ] Real passwords do not appear in `.env`, Compose, Dockerfiles, shell scripts, documentation, command history, or logs.
- [ ] Secret files are non-empty and have restrictive local permissions such as `600`.
- [ ] Missing or empty secrets cause a clear startup failure.

Safe checks:

```bash
git status --ignored
git ls-files | grep -E '(^|/)(\.env|secrets/.*\.txt)$'
git log --all --name-only --pretty=format: | sort -u
find secrets -type f -printf '%m %p\n'
```

Do not print the contents of secret files.

---

## 13. Restart and failure behavior

- [ ] All mandatory containers have an accepted restart policy.
- [ ] Killing the MariaDB process causes its container to restart.
- [ ] Killing the WordPress/PHP-FPM process causes its container to restart.
- [ ] Killing the NGINX process causes its container to restart.
- [ ] After recovery, the website becomes accessible again.
- [ ] Recovery does not recreate the database or WordPress installation.
- [ ] Logs provide useful failure information without exposing secrets.

Perform destructive runtime tests only with permission and only when disposable/persistent data safety is understood.

---

## 14. Documentation requirements

### `README.md`

- [ ] The first line is italicized and says: `This project has been created as part of the 42 curriculum by <login>.`
- [ ] It is written in English.
- [ ] It contains a Description section.
- [ ] It explains the project's goal and architecture.
- [ ] It explains the use of Docker and the sources included in the project.
- [ ] It documents the main design choices.
- [ ] It compares virtual machines and Docker.
- [ ] It compares secrets and environment variables.
- [ ] It compares Docker networks and host networking.
- [ ] It compares Docker volumes and bind mounts.
- [ ] It contains an Instructions section for installation, build, execution, and cleanup.
- [ ] It contains a Resources section with classic references.
- [ ] It explains exactly how AI was used and which project parts it assisted with.

### `USER_DOC.md`

- [ ] It explains the services provided by the stack in simple language.
- [ ] It explains how to start and stop the project.
- [ ] It explains how to access the website.
- [ ] It explains how to access the administration panel.
- [ ] It explains where credentials are located and how to manage them safely.
- [ ] It explains how to check whether services are running correctly.

### `DEV_DOC.md`

- [ ] It explains prerequisites and setup from scratch.
- [ ] It explains `.env` and secret-file creation without publishing real passwords.
- [ ] It explains how to build and launch through the Makefile and Docker Compose.
- [ ] It lists relevant commands for containers, images, networks, and volumes.
- [ ] It explains where data is stored.
- [ ] It explains how persistence works.

---

## 15. Explanation questions for the defense

The student should be able to explain, without reading memorized text:

- [ ] What an image is and how it differs from a container.
- [ ] What a Dockerfile does.
- [ ] What Docker Compose does.
- [ ] Why a container is not a virtual machine.
- [ ] Why one process per container is useful here.
- [ ] What PID 1 is and why `exec` matters.
- [ ] Why foreground daemons are required.
- [ ] Why `tail -f` and infinite-loop hacks are forbidden.
- [ ] How NGINX, PHP-FPM, WordPress, and MariaDB communicate.
- [ ] Why NGINX is the only published service.
- [ ] What TLS provides and what a self-signed certificate means.
- [ ] What happens from entering `https://<login>.42.fr` until the page is displayed.
- [ ] The difference between TLS 1.2 and TLS 1.3 at a high level.
- [ ] Why MariaDB data and WordPress files need separate persistent volumes.
- [ ] The difference between a named volume and a bind mount.
- [ ] The difference between a Docker network and host networking.
- [ ] How Docker DNS resolves service names.
- [ ] The difference between environment variables and secrets.
- [ ] Why committing a password and deleting it in a later commit is insufficient.
- [ ] How initialization scripts remain idempotent.
- [ ] What happens when a container crashes or the VM restarts.

---

## 16. Runtime evaluation sequence

Use this order to avoid overlooking failures:

1. [ ] Clone the repository into a clean location.
2. [ ] Confirm that no confidential local files came from Git.
3. [ ] Create `.env` and secret files using the documentation.
4. [ ] Configure `/etc/hosts` or DNS.
5. [ ] Run the full cleanup command only if its target paths were verified.
6. [ ] Run `make`.
7. [ ] Confirm that exactly the expected mandatory containers are running.
8. [ ] Inspect images, Dockerfiles, network, ports, and volumes.
9. [ ] Test TLS versions and the domain.
10. [ ] Open the website and `/wp-admin`.
11. [ ] Verify the administrator and second WordPress user.
12. [ ] Verify MariaDB database and database user.
13. [ ] Create unique WordPress content.
14. [ ] Recreate containers and verify persistence.
15. [ ] Test restart behavior.
16. [ ] Review all documentation.
17. [ ] Ask conceptual defense questions.
18. [ ] Evaluate bonus services only if the mandatory part passes completely.

---

## 17. Bonus gating and bonus services

- [ ] The mandatory part is perfect before bonus points are considered.
- [ ] Every bonus service has its own Dockerfile and container.
- [ ] Every bonus service is declared in Compose.
- [ ] Every bonus service follows the same security and PID 1 requirements.
- [ ] Every bonus service uses a dedicated volume when persistence is necessary.
- [ ] Redis cache is connected to and actually used by WordPress.
- [ ] FTP points to the WordPress website volume and works correctly.
- [ ] The static website is not written in PHP.
- [ ] Adminer works and is not mixed into another container.
- [ ] Any additional useful service is justified and works.
- [ ] Bonus ports do not weaken or violate the mandatory architecture expected by the applicable correction sheet.

---

## 18. Final result template

```text
Preliminary result: PASS / FAIL
Mandatory result: PASS / PARTIAL / FAIL
Bonus eligible: YES / NO

Fatal problems:
- ...

Mandatory missing items:
- ...

Runtime failures:
- ...

Security problems:
- ...

Documentation problems:
- ...

Recommended improvements:
- ...

Tests not performed and reason:
- ...
```

