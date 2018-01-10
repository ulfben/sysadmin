#!/bin/bash
# backup.sh - a basic backup script with grandfather-father-son rotation:
#  - Runs mysqldump and then creates a compressed & encrypted archive of $FOLDERS_TO_BACKUP
#  - The rotation will do a daily backup Sunday through Friday.
#  - On Saturday a weekly backup is done giving you four weekly backups a month.
#  - The monthly backup is done on the first of the month, rotating two monthly backups (odd/even)
#
# The script was inspired by the Ubuntu Server Guide https://help.ubuntu.com/lts/serverguide/backups.html
# 
# backup.sh will archive using tar + gzip (multithreaded) and then encrypt using 7z (AES256, no compression)
# This is MUCH faster than it is to let 7z compress-&-encrypt in a single step - even at x=0.
# Plus 7z is unfit for backup duty on Linux (see the man-page) so the tarball stays. :)
#
# Add a cron job to run at 03:00 every day:
#   $ crontab -e
#   0 3 * * * bash /home/myuser/scripts/backup.sh > /var/log/backup.log 2>&1
#
# //Ulf Benjaminsson, 2018-01
if [ $(id -u) != 0 ] ; then
    echo "please run backup.sh as root" >&2
    exit 1
fi

HOSTNAME=$(hostname -s)
TIMESTAMP_FORMAT='%Y-%m-%d %H:%M:%S'
ARCHIVE_PWD='secret' #used for 7z encryption. Will show up in process lists.
BACKUP_OWNER='myuser'
BACKUP_GROUP='mygroup'

MYSQL_DUMP_USER='BACKUPUSER'
MYSQL_DUMP_PWD="secret" #will NOT be printed in logs or process lists
DB_DESTINATION='/home/myuser/mysqldump'

FOLDERS_TO_BACKUP='/home /etc /var/www /var/log /usr/local /usr/share/phpmyadmin /root /boot /opt'
ARCHIVE_DESTINATION='/media/backup/rotatingbackup'

# log(): timestamped output
# Bash version in numbers like XYYYZZZ, where X is major version, YYY is minor, ZZZ is subminor.
printf -v BV '%d%03d%03d' ${BASH_VERSINFO[0]} ${BASH_VERSINFO[1]} ${BASH_VERSINFO[2]}
if [[ ${BV} -gt 4002000 ]]; then
	log() { # Fast (builtin) but low precision (seconds)
		printf "[%(${TIMESTAMP_FORMAT})T] %s\\n" '-1' "$*"
	}
else
	log() { # Slower, higher precisions (microseconds). Support legacy bash versions.    
		echo "[$(date +"${TIMESTAMP_FORMAT}")] $*"
	}
fi

# which week of the month is it (1-4)?
day_num=$(date +%-d)
if (( day_num <= 7 )); then
	week_file="${HOSTNAME}-week1"
elif (( day_num <= 14 )); then
	week_file="${HOSTNAME}-week2"
elif (( day_num <= 21 )); then
	week_file="${HOSTNAME}-week3"
else # day_num < 32
	week_file="${HOSTNAME}-week4"
fi

# is the month odd or even?
is_even_month=$(expr $(date +%m) % 2)
if [ "$is_even_month" -eq 0 ]; then
	month_file="${HOSTNAME}-month2"
else
	month_file="${HOSTNAME}-month1"
fi

# create archive filename.
day=$(date +%A)
if [ "$day_num" == 1 ]; then
	archive_name=$month_file
elif [ "$day" != "Saturday" ]; then
        archive_name="${HOSTNAME}-$day"
else 
	archive_name=$week_file 
fi

#build the full paths before starting the real work
database_file="${DB_DESTINATION}/${archive_name}.sql.7z"
archive_file="${ARCHIVE_DESTINATION}/${archive_name}.tgz"
encrypted_archive_file="${archive_file}.7z"

log "Starting backup.sh"

if [ ! -d "${DB_DESTINATION}" ] 
then
	log "ERROR: ${DB_DESTINATION} does not exist. Skipping mysqldump."
else
	log "Dumping MySQL to ${database_file}"	
	rm -f "${database_file}" # delete any pre-existing archive manually, because 7za is a PITA.
	export MYSQL_PWD=$MYSQL_DUMP_PWD #read https://unix.stackexchange.com/a/369568 for the security implications	
	mysqldump -u ${MYSQL_DUMP_USER} --all-databases | 7za a -mhe=on -p"${ARCHIVE_PWD}" -mx=9 -si "${database_file}"
	unset MYSQL_PWD
	chown ${BACKUP_OWNER}:${BACKUP_GROUP} "${database_file}"	
fi # mysqldump

if [ ! -d "${ARCHIVE_DESTINATION}" ] 
then
	log "ERROR: ${ARCHIVE_DESTINATION} does not exist. Skipping backup ${archive_name}"
	log "backup.sh finished with errors!"
else
	log "Backing up ${FOLDERS_TO_BACKUP} to ${archive_file}"
	tar --use-compress-program=pigz -Pcf "${archive_file}" $FOLDERS_TO_BACKUP
		
	# delete any pre-existing encrypted archive manually, because 7za is a PITA.
	rm -f "${encrypted_archive_file}"
	
	log "Encrypting ${archive_file} to ${encrypted_archive_file}"
	7za a -mhe=on -p"${ARCHIVE_PWD}" -mx=0 "${encrypted_archive_file}" "${archive_file}"

	#make sure the 7z was created before deleting the tarball
	if [ -e "${encrypted_archive_file}" ]
	then	
		log "Removing unencrypted ${archive_file}"
		rm -f "${archive_file}"
		chown ${BACKUP_OWNER}:${BACKUP_GROUP} "${encrypted_archive_file}" 
	else
		chown ${BACKUP_OWNER}:${BACKUP_GROUP} "${archive_file}" 
		log "ERROR: 7z failed! Leaving unencrypted ${archive_file} on drive!"
	fi
	
	log "backup.sh finished!"
	#list files ${ARCHIVE_DESTINATION} to check file sizes.	
	ls -lh "${ARCHIVE_DESTINATION}/"
fi # archive creation
