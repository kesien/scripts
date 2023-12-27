#!/bin/bash

# Check if the required arguments are provided
if [ "$#" -ne 5 ]; then
    echo "$(date +'%Y-%m-%d %H:%M:%S') Usage: $0 <zip_file> <mysql_user> <mysql_password> <mysql_database> <destionation_directory>" >> backup_log.txt
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
unzip -q "$zip_file" >> backup_log.txt 2>&1 || { echo "$(date +'%Y-%m-%d %H:%M:%S') Error unzipping the file." >> backup_log.txt; exit 1; }

# Extract the tar file name from the zip
backup_filename=$(unzip -l "$zip_file" | grep ".tar" | awk '{ print $4 }')

# Untar the contents of the tar file
tar -xzf "$backup_filename" backup_log.txt 2>&1 || { echo "$(date +'%Y-%m-%d %H:%M:%S') Error untarring the file." >> backup_log.txt; exit 1; }

# Copy the extracted files to the specified directory, overwriting existing files
cp -r "$backup_filename" "$destination_directory" || { echo "$(date +'%Y-%m-%d %H:%M:%S') Error copying files to destination directory." >> backup_log.txt; exit 1; }

# Import the MySQL file into the specified database
mysql -u "$mysql_user" -p"$mysql_password" -e "source $destination_path/$backup_filename.sql" "$mysql_database" || { echo "$(date +'%Y-%m-%d %H:%M:%S') Error importing MySQL file." >> backup_log.txt; exit 1; }

# Delete older zip files after completion, retaining only the most recent one
find ./ -maxdepth 1 -type f -name "backup_*.zip" -not -name "$zip_name" -exec rm {} +

# Delete all files after completion
rm -rf "$backup_filename.tar" "$backup_filename" "$backup_filename.sql" || { echo "$(date +'%Y-%m-%d %H:%M:%S') Error deleting files." >> backup_log.txt; exit 1; }

echo "$(date +'%Y-%m-%d %H:%M:%S') Backup restoration completed successfully." >> backup_log.txt