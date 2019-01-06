#!/bin/bash

TIMESTAMP=$(date +"%F")
BACKUP_DIR="/backup/databases/$TIMESTAMP"
MYSQL_USER="root"
MYSQL=/usr/bin/mysql
MYSQLDUMP=/usr/bin/mysqldump

mkdir -p "$BACKUP_DIR"

databases=`$MYSQL --user=$MYSQL_USER -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema)"`

for db in $databases; do
	  $MYSQLDUMP --force --opt --user=$MYSQL_USER --databases $db | gzip > "$BACKUP_DIR/$db.gz"
  done
