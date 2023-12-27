#!/bin/bash

dotenv_file="./.env"
source "$dotenv_file" || { echo "$(date +'%Y-%m-%d %H:%M:%S') Error: Unable to load environment variables from $dotenv_file"; exit 1; }
backup_name=$NAME

cd $BACKUP_DIR

# Create a tar file with the specified naming convention
tar_filename="backup_${backup_name}_$(date +'%Y%m%d').tar"
(tar -czvf "$tar_filename" "$BACKUP_DIR" >> backup_log.txt 2>&1) || { echo "$(date +'%Y-%m-%d %H:%M:%S') Error creating tar file." >> backup_log.txt; exit 1; }

# Create a mysqldump with the same naming convention
mysql_dump_filename="backup_${MYSQL_DATABASE}_$(date +'%Y%m%d').sql"
(mysqldump -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" > "$mysql_dump_filename" >> backup_log.txt 2>&1) || { echo "$(date +'%Y-%m-%d %H:%M:%S') Error creating mysqldump file." >> backup_log.txt; exit 1; }

# Zip the tar and SQL files into the same zip
zip_name="backup_$(date +'%Y%m%d').zip"
zip -m "$zip_name" "$tar_filename" "$mysql_dump_filename" >> backup_log.txt 2>&1 || { echo "$(date +'%Y-%m-%d %H:%M:%S') Error zipping files." >> backup_log.txt; exit 1; }

# Copy files to another server using scp
(scp -o StrictHostKeyChecking=no "$zip_name" "$REMOTE_USER"@"$REMOTE_ADDRESS":"$REMOTE_DESTINATION" >> backup_log.txt 2>&1) || { echo "$(date +'%Y-%m-%d %H:%M:%S') Error copying files to remote server." >> backup_log.txt; exit 1; }
if [ $? -ne 0 ]; then
    echo "Error copying files to remote server." >> backup_log.txt
    exit 1
fi

# Run remote script
zip_path=$REMOTE_DESTINATION/$zip_name
ssh -o StrictHostKeyChecking=no "$REMOTE_USER"@"$REMOTE_ADDRESS" "bash $zip_path $REMOTE_MYSQL_USER $REMOTE_MYSQL_PASSWORD $REMOTE_MYSQL_DATABASE $REMOTE_RESTORE_DESTIONATION" >> backup_log.txt 2>&1
if [ $? -ne 0 ]; then
    echo "Error running script on remote server." >> backup_log.txt
    exit 1
fi

# Delete backups from the previous month, retaining the earliest backup for each day
previous_month=$(date -d 'last month' +'%Y%m')
IFS=$'\n' read -r -a backups_to_delete <<< "$(find "$BACKUP_DIR" -type f -name "backup_*_${previous_month}.zip")"
declare -A earliest_backup_per_day
for backup in "${backups_to_delete[@]}"; do
    day=$(basename "$backup" | sed 's/.*backup_\(.*\)\.zip/\1/')
    if [[ ! ${earliest_backup_per_day[$day]} || "$backup" < "${earliest_backup_per_day[$day]}" ]]; then
        earliest_backup_per_day[$day]="$backup"
    fi
done
for backup in "${backups_to_delete[@]}"; do
    day=$(basename "$backup" | sed 's/.*backup_\(.*\)\.zip/\1/')
    if [[ "$backup" != "${earliest_backup_per_day[$day]}" ]]; then
        rm "$backup"
    fi
done
unset IFS>> backup_log.txt 2>&1

# Delete local tar and mysql files
(rm "$tar_filename" "$mysql_dump_filename" >> backup_log.txt 2>&1) || { echo "$(date +'%Y-%m-%d %H:%M:%S') Error deleting local backup files." >> backup_log.txt; exit 1; }

echo "Backup and transfer completed successfully." >> backup_log.txt
