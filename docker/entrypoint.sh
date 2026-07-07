#!/bin/bash
set -e

# Wait for DB
echo "Waiting for DB..."
until pg_isready -h ${DATABASE_HOST:-db} -U ${DATABASE_USER:-auth_dev} -d ${DATABASE_NAME:-auth_dev_db}; do
  sleep 1
done

# Wait for Redis
echo "Waiting for Redis..."
until redis-cli -h redis ping; do
  sleep 1
done

echo "Starting Rails..."
exec "$@"
