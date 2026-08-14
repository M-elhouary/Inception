#!/usr/bin/env bash
set -eu

# ==============================================================================
# GLOBALS & HELPERS
# ==============================================================================
DATADIR="/var/lib/mysql"
RUN_DIR="/run/mysqld"
SOCKET_FILE="${RUN_DIR}/mysqld.sock"
SAFE_IDENTIFIER_REGEX='^[a-zA-Z0-9_]+$'

# Function to escape single quotes inside SQL string literals
escape_sql_string() {
  local input="$1"
  # Replace every single quote ' with ''
  echo "${input//\'/\'\'}"
}

# Cleanup handler for signal trapping during temporary server execution
cleanup_temp_server() {
  if [[ -n "${TEMP_PID:-}" ]] && kill -0 "$TEMP_PID" 2>/dev/null; then
    echo "Warning: Interrupted during setup. Terminating temporary MariaDB server (PID: ${TEMP_PID})..." >&2
    kill -TERM "$TEMP_PID" 2>/dev/null || true
    wait "$TEMP_PID" 2>/dev/null || true
  fi
}

# ==============================================================================
# SECTION B: VALIDATE ORDINARY CONFIGURATION
# ==============================================================================
validate_sql_identifier() {
  local var_name="$1"
  local var_value="${!var_name:-}"

  if [[ -z "$var_value" ]]; then
    echo "Error: Required environment variable '$var_name' is missing or empty." >&2
    exit 1
  fi

  if [[ ! "$var_value" =~ $SAFE_IDENTIFIER_REGEX ]]; then
    echo "Error: Variable '$var_name' contains invalid characters: '$var_value'" >&2
    echo "Identifiers may only contain letters, numbers, and underscores." >&2
    exit 1
  fi
}

validate_sql_identifier "MYSQL_DATABASE"
validate_sql_identifier "MYSQL_USER"

# ==============================================================================
# SECTION C: READ AND VALIDATE SECRETS
# ==============================================================================
DB_PASSWORD_FILE="/run/secrets/db_password"
DB_ROOT_PASSWORD_FILE="/run/secrets/db_root_password"

read_secret() {
  local secret_path="$1"
  local secret_name="$2"

  if [[ ! -r "$secret_path" ]]; then
    echo "Error: Secret file '$secret_path' for $secret_name is missing or unreadable." >&2
    exit 1
  fi

  # Read secret and trim trailing newlines/whitespace
  local secret_val
  secret_val=$(tr -d '\r\n' < "$secret_path")

  if [[ -z "$secret_val" ]]; then
    echo "Error: Secret '$secret_name' at '$secret_path' is empty." >&2
    exit 1
  fi

  echo "$secret_val"
}

MYSQL_PASSWORD=$(read_secret "$DB_PASSWORD_FILE" "MYSQL_PASSWORD")
MYSQL_ROOT_PASSWORD=$(read_secret "$DB_ROOT_PASSWORD_FILE" "MYSQL_ROOT_PASSWORD")

# ==============================================================================
# SECTION D: PREPARE RUNTIME DIRECTORIES
# ==============================================================================
mkdir -p "$RUN_DIR" "$DATADIR"
chown -R mysql:mysql "$RUN_DIR" "$DATADIR"
chmod 755 "$RUN_DIR"

# ==============================================================================
# SECTION E: DETECT FIRST START
# ==============================================================================
# Checks for MariaDB's internal system database inside the persistent volume.
if [[ ! -d "${DATADIR}/mysql" ]]; then
  echo "Notice: Persistent data directory is uninitialized. Starting first-time setup..."

  # Setup interrupt cleanup trap for Section G
  trap cleanup_temp_server EXIT INT TERM

  # ============================================================================
  # SECTION F: CREATE MARIADB SYSTEM FILES
  # ============================================================================
  echo "Initializing MariaDB system tables..."
  mariadb-install-db \
    --user=mysql \
    --datadir="$DATADIR" \
    --auth-root-authentication-method=normal \
    --skip-test-db \
    > /dev/null

  # ============================================================================
  # SECTION G: START A TEMPORARY LOCAL SERVER
  # ============================================================================
  echo "Starting temporary local MariaDB server..."
  mariadbd \
    --user=mysql \
    --datadir="$DATADIR" \
    --socket="$SOCKET_FILE" \
    --skip-networking \
    --skip-grant-tables=OFF &
  
  TEMP_PID=$!

  # ============================================================================
  # SECTION H: WAIT FOR ACTUAL READINESS
  # ============================================================================
  echo "Waiting for temporary server to respond..."
  MAX_RETRIES=30
  RETRY_COUNT=0
  SERVER_READY=0

  while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
    if ! kill -0 "$TEMP_PID" 2>/dev/null; then
      echo "Error: Temporary MariaDB server crashed during startup." >&2
      exit 1
    fi

    if mariadb-admin ping --socket="$SOCKET_FILE" --silent 2>/dev/null; then
      SERVER_READY=1
      break
    fi

    sleep 1
    ((RETRY_COUNT++))
  done

  if [[ $SERVER_READY -ne 1 ]]; then
    echo "Error: Timed out waiting for temporary MariaDB server on socket '$SOCKET_FILE'." >&2
    exit 1
  fi

  # ============================================================================
  # SECTION I & J: PROTECT VALUES & CONFIGURE MARIADB WITH SQL
  # ============================================================================
  echo "Applying secure database configuration..."

  # Escape passwords for SQL string literals
  ESCAPED_MYSQL_PASSWORD=$(escape_sql_string "$MYSQL_PASSWORD")
  ESCAPED_MYSQL_ROOT_PASSWORD=$(escape_sql_string "$MYSQL_ROOT_PASSWORD")

  # Build transactional SQL configuration
  # Uses safe, validated variables for identifiers ($MYSQL_DATABASE, $MYSQL_USER)
  mariadb --socket="$SOCKET_FILE" <<-EOSQL
    -- 1. Secure root user
    ALTER USER 'root'@'localhost' IDENTIFIED BY '${ESCAPED_MYSQL_ROOT_PASSWORD}';

    -- 2. Create target database
    CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

    -- 3. Create application user for container network access (%)
    CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${ESCAPED_MYSQL_PASSWORD}';

    -- 4. Apply least-privilege principle
    GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';

    -- 5. Cleanup default security hazards
    DELETE FROM mysql.user WHERE User='';
    DROP DATABASE IF EXISTS test;

    -- 6. Reload privileges
    FLUSH PRIVILEGES;
EOSQL

  # ============================================================================
  # SECTION K: STOP THE TEMPORARY SERVER
  # ============================================================================
  echo "Shutting down temporary server..."
  mariadb-admin --socket="$SOCKET_FILE" --user=root --password="$MYSQL_ROOT_PASSWORD" shutdown

  # Wait for temporary process to gracefully terminate
  wait "$TEMP_PID"

  # Remove process-specific signal traps
  trap - EXIT INT TERM
  unset TEMP_PID
  
  echo "Initialization complete."
else
  echo "Notice: Existing MariaDB database found in '$DATADIR'. Skipping initialization."
fi

# ==============================================================================
# SECTION L: START THE FINAL PROCESS
# ==============================================================================
echo "Starting main process: $@"
# Exec replaces the shell process so mariadbd becomes PID 1
exec "$@"