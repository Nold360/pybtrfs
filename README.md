# pybtrfs
Python BTRFS wrapper for df style output of METADATA SYSTEM, Block and data, including qgroup limit support. 

This code is all GPLv3 licensed. Standard disclaimers about its use apply. 

pybtrfs df output is formatted exactly the same as that from df - ie it is compatible with df scripts if you
just call the pybtrfs command instead.

Python 2.6+ and 3.3+ supported. 

The linux_fs_check_new.sh can be used from a cron job to give warnings about file systems getting full.  
Check that script out for a section to go in /etc/default so tha tyou can adjust thresholds for warnings.
This shell script only warns about BTRFS metadata (75% +) if more than 90% of blocks in btrfs FS are in use.  

Synopsis of Pybtrfs command line below. 

en-gedi: -grantma- [~/src/pybtrfs] 
$ sudo ./pybtrfs df --help
usage: pybtrfs df [--help] [-A] [-l] [-h [HUMAN_READABLE]] [-H [SI]]
                  [-m [MEGABYTES]] [-k [KILOBYTES]] [-T] [-B [BLOCK_SIZE]]
                  [-t [TYPE]]
                  [PATH [PATH ...]]

Df including BTRFS Metadata, Data, and System space

positional arguments:
  PATH                  Path for df

optional arguments:
  --help                show this help message and exit
  -A, --btrfs-all       All BTRFS metadata/system/data details
  -l, --local           Only do local file systems
  -h [HUMAN_READABLE], --human-readable [HUMAN_READABLE]
                        Human readable output GiB/MiB/KiB
  -H [SI], --si [SI]    Human readable output GB/MB/KB
  -m [MEGABYTES], --megabytes [MEGABYTES]
                        Output MiB
  -k [KILOBYTES], --kilobytes [KILOBYTES]
                        Output KiB
  -T, --print-type      Output file system type
  -B [BLOCK_SIZE], --block-size [BLOCK_SIZE]
                        Scales output by SIZE B/K/M/G/T
  -t [TYPE], --type [TYPE]
                        File system type

en-gedi: -grantma- [~/src/pybtrfs] 
$ en-gedi: -grantma- [~/src/pybtrfs] 
$ sudo ./pybtrfs df --help
usage: pybtrfs df [--help] [-A] [-l] [-h [HUMAN_READABLE]] [-H [SI]]
                  [-m [MEGABYTES]] [-k [KILOBYTES]] [-T] [-B [BLOCK_SIZE]]
                  [-t [TYPE]]
                  [PATH [PATH ...]]

Df including BTRFS Metadata, Data, and System space

positional arguments:
  PATH                  Path for df

optional arguments:
  --help                show this help message and exit
  -A, --btrfs-all       All BTRFS metadata/system/data details
  -l, --local           Only do local file systems
  -h [HUMAN_READABLE], --human-readable [HUMAN_READABLE]
                        Human readable output GiB/MiB/KiB
  -H [SI], --si [SI]    Human readable output GB/MB/KB
  -m [MEGABYTES], --megabytes [MEGABYTES]
                        Output MiB
  -k [KILOBYTES], --kilobytes [KILOBYTES]
                        Output KiB
  -T, --print-type      Output file system type
  -B [BLOCK_SIZE], --block-size [BLOCK_SIZE]
                        Scales output by SIZE B/K/M/G/T
  -t [TYPE], --type [TYPE]
                        File system type

en-gedi: -grantma- [~/src/pybtrfs] 
$ 
en-gedi: -grantma- [~/src/pybtrfs] 
$ sudo ./pybtrfs df --help
usage: pybtrfs df [--help] [-A] [-l] [-h [HUMAN_READABLE]] [-H [SI]]
                  [-m [MEGABYTES]] [-k [KILOBYTES]] [-T] [-B [BLOCK_SIZE]]
                  [-t [TYPE]]
                  [PATH [PATH ...]]

Df including BTRFS Metadata, Data, and System space

positional arguments:
  PATH                  Path for df

optional arguments:
  --help                show this help message and exit
  -A, --btrfs-all       All BTRFS metadata/system/data details
  -l, --local           Only do local file systems
  -h [HUMAN_READABLE], --human-readable [HUMAN_READABLE]
                        Human readable output GiB/MiB/KiB
  -H [SI], --si [SI]    Human readable output GB/MB/KB
  -m [MEGABYTES], --megabytes [MEGABYTES]
                        Output MiB
  -k [KILOBYTES], --kilobytes [KILOBYTES]
                        Output KiB
  -T, --print-type      Output file system type
  -B [BLOCK_SIZE], --block-size [BLOCK_SIZE]
                        Scales output by SIZE B/K/M/G/T
  -t [TYPE], --type [TYPE]
                        File system type

$ sudo ./pybtrfs qgroup display --help
usage: pybtrfs quota display [-h] [-u U] PATH

Displays quota groups from a BTRFS filesystem readably

positional arguments:
  PATH            BTRFS mount point

optional arguments:
  -h, --help      show this help message and exit
  -u U, --unit U  SI Unit, [B]ytes, K, M, G, T, P

Use sudo ./pybtrfs qgroup limit  to set subolume quotas.
