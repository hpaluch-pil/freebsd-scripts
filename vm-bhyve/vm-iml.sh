#!/bin/sh
# list VM images with ZFS archive size and sorted by NAME,CREATED
# It is like "advanced" version of "vm image list" command
# Requirements: installed and configured "vm-bhyve" package
# Copyright: many parts come from /usr/local/lib/vm-bhyve/vm-* scripts
set -euo pipefail

errx() {
	echo "ERROR: $@" >&2
	exit 1
}

# extract ZFS dataset for vm-bhyve "datastore" configuration
extract_zfs_ds() {
	local vm_dir vm_ds
	vm_dir="$(sysrc -n vm_dir)"
	[ -n "$vm_dir" ] || errx "No vm_dir variable defined in /etc/rc.conf"
	[ "${vm_dir%%:*}" = "zfs" ] || errx "vm_dir='$vm_dir' has no 'zfs:' prefix"
	vm_ds="${vm_dir#zfs:}"
	[ -n "$vm_ds" ] || errx "Unable to extract ZFS dataset name from vm_dir='$vm_dir'"
	echo "$vm_ds"
}

vm_ds=$( extract_zfs_ds )
vm_dir=$(mount | grep "^${vm_ds} " |cut -d' ' -f3)
[ -n "$vm_dir" ] || errx "Unable to find mount point for ZFS dataset '$vm_ds'"
[ "${vm_dir#/}" != "$vm_dir" ] || errx "Mount point '$vm_dir' does not start with '/'"
im_dir="$vm_dir/images"
[ -d "$im_dir" ] || errx "Unable to find Image dir '$im_dir' under '$vm_dir'"

_formath='%s^%s^%s^%s^%s\n'
_format='%s^%s^%s^%7d^%s\n'

# top level block to align '^' separated output to columns
{
	printf "${_formath}" "UUID" "NAME" "CREATED" "SIZE_MB" "DESCRIPTION"
	# nested block to properly sort output data by NAME,CREATED
	{
		ls -1 ${vm_dir}/images/ | \
		while read _file; do
		    if [ "${_file##*.}" = "manifest" ]; then
			_uuid=${_file%.*}
			# NOTE: sourcing with '.' is much faster than several calls of sysrc
			. "${vm_dir}/images/${_uuid}.manifest" 
			# convert date to ASCII sortable
			sortable_created=$( date -j -f '%+' '+%Y%m%d-%H%M%S' "${created}" )
			# get file size of compressed ZFS dataset
			zfs_size=$( stat -f "%z" "${vm_dir}/images/$_uuid.zfs.z" )
			zfs_size_mb=$(( $zfs_size / 1024 / 1024 ))
			printf "${_format}" "${_uuid}" "${name}" "${sortable_created}" "${zfs_size_mb}" "${description}"
		    fi
		done
	} | sort -t ^ -k 2,3
} | column -ts^

exit 0
