#!/bin/bash
log_file="$(pwd)/backup_log.txt"
echo "$(date +'%Y-%m-%d %H:%M:%S') Backup script staring ..." >> $log_file
dotenv_file="./.env"
source "$dotenv_file" || { echo "$(date +'%Y-%m-%d %H:%M:%S') Error: Unable to load environment variables from $dotenv_file" >> $log_file; exit 1; }

cd $BACKUP_DESTINATION
# Create a tar file with the specified naming convention
tar_filename="backup_${NAME}_$(date +'%Y%m%d').tar"
echo "$(date +'%Y-%m-%d %H:%M:%S') Creating tar file: $tar_filename" >> $log_file
(tar -czvf "$tar_filename" -C "$APPLICATION_PATH" . >> /dev/null 2>&1) || { echo "$(date +'%Y-%m-%d %H:%M:%S') Error creating tar file." >> $log_file; exit 1; }

# Create a mysqldump with the same naming convention
mysql_dump_filename="backup_${NAME}_$(date +'%Y%m%d').sql"
echo "$(date +'%Y-%m-%d %H:%M:%S') Creating mysql dump file: $mysql_dump_filename" >> $log_file
(mysqldump -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" > "$mysql_dump_filename") || { echo "$(date +'%Y-%m-%d %H:%M:%S') Error creating mysqldump file." >> $log_file; exit 1; }

# Zip the tar and SQL files into the same zip
zip_name="backup_${NAME}_$(date +'%Y%m%d').zip"
echo "$(date +'%Y-%m-%d %H:%M:%S') Creating $zip_name file from $tar_filename and $mysql_dump_filename" >> $log_file
(zip -mq "$zip_name" "$tar_filename" "$mysql_dump_filename") || { echo "$(date +'%Y-%m-%d %H:%M:%S') Error zipping files." >> $log_file; exit 1; }

# Copy files to another server using scp
echo "$(date +'%Y-%m-%d %H:%M:%S') Copying files to remote host ..." >> $log_file
(scp -o StrictHostKeyChecking=no "$zip_name" "$REMOTE_USER"@"$REMOTE_ADDRESS":"$REMOTE_DESTINATION" >> $log_file 2>&1) || { echo "$(date +'%Y-%m-%d %H:%M:%S') Error copying files to remote server." >> $log_file; exit 1; }

# Run remote script
zip_path=$REMOTE_DESTINATION/$zip_name
echo "$(date +'%Y-%m-%d %H:%M:%S') Start running remote script ..." >> $log_file
ssh -o StrictHostKeyChecking=no "$REMOTE_USER"@"$REMOTE_ADDRESS" "bash $REMOTE_SCRIPT_PATH \"$zip_path\" \"$REMOTE_MYSQL_USER\" \"$REMOTE_MYSQL_PASSWORD\" \"$REMOTE_MYSQL_DATABASE\" \"$REMOTE_RESTORE_DESTINATION\"" >> $log_file 2>&1
if [ $? -ne 0 ]; then
    echo "Error running script on remote server." >> $log_file
    exit 1
fi
echo "$(date +'%Y-%m-%d %H:%M:%S') Remote script finished" >> $log_file

# Delete backups from the previous month, retaining the latest backup for each month
echo "$(date +'%Y-%m-%d %H:%M:%S') Deleting files from the previous month, retaining the latest backup for each month" >> $log_file
count=0
previous_month=$(date -d 'last month' +'%Y%m')
mapfile -t backups_to_delete < <(find "$BACKUP_DESTINATION" -type f -name "backup_${NAME}_${previous_month}*.zip")
latest_backup=""
for backup in "${backups_to_delete[@]}"; do
    if [[ -z "$latest_backup" || "$backup" > "$latest_backup" ]]; then
        latest_backup="$backup"
    fi
done
for backup in "${backups_to_delete[@]}"; do
    if [[ "$backup" != "$latest_backup" ]]; then
        rm "$backup"
        ((count=count+1))
    fi
done
echo "$(date +'%Y-%m-%d %H:%M:%S') Deleted $count files from the previous month." >> $log_file

echo "$(date +'%Y-%m-%d %H:%M:%S') Backup and transfer completed successfully." >> $log_file