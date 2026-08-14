# Inception MariaDB — Build-It-Yourself Guide

## 1. Purpose of this guide

This guide records everything completed in the MariaDB phase of Inception. Its purpose is to help you rebuild the code yourself and understand every decision.

Do not begin by copying the existing implementation. Use this guide as the specification, write one file yourself, test it, and only then compare it with the existing version.

## 2. Current project position

| Stage | Status |
|---|---|
| Understand the Inception requirements | Completed |
| Learn essential Docker concepts | Completed |
| Understand and plan MariaDB | Completed |
| Implement the MariaDB files | Completed as a reference |
| Rebuild MariaDB yourself | Current exercise |
| Create the Makefile | Next |
| Build and test MariaDB independently | After the Makefile |
| Implement WordPress/PHP-FPM | Later |
| Implement NGINX/TLS | Later |
| Integrate and test the full stack | Final mandatory phase |

## 3. The result we are building

For the current phase, Docker Compose must build one custom MariaDB image and start one MariaDB container.

```text
Dockerfile + configuration + entrypoint
                    |
                    v
             MariaDB image
                    |
                    v
             MariaDB container
                    |
                    v
 /var/lib/mysql <-> mariadb_data <-> VM host directory
```

MariaDB must:

- Be built from the required Debian base image.
- Run in its own container.
- Store its data persistently.
- Initialize the WordPress database only on the first start.
- Create a restricted database user for WordPress.
- Read passwords from Docker secrets at runtime.
- Accept connections from the private Docker network.
- Never publish port `3306` to the VM host.
- Run the real `mariadbd` process as PID 1.
- Report its readiness through a health check.

## 4. Concepts already learned

### Dockerfile, image, and container

```text
Dockerfile --build--> image --run--> container
```

- The Dockerfile is the build recipe.
- The image is the result of building that recipe.
- The container is a running instance of the image.

### Docker Compose

The Dockerfile describes how to build one image. Compose describes how the complete infrastructure runs: services, volumes, networks, variables, secrets, dependencies, and health checks.

### Container isolation

Each container has its own process and filesystem view. Containers on the same Docker network communicate using service names.

Later, WordPress will connect to:

```text
Host: mariadb
Port: 3306
```

It must not use `localhost`, because inside the WordPress container `localhost` means WordPress itself.

### Internal and public ports

- `ports` publishes a container port to the VM host.
- `expose` documents an internally used port.
- Containers on the same network can communicate even without `expose` if the service is listening.

MariaDB must not have a `ports` section. Only NGINX will eventually publish port `443`.

### Persistence

Container storage is disposable. Important database files belong in a volume.

```text
Inside container: /var/lib/mysql
Named volume:     mariadb_data
On VM host:       /home/your-login/data/mariadb
```

Removing the container must not remove its data. Deleting the volume or its backing data directory can destroy that data.

### Configuration and secrets

- Ordinary configuration, such as a database name, goes in `.env`.
- Confidential values, such as passwords, go in secret files.
- WordPress and MariaDB must receive the same database-user password.
- The human website user never enters this database password.

### Startup order and readiness

```text
Container started != service ready
```

A health check proves that MariaDB can accept commands. Later, WordPress will wait for MariaDB to become healthy.

### PID 1

The final command must use `exec` so the real MariaDB server replaces the entrypoint shell and becomes PID 1. This lets it receive Docker stop signals correctly.

## 5. Project structure for this phase

Recreate this structure:

```text
Inception/
|-- .gitignore
|-- MARIADB_BUILD_GUIDE.md
|-- secrets/
|   |-- db_password.txt.example
|   `-- db_root_password.txt.example
`-- srcs/
    |-- .env
    |-- docker-compose.yml
    `-- requirements/
        `-- mariadb/
            |-- Dockerfile
            |-- conf/
            |   `-- mariadb.cnf
            `-- tools/
                `-- entrypoint.sh
