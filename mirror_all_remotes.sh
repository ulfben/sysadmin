#!/bin/bash
#mirror_all_remotes.sh - sync a remote folder to the local filesystem
# should be used with read-only service accounts and public key authentication on the remote side.
#log-fu courtesy of https://serverfault.com/a/103569
exec 3>&1 4>&2 #save original pipes 
trap 'exec 2>&4 1>&3' 0 1 2 3 15 RETURN #restore pipes on exit and sigterm

#error handler to exit with useful info
function error() {
  local message="$1"
  local code="${2:-1}"
  echo "Error: ${message}; exiting with status ${code}" 1>&2
  exit "${code}"
}

BACKUP_DIR=/media/wd_4tb_blue
LOG_DIR="$BACKUP_DIR"/logs
mkdir -p "$LOG_DIR" || error "Unable to create $LOG_DIR" 1;

declare -A REMOTES #pre-declare an associative array,
# mapping each remote host to a local target directory
REMOTES[example.com:22]="$BACKUP_DIR/example"
REMOTES[anotherexample.com:22]="$BACKUP_DIR/anotherexample"

#shared settings:
USER='backup'
PASSWORD='' 	#empty password, relying on public key authentication.
REMOTE_DIR='./' #chroot on the server side ensures we're always placed directly in the target dir
ARGS="--continue --delete --parallel=8 --skip-noaccess"
EXCLUDES="--exclude 'cache' --exclude '.git'"

for HOST in "${!REMOTES[@]}"; do
	LOCAL_DIR=${REMOTES[$HOST]}
	HOSTNAME=${HOST%:*}  #delete from : to the right
	LOGFILE="$LOG_DIR/$HOSTNAME-$(date +%Y%m).log" #one logfile per host, per month.	
	mkdir -p "$LOCAL_DIR" || error "Unable to create $LOCAL_DIR" 1;
	exec 1>>"$LOGFILE" 2>&1 #append stdout to logfile, direct stderr to stdout.

	echo "Transferring $REMOTE_DIR from $HOST to $LOCAL_DIR"
	date +"%F %T"
	echo sftp://"$USER":"$PASSWORD"@"$HOST" -e "mirror $REMOTE_DIR $LOCAL_DIR $ARGS $EXCLUDES; exit;"
	lftp sftp://"$USER":"$PASSWORD"@"$HOST" -e "mirror $REMOTE_DIR $LOCAL_DIR $ARGS $EXCLUDES; exit;"
	echo "Transfer from $HOST finished"
	date +"%F %T"
	echo "#######"
done

exit 0
