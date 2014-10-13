#o "100 * 169.32 / 307.19" | bc -l/bin/sh
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
DEBUG=""       # set to any value to turn debug on
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
	local DF_PERCENT MAX
	DF_PERCENT=`df "$1" | tail -n 1 | tr -s " " " " | cut -d " " -f5 | cut -d "%" -f1`
	if echo "$DF_EXCEPTION_LIST" | grep -qw "$1"; then
  		if [ $DEBUG ]; then  
			echo "$1 in Exception List" 
		fi
  		MAX=`echo "$DF_EXCEPTION_LIST" | grep -w "$1" | cut -d "," -f2`
   		if [ $DEBUG ]; then
			echo "Compare $DF_PERCENT vs max of $MAX"; 
		fi
	else
   		if [ $DEBUG ]; then 
			echo "$1 check against $DF_MAX_PERCENT"; 
		fi
   		MAX=$DF_MAX_PERCENT
	fi
	if [ $DF_PERCENT -ge $MAX ]
	then
  		if [ $DEBUG ]; then echo "Found $FS at $DF_PERCENT - max is $MAX "; fi
  		alert "$FS" "Space" "$DF_PERCENT" "$MAX"
	fi
}

fix_btrfs_datasize () {

	while read STD_IN; do
		NUMBER=`echo "$STD_IN" | perl -pe 's/^([0-9]+).*$/\1/'`
		UNIT=`echo "$STD_IN" | perl -pe 's/^[0-9\.]+([BKMGTPEi]*)$/\1/'`

		if [ -z "$UNIT" ]; then
			echo "$1"
			return 0
		fi

		case "$UNIT" in
		
		EiB|EB)
			echo  "1024 * 1024 * 1024 * 1024 * 1024 * 1024 * $NUMBER" | bc
			return 0
			;;
		PiB|PB)
			echo  "1024 * 1024 * 1024 * 1024 * 1024 * $NUMBER" | bc
			return 0
			;;
		TiB|TB)
			echo  "1024 * 1024 * 1024 * 1024 * $NUMBER" | bc
			return 0
			;;
		GiB|GB)
			echo  "1024 * 1024 * 1024 * $NUMBER" | bc
			return 0
			;;
		MiB|MB)
			echo "1024 * 1024 * $NUMBER" | bc
			return 0
			;;
		KiB|KB)
			echo "1024 * $NUMBER" | bc
			return 0
			;;
		esac
	done

	return 1
}

get_btrfs_data () {

	if [ $# -ne 2 ]; then
		echo "$0: get_btrfs_data requires 2 arguments, <fs-root-path> <Metadata|System>" 1>&2
		exit 2
	fi

 	local BTRFS_OUT=`btrfs filesystem df "$1" | grep "${2}, DUP" | perl -pe "s/^${2}, DUP: (.*)\$/\1/" | tr ',' ' '`
	local TOTAL=`echo $BTRFS_OUT | perl -pe 's/^total=(\S+).*$/\1/' | fix_btrfs_datasize`
	local USED=`echo $BTRFS_OUT | perl -pe 's/^total=\S+\s+used=(\S+)$/\1/' | fix_btrfs_datasize`

	echo "local USED=${USED}"
	echo "local TOTAL=${TOTAL}"
}

check_btrfs_metadata_DUP () 
{
	local PERCENT

	eval `get_btrfs_data "$1" 'Metadata'`
	
	[ -n "$DEBUG" ] && echo "Metadata TOTAL: $TOTAL"
	[ -n "$DEBUG" ] && echo "Metadata USED: $USED"

	PERCENT=`echo "100 * $USED / $TOTAL" | bc`
	[ -n "$DEBUG" ] && echo "Metadata PERCENT: $PERCENT"
	[ -n "$DEBUG" ] && echo "Metadata THRESH: $BTRFS_MAX_METADATADUP_PERCENT"
	
	if [ $PERCENT -lt $BTRFS_MAX_METADATADUP_PERCENT ]; then
		return 0
	fi


	[ -n "$DEBUG" ] && echo "Metadata ALERTING"
  	alert "$FS" "Metadata" "$PERCENT" "$BTRFS_MAX_METADATADUP_PERCENT"
}

check_btrfs_system_DUP () 
{
	local PERCENT
	
	eval `get_btrfs_data "$1" 'System'`

	[ -n "$DEBUG" ] && echo "System TOTAL: $TOTAL"
	[ -n "$DEBUG" ] && echo "System USED: $USED"

	PERCENT=`echo "100 * $USED / $TOTAL" | bc`
	[ -n "$DEBUG" ] && PERCENT=100

	[ -n "$DEBUG" ] && echo "System PERCENT: $PERCENT"
	[ -n "$DEBUG" ] && echo "System THRESH: $BTRFS_MAX_SYSTEMDUP_PERCENT"
	
	if [ $PERCENT -lt $BTRFS_MAX_SYSTEMDUP_PERCENT ]; then
		return 0
	fi

	[ -n "$DEBUG" ] && echo "System ALERTING"
  	alert "$FS" "System" "$PERCENT" "$BTRFS_MAX_SYSTEMDUP_PERCENT"
}

check_fs ()
{
	# skip if fs on exclusion list
	if echo "$1" | grep -q "$SKIP_LIST"; then
      		if [ $DEBUG ]; then echo "$1 on Skip list -ignoring"; fi
		return 0
	fi
	
	# df EXCCEPTIONS list looked after in check_df
	check_df "$1"

	# Only go further if btrfs
	FSTYPE=`cat /proc/mounts | grep -v 'rootfs' | awk -F ' ' '{ print $2 " " $3 };' | grep "^$1 " | awk -F ' ' '{ print $2 };'`
	if echo "$FSTYPE" | grep -qv 'btrfs'; then
		return 0
	fi
	check_btrfs_metadata_DUP "$1"
	check_btrfs_system_DUP "$1"
}


# script starts
# create list of filesystems, but exclude remote mounts and header
FS_LIST=`df | grep -v ":" | grep -v "Use%" |tr -s " " " " | cut -d " " -f6`
# check each filesystem against lists
for FS in `echo "$FS_LIST"`
do
  check_fs $FS
done