```

Real local secrets will also exist, but Git must ignore them:

```text
secrets/db_password.txt
secrets/db_root_password.txt
```

## 6. Recommended order for writing the files

Write in this order:

1. `srcs/.env`
2. Secret templates and `.gitignore`
3. `requirements/mariadb/conf/mariadb.cnf`
4. `requirements/mariadb/Dockerfile`
5. `requirements/mariadb/tools/entrypoint.sh`
6. `srcs/docker-compose.yml`
7. Makefile, which is the next project stage
8. Build, behavior, security, and persistence tests

The entrypoint is the most complex file. Write it in small sections and syntax-check after every section.

## 7. File guide: `srcs/.env`

### Responsibility

Store ordinary project configuration that Compose substitutes into its YAML file.

### Values it must define

| Variable | Meaning | Example shape |
|---|---|---|
| `LOGIN` | Your 42 login | `your-login` |
| `DOMAIN_NAME` | Required local domain | `your-login.42.fr` |
| `DATA_PATH` | Parent directory for persistent data | `/home/your-login/data` |
| `MYSQL_DATABASE` | Database WordPress will use | `wordpress` |
| `MYSQL_USER` | Restricted MariaDB account for WordPress | `wpuser` |

### Rules

- Replace every `your-login` placeholder yourself.
- Do not put passwords in this file for our implementation.
- Use simple database and user names containing letters, numbers, or underscores.
- Compose reads variables with syntax such as `${MYSQL_DATABASE}`.

### Completion check

You should be able to explain why `MYSQL_USER` is configuration while its password is a secret.

## 8. File guide: secret files and `.gitignore`

### Required secret roles

| Secret | Used for |
|---|---|
| `db_password` | Authenticates the restricted WordPress database user |
| `db_root_password` | Protects the MariaDB root administration account |

### Files to create locally

```text
secrets/db_password.txt
secrets/db_root_password.txt
```

Each file should contain one strong password. Use different passwords for the two accounts.

### Templates

Commit only placeholder templates ending in `.example`. A new developer copies each template to the corresponding `.txt` filename and replaces the placeholder locally.

### `.gitignore` responsibility

It must:

- Ignore real files matching `secrets/*.txt`.
- Allow safe example files matching `secrets/*.txt.example`.

### Important security check

Before every commit, run:

```bash
git status --short
```

The real `.txt` password files must never appear as files ready to commit.

## 9. File guide: `mariadb.cnf`

### Responsibility

Configure how the MariaDB server runs inside its container.

### Required section and settings

Use a MariaDB server section and configure:

| Setting | Required behavior |
|---|---|
| Linux user | Run as the package-created `mysql` user |
| Bind address | Listen on the container's Docker network interfaces |
| Port | Use internal port `3306` |
| Data directory | Store database files under `/var/lib/mysql` |
| Socket | Put the Unix socket under `/run/mysqld` |
| PID file | Put the process-ID file under `/run/mysqld` |

### Why each setting exists

- The `mysql` Linux user avoids running the database service as root.
- Binding to all container interfaces lets the future WordPress container connect.
- Port `3306` is internal and is not automatically public.
- `/var/lib/mysql` is the directory mounted to persistent storage.
- The socket gives the entrypoint a local connection during initialization.
- The PID file records the running server process.

### Completion check

You should be able to answer:

1. Why does binding to all container interfaces not publish port `3306`?
2. Which setting connects MariaDB to persistent storage?
3. Why must `/run/mysqld` belong to the `mysql` Linux user?

## 10. File guide: MariaDB `Dockerfile`

### Responsibility

Build a reusable MariaDB image. It prepares software and files; it must not create the runtime database or contain passwords.

### Required build sequence

1. Select Debian Bookworm as the base.
2. Refresh APT's package index.
3. Install the MariaDB server and client packages.
4. Avoid unnecessary recommended packages.
5. Remove APT list files from the resulting image layer.
6. Copy `mariadb.cnf` to MariaDB's configuration directory.
7. Copy `entrypoint.sh` to an executable path inside the image.
8. Give the script execute permission.
9. Document internal port `3306`.
10. Configure the entrypoint script.
11. Supply `mariadbd` as the default command passed to that script.

### Instruction responsibilities

| Instruction | Responsibility |
|---|---|
| `FROM` | Select the base filesystem |
| `RUN` | Execute image-build commands, such as package installation |
| `COPY` | Copy project files into the image |
| `EXPOSE` | Document the internal service port; it does not publish it |
| `ENTRYPOINT` | Select the startup program that always runs |
| `CMD` | Supply the default command or arguments |

### Build-time rules

- Use a fixed distribution codename, not `latest`.
- Do not use a ready-made MariaDB service image.
- Do not put credentials in the Dockerfile or build arguments.
- Keep package installation and APT cleanup in the same build layer.
- Do not start MariaDB during `docker build`.

### Completion check

Explain this chain without reading it:

```text
Dockerfile ENTRYPOINT + Dockerfile CMD
                    |
                    v
entrypoint.sh receives mariadbd as its command
```

## 11. File guide: `entrypoint.sh`

### Responsibility

Configure MariaDB at container runtime, initialize persistent data only once, and finally start the real server in the foreground.

### Section A: safe shell behavior

The script should:

- Use `/bin/sh`.
- Stop when a command fails.
- Stop when an undefined variable is used.

This prevents an incomplete setup from continuing silently.

### Section B: validate ordinary configuration

Require both:

- `MYSQL_DATABASE`
- `MYSQL_USER`

Fail early with a clear error if either is missing. Validate that their characters are safe before inserting them into SQL identifiers.

### Section C: read and validate secrets

The script receives secrets at these runtime paths:

```text
/run/secrets/db_password
/run/secrets/db_root_password
```

For each secret:

1. Define its expected path.
2. Confirm that the file is readable.
3. Read the content into a shell variable.
4. Reject an empty value.

Never print the password to logs.

### Section D: prepare runtime directories

Create when missing:

```text
/run/mysqld
/var/lib/mysql
```

Set their owner and group to the `mysql` Linux account. MariaDB cannot create its socket or database files if permissions are wrong.

### Section E: detect first start

Use the existence of MariaDB's internal system database under the data directory as the initialization marker.

```text
System database absent  -> first start -> initialize
System database present -> later start -> skip initialization
```

Do not use a file inside the container's disposable layer as the marker. The marker must be inside the persistent data directory.

### Section F: create MariaDB system files

On the first start only, run MariaDB's database-installation utility with:

- The `mysql` Linux user.
- `/var/lib/mysql` as the data directory.
- An authentication mode that allows the script to configure the root password afterward.

This creates MariaDB's internal tables. It does not yet create the WordPress database or restricted user.

### Section G: start a temporary local server

SQL statements require a running server. Start a temporary `mariadbd` process:

- As the `mysql` Linux user.
- With the persistent data directory.
- With network connections disabled.
- With the known Unix socket.
- In the background so the entrypoint can continue.

Save the background process ID. Add signal cleanup so a failed or interrupted entrypoint does not leave the temporary process behind.

Networking stays disabled because accounts, passwords, and permissions are not ready yet.

### Section H: wait for actual readiness

Do not run SQL immediately after starting the process.

Repeatedly use the administration client through the Unix socket until MariaDB answers. The wait loop should also:

- Detect if the temporary process died.
- Limit the number of attempts.
- Exit with an understandable error instead of waiting forever.

The short sleep in this bounded readiness loop is valid. It is not being used to keep the final container alive.

### Section I: protect values used in SQL

Database names, usernames, and passwords eventually enter SQL statements.

- Restrict database-name and username characters.
- Escape password characters that have meaning inside SQL string literals.
- Do not build unrestricted SQL from unchecked input.

### Section J: configure MariaDB with SQL

The first-start SQL transaction must achieve these results:

1. Set a password for `root@localhost`.
2. Create the configured WordPress database if it does not exist.
3. Create the configured database user for connections from containers.
4. Set that user's password from the secret.
5. Grant it privileges only on the configured WordPress database.
6. Remove anonymous database accounts.
7. Remove the default test database.
8. Reload privilege information.

The permission goal is:

```text
wpuser -> all tables in WordPress database
wpuser -X-> unrelated databases and account administration
```

This is the least-privilege principle.

### Section K: stop the temporary server

After SQL configuration:

1. Authenticate locally as root using the root secret.
2. Request a clean MariaDB shutdown.
3. Wait for the temporary process to exit.
4. Remove temporary signal traps.

Never run the temporary and final MariaDB servers against the same data directory simultaneously.

### Section L: start the final process

Outside the first-start conditional, replace the entrypoint shell with the command received from the Dockerfile.

The final result must be:

```text
Final mariadbd = foreground process = PID 1
```

Do not use `tail -f`, `sleep infinity`, or an infinite shell loop to keep the container running.

## 12. Complete MariaDB lifecycle

### Image build lifecycle

```text
Read Dockerfile
-> download Debian base
-> refresh package index
-> install MariaDB server and client
-> copy configuration and entrypoint
-> set executable permission
-> create MariaDB image
```

No database, database user, or password should be created during this lifecycle.

### First container start

```text
Compose creates container
-> mounts secrets and volume
-> passes environment variables
-> entrypoint validates configuration
-> entrypoint reads secrets
-> prepares directories and permissions
-> detects empty data volume
-> creates MariaDB system files
-> starts temporary server without networking
-> waits until temporary server is ready
-> creates database and restricted user
-> secures root and removes defaults
-> stops temporary server
-> execs final mariadbd
-> health check succeeds
```

### Later container start

```text
Compose creates or restarts container
-> mounts the same persistent volume
-> entrypoint validates configuration and secrets
-> detects existing MariaDB system database
-> skips all initialization SQL
-> execs final mariadbd
-> existing data remains available
```

### Crash and restart lifecycle

```text
mariadbd crashes
-> PID 1 exits
-> container stops
-> restart policy recreates/restarts service
-> same volume is mounted
-> initialization is skipped
-> mariadbd starts with existing data
```

## 13. File guide: `docker-compose.yml`

### Responsibility

Describe how the MariaDB image is built and how its container runs with configuration, secrets, storage, networking, restart behavior, and readiness testing.

### MariaDB service checklist

The service must define:

- A build context pointing to `requirements/mariadb`.
- The custom Dockerfile.
- Image name `mariadb`.
- Container name `mariadb`.
- A restart policy such as `unless-stopped`.
- `MYSQL_DATABASE` and `MYSQL_USER` from `.env`.
- Both database secrets.
- `mariadb_data` mounted at `/var/lib/mysql`.
- Membership in the explicit Inception network.
- Internal port `3306`, without publishing it.
- A MariaDB readiness health check.

### Secret declarations

At the top-level secrets section, connect Compose secret names to the real local files:

```text
db_password      -> ../secrets/db_password.txt
db_root_password -> ../secrets/db_root_password.txt
```

The paths are relative to `srcs/docker-compose.yml`.

### Network declaration

Create an explicit bridge network for Inception. Do not use host networking or legacy links.

The network will later connect:

```text
NGINX <-> WordPress <-> MariaDB
```

### Volume declaration

Declare a named volume called `mariadb_data`. Configure its host backing path using:

```text
${DATA_PATH}/mariadb
```

Before starting Compose, this directory must exist on the VM. The future Makefile will create it.

### Health-check behavior

The health check should:

- Read the root secret inside the container.
- Use `mariadb-admin ping` through the local socket.
- Run periodically.
- Have a per-check timeout.
- Allow several retries.
- Allow extra initialization time before counting failures.

In a Compose health-check command, `$$` escapes a dollar sign so the shell inside the container receives `$` instead of Compose trying to substitute it.

### Security rules

- Do not add `ports: - "3306:3306"`.
- Do not place password values in YAML.
- Do not mount the entire project directory into the database container.
- Do not use host networking.

## 14. How all files work together

| File | Build time | Runtime | Main responsibility |
|---|---:|---:|---|
| `.env` | No | Yes, through Compose substitution | Ordinary configuration |
| Secret `.txt` files | No | Yes, mounted under `/run/secrets` | Confidential passwords |
| `mariadb.cnf` | Copied | Read by MariaDB | Server behavior and paths |
| `Dockerfile` | Yes | Defines startup | Build the custom image |
| `entrypoint.sh` | Copied | Yes | Initialize once and start MariaDB |
| `docker-compose.yml` | Used to build | Used to run | Connect all runtime resources |
| `.gitignore` | No | No | Prevent real secrets from entering Git |

## 15. Write-it-yourself workflow

For each file:

1. Read only that file's requirements in this guide.
2. Close the existing reference implementation.
3. Write your own version.
4. Explain every line aloud or in comments.
5. Run the relevant syntax check.
6. Compare behavior, not only text, with the reference.
7. Ask for help only with the smallest part that blocks you.

Two implementations can be different and still both be correct if they satisfy the same requirements safely.

### Suggested entrypoint checkpoints

Build the script in these checkpoints:

1. Safe shell settings and required-variable validation.
2. Secret-file validation and reading.
3. Runtime-directory creation and permissions.
4. First-start detection.
5. System-database installation.
6. Temporary server and bounded readiness loop.
7. SQL configuration.
8. Clean temporary shutdown.
9. Final `exec`.

Run this after every checkpoint:

```bash
dash -n srcs/requirements/mariadb/tools/entrypoint.sh
```

No output means the shell syntax is valid. It does not prove the runtime behavior is correct.

## 16. Pre-build checklist

Before building on your VM:

- [ ] Replace `your-login` in `.env`.
- [ ] Create the two real secret `.txt` files.
- [ ] Give each secret a non-empty and different password.
- [ ] Confirm Git ignores both real secret files.
- [ ] Create `${DATA_PATH}/mariadb` on the VM.
- [ ] Confirm Docker and Docker Compose are installed.
- [ ] Confirm the entrypoint is executable.
- [ ] Run a shell syntax check on the entrypoint.
- [ ] Run `docker compose config` from `srcs` to validate Compose.
- [ ] Confirm the MariaDB service has no published port.

## 17. Test plan for the next stage

Do these tests only after the Makefile or equivalent build commands are ready.

### Test 1: image build

Expected result:

- Debian base downloads successfully.
- MariaDB packages install.
- Configuration and entrypoint copy successfully.
- A custom image named `mariadb` exists.

### Test 2: first startup

Expected logs should show initialization once, followed by the normal server becoming ready.

Verify:

- Container is running.
- Health status becomes healthy.
- WordPress database exists.
- Restricted database user exists.
- Anonymous users and test database are absent.

### Test 3: permissions

Authenticate as the restricted database user.

Verify:

- It can access the WordPress database.
- It cannot administer unrelated databases or create privileged accounts.

### Test 4: no public database port

Verify that Docker reports no host port mapping for MariaDB. `expose` is acceptable; a published `3306:3306` mapping is not.

### Test 5: normal restart

Restart the container.

Expected result:

- Initialization does not run again.
- The service becomes healthy.
- Existing data remains.

### Test 6: container recreation and persistence

1. Create a small test table or record.
2. Stop and remove only the MariaDB container.
3. Recreate it with the same volume.
4. Confirm the test data still exists.

Do not delete the volume during this test.

### Test 7: missing configuration

Temporarily omit a required environment variable in a safe test copy.

Expected result:

- Entrypoint exits immediately.
- Logs state which variable is missing.

### Test 8: missing or empty secret

Temporarily test with a missing or empty secret in a safe test environment.

Expected result:

- Entrypoint exits.
- MariaDB does not initialize with an empty password.

## 18. Debugging map

| Symptom | First place to inspect | Likely cause |
|---|---|---|
| Build fails during APT | Docker build output | Network, repository, or package problem |
| Configuration file not found | Dockerfile `COPY` and build context | Wrong source path |
| Entrypoint permission denied | Dockerfile permission step | Script is not executable |
| Required variable error | `.env` and Compose environment section | Missing or misspelled variable |
| Secret cannot be read | Compose secret declaration and local file | Wrong relative path or missing file |
| Cannot create socket | `/run/mysqld` ownership | Directory missing or wrong permissions |
| Cannot write database files | `/var/lib/mysql` ownership and volume | Wrong permissions or host directory |
| Temporary server never becomes ready | Container logs and socket settings | Startup error or socket mismatch |
| SQL initialization fails | SQL syntax and escaped values | Invalid identifier or quoting problem |
| Container exits immediately after setup | Final command and `exec` | `mariadbd` not started correctly |
| Health check stays unhealthy | Health command, socket, and password | Wrong authentication or path |
| Data disappears after recreation | Volume mount and host path | Wrong mount or volume deleted |

## 19. Commands you should understand before testing

You do not need to memorize every option, but you should understand the purpose of these operations:

```text
docker compose config       -> validate and render Compose configuration
docker compose build        -> build custom images
docker compose up           -> create and start services
docker compose ps           -> inspect container and health status
docker compose logs         -> inspect service output
docker compose exec         -> run a diagnostic command inside a container
docker compose stop         -> stop without removing containers
docker compose down         -> remove containers and network
docker image ls             -> inspect images
docker volume ls            -> inspect volumes
docker inspect              -> inspect detailed Docker state
```

Be careful with `docker compose down --volumes`: it removes project volumes and is not appropriate for a persistence test.

## 20. Knowledge checkpoint

Before starting the Makefile, you should be able to answer these questions:

1. What is the difference between a Dockerfile, image, and container?
2. Why does WordPress later use `mariadb` instead of `localhost`?
3. Why is MariaDB port `3306` not published?
4. Why is `/var/lib/mysql` mounted to a volume?
5. Why are usernames in `.env` but passwords in secret files?
6. Why does initialization happen at runtime instead of image-build time?
7. How does the entrypoint detect a later start?
8. Why is the temporary server started without networking?
9. Why must the entrypoint wait before executing SQL?
10. Why does the restricted user receive access only to the WordPress database?
11. Why is the temporary server stopped before the final one starts?
12. Why does the final command use `exec`?
13. What is the difference between a running container and a healthy service?
14. Why does recreating the container not remove database data?
15. Which action would remove the persistent data?

## 21. Your immediate exercise

Rebuild the MariaDB component in a separate practice directory. Start with only:

```text
practice-mariadb/
|-- Dockerfile
|-- conf/
|   `-- mariadb.cnf
`-- tools/
    `-- entrypoint.sh
```

Recommended first task:

1. Write `mariadb.cnf` from the requirements in Section 9.
2. Explain every setting in your own words.
3. Write the Dockerfile from the ordered requirements in Section 10.
4. Run a syntax check on the entrypoint as you build it section by section.

Do not start with the full entrypoint in one attempt. Complete and understand one checkpoint at a time.

## 22. What comes next

After your own MariaDB files are ready, the next project stage is:

1. Create a root Makefile.
2. Make it create the required host data directories.
3. Make it call Docker Compose to build and start the project.
4. Build MariaDB on the VM.
5. Run every test from Section 17.
6. Fix all failures before beginning WordPress.

The WordPress phase should not begin until MariaDB is independently healthy, private, secure, and persistent.
