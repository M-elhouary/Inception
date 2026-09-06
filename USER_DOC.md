# Inception — User Documentation

This document explains, in simple terms, what the stack provides and how to use it.

## What services are provided

The infrastructure runs three services inside a virtual machine, each in its own Docker container:

- **MariaDB** — a private database that stores all WordPress content (posts, pages, users, settings).
- **WordPress + PHP-FPM** — the website itself. It processes PHP code and talks to MariaDB.
- **NGINX** — the front door of the whole stack. It receives HTTPS traffic on port `443` and forwards PHP requests to WordPress.

Only NGINX is reachable from outside. MariaDB and WordPress stay private inside the Docker network.

## How to start and stop the project

From the project root folder (the one containing the `Makefile`):

```bash
make          # build and start everything
make down     # stop everything (data is kept)
make ps       # show whether each container is running and healthy
make logs     # watch the live logs of all containers
make fclean   # (destructive) stop everything and delete all stored data
```

To start the stack again after `make down`, simply run `make` again.

## How to access the website

Open a browser and go to:

```text
https://mel-houa.42.fr
```

The VM must be reachable under that name (see the README "Domain name" section). Because the certificate is self-signed, your browser will show a warning the first time — accept it to continue. You should see the WordPress home page of the *Inception* site.

## How to access the administration panel

Add `/wp-admin` to the site address:

```text
https://mel-houa.42.fr/wp-admin
```

Sign in with the administrator account (see below).

## Where credentials are located and how to manage them safely

The ordinary configuration lives in `srcs/.env`. The confidential passwords (admin, database, and other users) live in plain-text files inside the local `secrets/` folder:

```text
secrets/db_password.txt         password of the WordPress database user
secrets/db_root_password.txt    password of the MariaDB root account
secrets/wp_admin_password.txt   password of the WordPress administrator
secrets/wp_user_password.txt    password of the WordPress regular user
```

These files are ignored by Git and must never be committed. They are mounted into the containers at runtime under `/run/secrets/`.

To manage them safely:

1. Keep the files read-only for everyone except the owner (mode `600`).
2. Use a different, strong password for each account.
3. After changing a secret, rebuild and re-initialize the stack with `make re` so the running services use the new value.

## How to check that the services are running correctly

```bash
make ps
```

You should see three containers with the names `nginx`, `wordpress`, and `mariadb`. The `mariadb` container should also report a `healthy` status (checks that the database answers).

You can test the website with:

```bash
curl -kI https://mel-houa.42.fr
```

A `HTTP/1.1 200 OK` response means the site is up. If a page fails to load after starting the stack, wait a few seconds for WordPress to finish installing on the first boot, then reload.
