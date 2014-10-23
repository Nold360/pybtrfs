#!/bin/bash
# SCRIPT: linux_fs_check.sh
# AUTHOR: George R and Mat Grant
# DATE: 20141014
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
DEBUG=""       # set to any value to turn debug on
IGNORE_BLOCK="" # set if you want to ignore /BLOCK output
TIME=`date`
HOSTNAME=`hostname`


# skip checking any filesystems in this list
SKIP_LIST="/proc"

DF_MAX_PERCENT=90  # default warning value
# specially check any filesystems in this list against given value
# format is "/filesystem,80" additional entries should be on a new line
DF_EXCEPTION_LIST=""
# Do extensive BTRFS checks - extra DF argument
DF_BTRFS_CHECK_ALL="--btrfs-all"
#DF_BTRFS_CHECK_ALL=""
# BTRFS max metadata %
BTRFS_MAX_METADATA_PERCENT=75
# BTRFS max system %
BTRFS_MAX_SYSTEM_PERCENT=75

[ -n "$DEBUG" ] && DF_MAX_PERCENT=5
[ -n "$DEBUG" ] && BTRFS_MAX_METADATA_PERCENT=5
[ -n "$DEBUG" ] && BTRFS_MAX_SYSTEM_PERCENT=5
[ -n "$DEBUG" ] && MAILTO="$MAILTO_DEBUG"

PATH="$PATH:/sbin:/usr/sbin"
DF="/usr/local/bin/pybtrfs"
DF_SUBARG="df"
PROGNAME=`basename $0`

if ! [ -x "${DF}" ]; then
	echo "${PROGNAME}: Can't find '${DF}' or it is not executable." 1>&2
	exit 2
fi

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

		# skip BTRFS DATA - checked under df
		if echo "$MOUNT_PT" | grep -q "\/DATA$"; then
			continue
		fi
		# skip BTRFS DATA - checked under df
		if [ -n "$IGNORE_BLOCK" ] && echo "$MOUNT_PT" | grep -q "\/BLOCK$"; then
			continue
		fi
		# skip if fs on exclusion list
		if echo "$MOUNT_PT" | grep -q "$SKIP_LIST"; then
			if [ $DEBUG ]; then echo "$1 on Skip list -ignoring"; fi
			continue
		fi

		DF_PERCENT=`echo ${USE_PERC} | cut -d "%" -f1`
		if echo "$MOUNT_PT" | grep -q 'SYSTEM$'; then
			if [ $DEBUG ]; then 
				echo "$MOUNT_PT check against $BTRFS_MAX_SYSTEM_PERCENT"; 
			fi
			MAX="$BTRFS_MAX_SYSTEM_PERCENT"
		elif echo "$MOUNT_PT" | grep -q 'METADATA$'; then
			if [ $DEBUG ]; then 
				echo "$MOUNT_PT check against $BTRFS_MAX_METADATA_PERCENT"; 
			fi
			MAX="$BTRFS_MAX_METADATA_PERCENT"
		elif echo "$DF_EXCEPTION_LIST" | grep -qw "$MOUNT_PT"; then
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
${DF} ${DF_SUBARG} --local ${DF_BTRFS_CHECK_ALL} | check_df

