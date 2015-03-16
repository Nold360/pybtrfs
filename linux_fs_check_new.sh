#!/bin/bash
#
# Copyright (c) Foodstuffs (South Island) Limited,
#               Christchurch, New Zealand 2014-2015
#
#    This file is part of pybtrfs.
#
#    Pybtrfs is free software: you can redistribute it and/or modify
#    it under the terms of the GNU  General Public License as published
#    by the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    Pybtrfs is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU  General Public License for more details.
#
#    You should have received a copy of the GNU  General Public License
#    along with pybtrfs.  If not, see <http://www.gnu.org/licenses/>.
#
# SCRIPT: linux_fs_check.sh
# AUTHOR: George R and Matt Grant

DEBUG=""      # set to any value to turn debug on
TIME=`date`
HOSTNAME=`hostname`

#==============Config file here================
# MAIL destination(s)
MAILTO="please-set-me@example.org"
# Use this for DEBUG email
MAILTO_DEBUG="debug-destination@example.org"
# skip checking any filesystems in this list
# Note that FS are on separate lines
SKIP_LIST="
/proc"
# Default warning value
DF_MAX_PERCENT=90
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
# BTRFS BLOCK check waterline
BTRFS_BLOCK_CHECK_THRESHOLD=90
# Ignore BLOCK for checks
IGNORE_BLOCK="1"
#==============Config file here================

CFG_FILE="/etc/default/linux_fs_check_new"
[ -f "$CFG_FILE" ] && . "$CFG_FILE" || true

PATH="$PATH:/sbin:/usr/sbin"
DF="/usr/local/bin/pybtrfs"
DF_SUBARG="df"
PROGNAME=`basename $0`
VERBOSE=""

usage () {
	echo 1>&2
	echo "Usage: $PROGNAME [-dh]" 1>&2
	echo 1>&2
	echo "                  -d     turn on debug" 1>&2
	echo "                  -h     display this help" 1>&2
	echo "                  -v     verbose output" 1>&2
	echo 1>&2
	echo "                  Config file is '${CFG_FILE}'" 1>&2
	echo 1>&2
	exit 1
}

OPTIND=1
while getopts dhv F; do
	case $F in
	d)	DEBUG="1"
		VERBOSE="1"
		;;
	v)	VERBOSE="1"
		;;
	h)	usage
		exit 1
		;;
	\?)
		usage
		exit 1
		;;
	*)
		usage
		exit 1
		;;
esac
done
shift $(( $OPTIND - 1 ))

if [ $# -ge 1 ]; then
	# Deal with any arguments left that are not switches
	usage
	exit 1
fi

[ -n "$DEBUG" ] && DF_MAX_PERCENT=5
[ -n "$DEBUG" ] && BTRFS_MAX_METADATA_PERCENT=5
[ -n "$DEBUG" ] && BTRFS_MAX_SYSTEM_PERCENT=5
[ -n "$DEBUG" ] && BTRFS_BLOCK_CHECK_THRESHOLD=90
[ -n "$DEBUG" ] && MAILTO="$MAILTO_DEBUG"

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
	local DF_PERCENT MAX FS SIZE AVAILABLE USE_PERC MOUNT_PT BLOCK_USED_PERCENT
	local BLK_PERC BLK_CHECK_PATH

	while read FS SIZE USED AVAILABLE USE_PERC MOUNT_PT; do  

		if [ "$FS" = 'Filesystem' ]; then
			continue
		fi

		# Put BLOCK percent used into an array
		if echo "$MOUNT_PT" | grep -q "\/BLOCK$"; then
			BLOCK_USED_PERCENT="${BLOCK_USED_PERCENT}${MOUNT_PT} ${USE_PERC}
"
		fi

		# skip BTRFS DATA - checked under df
		if echo "$MOUNT_PT" | grep -q "\/DATA$"; then
			continue
		fi
		# skip BTRFS BLOCK - checked under df
		if [ -n "$IGNORE_BLOCK" ] && echo "$MOUNT_PT" | grep -q "\/BLOCK$"; then
			continue
		fi
		# skip if fs on exclusion list
		if echo "$SKIP_LIST" | grep -q "^$MOUNT_PT\$"; then
			if [ $VERBOSE ]; then echo "$MOUNT_PT on Skip list -ignoring"; fi
			continue
		fi
		# Skip BTRFS checks if there is unallocated BLOCK available
		if echo "$MOUNT_PT" | grep -q 'SYSTEM$\|METADATA$'; then
			BLK_CHECK_PATH=`echo "$MOUNT_PT" | perl -pe 's/^(\S*\/)(SYSTEM$|METADATA$)/\1/'`
			[ "$BLK_CHK_PATH" != '/' ] && BLK_CHECK_PATH=`echo "$BLK_CHECK_PATH" | perl -pe 's/^(\S+)\//\1/'`
			BLK_PERC=`echo "$BLOCK_USED_PERCENT" | grep "$BLK_CHECK_PATH" | perl -pe 's/^\S+\s+(\S+)$/\1/' | cut -d "%" -f 1`
			[ $DEBUG ] && echo "BLK_CHECK_PATH: $BLK_CHECK_PATH"
			[ $DEBUG ] && echo "BLK_PERC: $BLK_PERC"
			if [ $BLK_PERC -le $BTRFS_BLOCK_CHECK_THRESHOLD ]; then
				[ $VERBOSE ] && echo "$MOUNT_PT at ${BLK_PERC}% <= ${BTRFS_BLOCK_CHECK_THRESHOLD}% - skipped as there is unused BLOCK available"
 				continue
			fi
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
			if [ $VERBOSE ]; then  
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
			if [ $VERBOSE ]; then echo "$MOUNT_PT at ${DF_PERCENT}% - max is ${MAX}% "; fi
			if [ -z "$VERBOSE" ]; then
				alert "$MOUNT_PT" "Space" "$DF_PERCENT" "$MAX"
			fi
		else
			if [ $VERBOSE ]; then echo "$MOUNT_PT at ${DF_PERCENT}% used."; fi
		fi
	done
}

# script starts
# create list of filesystems, but exclude remote mounts and header, and BTRFS
# check each filesystem against lists
${DF} ${DF_SUBARG} --local ${DF_BTRFS_CHECK_ALL} | check_df

