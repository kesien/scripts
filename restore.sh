#!/bin/bash

# Check if the required arguments are provided
if [ "$#" -ne 5 ]; then
    echo "$(date +'%Y-%m-%d %H:%M:%S') [REMOTE] Usage: $0 <zip_file> <mysql_user> <mysql_password> <mysql_database> <destionation_directory>"
    exit 1
fi

zip_file="$1"
mysql_user="$2"
mysql_password="$3"
mysql_database="$4"
destination_directory="$5"

# Extract the directory where the zip file is located
zip_directory=$(dirname "$zip_file")
zip_name=$(basename $zip_file)

cd "$zip_directory"

# Unzip the provided zip file
echo "$(date +'%Y-%m-%d %H:%M:%S') [REMOTE] Unzipping $zip_name..."
unzip -qo "$zip_file"|| { echo "$(date +'%Y-%m-%d %H:%M:%S') [REMOTE] Error unzipping the file."; exit 1; }

# Extract the tar file name from the zip
backup_filename=$(unzip -l "$zip_file" | grep ".tar" | awk '{ print $4 }')

# Untar the contents of the tar file
echo "$(date +'%Y-%m-%d %H:%M:%S') [REMOTE] Extracting the contents of $backup_filename to $destination_directory"
(tar -xzf "$backup_filename" -C $destination_directory >> /dev/null 2>&1) || { echo "$(date +'%Y-%m-%d %H:%M:%S') [REMOTE] Error extracting the file $backup_filename"; exit 1; }

# Import the MySQL file into the specified database
echo "$(date +'%Y-%m-%d %H:%M:%S') [REMOTE] Importing ${backup_filename%.tar}.sql into database: $mysql_database"
mysql -u "$mysql_user" -p"$mysql_password" "$mysql_database" < "${backup_filename%.tar}.sql" || { echo "$(date +'%Y-%m-%d %H:%M:%S') [REMOTE] Error importing MySQL file."; exit 1; }

# Delete older zip files after completion, retaining only the most recent one
echo "$(date +'%Y-%m-%d %H:%M:%S') [REMOTE] Deleting old zip files keeping only the most recent one"
find ./ -maxdepth 1 -type f -name "backup_*.zip" -not -name "$zip_name" -exec rm {} +

# Delete all files after completion
echo "$(date +'%Y-%m-%d %H:%M:%S') [REMOTE] Deleting temporary files"
rm "$backup_filename" "${backup_filename%.tar}.sql" || { echo "$(date +'%Y-%m-%d %H:%M:%S') [REMOTE] Error deleting files."; exit 1; }

echo "$(date +'%Y-%m-%d %H:%M:%S') [REMOTE] All tasks completed successfully"