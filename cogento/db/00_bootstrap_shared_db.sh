#!/bin/sh
# Bootstrap Shared Database Script
# Purpose: Create and initialize cogento_shared database on first startup
# Date: 2026-01-16
# Location: This script is version controlled in scripts/db/
#           It gets copied to volumes/postgres/init/ for execution

set -e  # Exit on error

echo "=========================================="
echo "Bootstrapping cogento_shared database..."
echo "=========================================="

# Wait for PostgreSQL to be ready
until pg_isready -U "$POSTGRES_USER" -d postgres; do
  echo "Waiting for PostgreSQL to be ready..."
  sleep 1
done

echo "PostgreSQL is ready."

# Check if cogento_shared database exists
DB_EXISTS=$(psql -U "$POSTGRES_USER" -d postgres -tc "SELECT 1 FROM pg_database WHERE datname = 'cogento_shared'" | grep -q 1 && echo "yes" || echo "no")

if [ "$DB_EXISTS" = "no" ]; then
    echo "Creating cogento_shared database..."
    psql -U "$POSTGRES_USER" -d postgres -c "CREATE DATABASE cogento_shared;"
    echo "Database cogento_shared created."
else
    echo "Database cogento_shared already exists, skipping creation."
fi

# Run bootstrap schema SQL
# The SQL file is in the same directory as this script when mounted
echo "Running bootstrap schema..."
BOOTSTRAP_SQL="/docker-entrypoint-initdb.d/bootstrap_shared_schema.sql"

if [ -f "$BOOTSTRAP_SQL" ]; then
    psql -U "$POSTGRES_USER" -d cogento_shared -f "$BOOTSTRAP_SQL"
    echo "Bootstrap schema applied successfully."
else
    echo "WARNING: Bootstrap SQL file not found at $BOOTSTRAP_SQL"
    echo "Schema initialization skipped."
fi

# Create initial superuser if SHARED_SUPERUSER_EMAIL is set
if [ -n "$SHARED_SUPERUSER_EMAIL" ]; then
    echo "Creating initial superuser: $SHARED_SUPERUSER_EMAIL"
    
    # Check if user already exists
    USER_EXISTS=$(psql -U "$POSTGRES_USER" -d cogento_shared -tc "SELECT 1 FROM users WHERE email = '$SHARED_SUPERUSER_EMAIL'" | grep -q 1 && echo "yes" || echo "no")
    
    if [ "$USER_EXISTS" = "no" ]; then
        psql -U "$POSTGRES_USER" -d cogento_shared <<EOF
INSERT INTO users (user_id, email, role, is_active, created_at, updated_at)
VALUES (gen_random_uuid(), '$SHARED_SUPERUSER_EMAIL', 'superuser', TRUE, NOW(), NOW())
ON CONFLICT (email) DO NOTHING;
EOF
        echo "Initial superuser created: $SHARED_SUPERUSER_EMAIL"
    else
        echo "Superuser already exists: $SHARED_SUPERUSER_EMAIL (skipping)"
    fi
else
    echo "SHARED_SUPERUSER_EMAIL not set, skipping superuser creation."
    echo "You can create a superuser later via the UI or SQL."
fi

# Demo tenant bootstrap removed - demo tenants should be created manually using existing Cogento features

echo "=========================================="
echo "Bootstrap complete!"
echo "=========================================="
