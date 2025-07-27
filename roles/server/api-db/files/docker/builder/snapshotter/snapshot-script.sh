#!/usr/bin/env bash

set -e

echo "Start snapshot at $(date)"

BACKUP_FILE="/tmp/backup_$(date +%y_%m_%d-%H_%M).gz"

# Setting the password this way suppresses the mysqldump warning about using
# a password on the command line
export MYSQL_PWD="$MYSQL_PASSWORD"

# api-db is the container running the database
/usr/bin/mysqldump --host=api-db --port=3306 --user "$MYSQL_USER" --no-tablespaces "$MYSQL_DATABASE" | gzip > "$BACKUP_FILE"
/usr/local/bin/aws s3 cp "$BACKUP_FILE" s3://apidb-snapshot/

rm "$BACKUP_FILE"
