#!/bin/sh
# SCRIPT: linux_fs_check.sh
# AUTHOR: George R
# DATE: 180514
# LAST CHANGE:
# FUNCTION: Check filelist % full for an Linux system
# Make a list of filesystems (excluding NFS and CIFS mounts)
# For each filesystem:
# First check if FS is on skip list
#   If it is ignore % space used
# Second check if FS is in exclusion list
#   If it is use value in list to compare against
# Finally compare against default value (MAX_PERCENT)

#MAILTO="george.rogers@foodstuffs-si.co.nz"
#MAILTO="matt.grant@foodstuffs-si.co.nz"
MAILTO="itbasissupport@foodstuffs-si.co.nz"
MAILTO_DEBUG="matt.grant@foodstuffs-si.co.nz"
DEBUG="1"       # set to any value to turn debug on
TIME=`date`
HOSTNAME=`hostname`


# skip checking any filesystems in this list
SKIP_LIST="/proc"

DF_MAX_PERCENT=90  # default warning value
# specially check any filesystems in this list against given value
# format is "/filesystem,80" additional entries should be on a new line
DF_EXCEPTION_LIST=""
# BTRFS max metadata %
BTRFS_MAX_METADATADUP_PERCENT=75
# BTRFS max system %
BTRFS_MAX_SYSTEMDUP_PERCENT=75

[ -n "$DEBUG" ] && DF_MAX_PERCENT=5
[ -n "$DEBUG" ] && BTRFS_MAX_METADATADUP_PERCENT=5
[ -n "$DEBUG" ] && BTRFS_MAX_SYSTEMDUP_PERCENT=5
[ -n "$DEBUG" ] && MAILTO="$MAILTO_DEBUG"

PATH="$PATH:/sbin:/usr/sbin"
DF="/usr/local/bin/pybtrfs df"

alert ()
# send mail with detail
{
	local FS="$1"
	local WARN_TYPE="$2"
	local PERCENT="$3"
	local THRESHOLD="$4"

	BODY="
DATETIME:\t$TIME 
HOSTNAME:\t$HOSTNAME 
FILESYSTEM:\tFilesystem ${FS} is at ${PERCENT}% 
THRESHOLD:\tTrigger Point is ${THRESHOLD}%"

	SUBJECT="WARNING $WARN_TYPE usage on $HOSTNAME is ${PERCENT}% for $FS"
	echo -e "$BODY" | mailx -s "$SUBJECT" "$MAILTO"
}

check_df ()
# look for match with EXCEPTION_LIST
{
	local DF_PERCENT MAX FS SIZE AVAILABLE USE_PERC MOUNT_PT

	while read FS SIZE USED AVAILABLE USE_PERC MOUNT_PT; do  

		if [ "$FS" = 'Filesystem' ]; then
			continue
		fi

		# skip if fs on exclusion list
		if echo "$MOUNT_PT" | grep -q "$SKIP_LIST"; then
			if [ $DEBUG ]; then echo "$1 on Skip list -ignoring"; fi
			continue
		fi

		DF_PERCENT=`echo ${USE_PERC} | cut -d "%" -f1`
		if echo "$DF_EXCEPTION_LIST" | grep -qw "$MOUNT_PT"; then
			if [ $DEBUG ]; then  
				echo "$1 in Exception List" 
			fi
			MAX=`echo "$DF_EXCEPTION_LIST" | grep -w "$MOUNT_PT" | cut -d "," -f2`
			if [ $DEBUG ]; then
				echo "Compare $DF_PERCENT vs max of $MAX"; 
			fi
		else
			if [ $DEBUG ]; then 
				echo "$MOUNT_PT check against $DF_MAX_PERCENT"; 
			fi
			MAX=$DF_MAX_PERCENT
		fi
		if [ $DF_PERCENT -ge $MAX ]
		then
			if [ $DEBUG ]; then echo "Found $MOUNT_PT at $DF_PERCENT - max is $MAX "; fi
			alert "$MOUNT_PT" "Space" "$DF_PERCENT" "$MAX"
		fi
	done
}

# script starts
# create list of filesystems, but exclude remote mounts and header, and BTRFS
# check each filesystem against lists
${DF} --local | check_df

