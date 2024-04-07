#!/bin/bash
# backup_database.sh - a basic backup script with grandfather-father-son rotation:
#  - The rotation will do a daily backup Sunday through Friday.
#  - On Saturday a weekly backup is done giving you four weekly backups a month.
#  - The monthly backup is done on the first of the month, rotating two monthly backups (odd/even)
#
# The script was inspired by the Ubuntu Server Guide https://help.ubuntu.com/lts/serverguide/backups.html
# To simplify restorations this script will both dump --all-databases, and then proceed to dump 
# every user-created database individually. 
#
# Add a cron job to run at 23:00 every day:
#   $ crontab -e
#   0 23 * * * bash /path/to/backup_database.sh > /var/log/backup_database.log 2>&1
#
# //Ulf Benjaminsson, 2024-04

HOSTNAME=$(hostname -s)
TIMESTAMP_FORMAT='%Y-%m-%d %H:%M:%S'
ARCHIVE_PWD='REDACTED' #used for 7z encryption. Will show up in process lists.
BACKUP_OWNER='REDACTED'
BACKUP_GROUP='REDACTED'

MYSQL_DUMP_USER='BACKUPUSER'
MYSQL_DUMP_PWD="REDACTED" #will not be printed in logs or process lists
DB_DESTINATION='/home/[USER]/mysqldump'

log() {
    if [[ ${BASH_VERSINFO[0]} -gt 4 || (${BASH_VERSINFO[0]} -eq 4 && ${BASH_VERSINFO[1]} -ge 2) ]]; then
        printf "[%(${TIMESTAMP_FORMAT})T] %s\\n" '-1' "$@"
    else
        echo "[$(date +"${TIMESTAMP_FORMAT}")] $*"
    fi
}

perform_backup() {
    local database=$1
    local destination_file=$2

    log "Dumping database ${database} to ${destination_file}"
    rm -f "${destination_file}" # Ensure the old backup is removed
    
	if ! mysqldump -u "${MYSQL_DUMP_USER}" "${database}" | 7za a -mhe=on -p"${ARCHIVE_PWD}" -mx=9 -si "${destination_file}"; then
		log "Error occurred during backup of database ${database}"
		return 1
	fi    

    chown ${BACKUP_OWNER}:${BACKUP_GROUP} "${destination_file}"
}

# Determine postfix based on the date
day=$(date +%A)
day_num=$(date +%-d)
is_even_month=$(( $(date +%m) % 2 ))

if [ "$day_num" -eq 1 ]; then
    if [ "$is_even_month" -eq 0 ]; then
        postfix="month2"
    else
        postfix="month1"
    fi
elif [ "$day" = "Saturday" ]; then
    # Determine which week of the month it is
    if (( day_num <= 7 )); then
        postfix='week1'
    elif (( day_num <= 14 )); then
        postfix='week2'
    elif (( day_num <= 21 )); then
        postfix='week3'
    else
        postfix='week4'
    fi
else
    postfix="${day}"
fi

export MYSQL_PWD=$MYSQL_DUMP_PWD

# Prepare the destination
mkdir -p "$DB_DESTINATION" || exit 1
chown -R ${BACKUP_OWNER}:${BACKUP_GROUP} "$DB_DESTINATION"

# Backup all databases
target="${DB_DESTINATION}/${HOSTNAME}-${postfix}.sql.7z"
perform_backup "--all-databases" "${target}"

# Backup each database individually
mysql --user "${MYSQL_DUMP_USER}" -e "SHOW DATABASES;" -s | grep -vE '^(Database|information_schema|performance_schema|mysql|sys)$' |
while IFS= read -r database; do
    mkdir -p "${DB_DESTINATION}/${database}/" # Ensure the directory exists
    individual_archive_name="${database}-${postfix}.sql.7z"
    target="${DB_DESTINATION}/${database}/${individual_archive_name}"
    perform_backup "${database}" "${target}"
done

unset MYSQL_PWD
