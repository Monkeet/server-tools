#!/bin/bash
FROM=windows-1252
TO=UTF-8
ICONV="iconv -f $FROM -t $TO"
# Convert
find . -name "db-backup.sql" | while read fn; do
cp ${fn} ${fn}.bak
$ICONV < ${fn}.bak > ${fn}
rm ${fn}.bak
done
