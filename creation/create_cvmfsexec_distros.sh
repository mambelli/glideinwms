#!/bin/bash

# SPDX-FileCopyrightText: 2009 Fermi Research Alliance, LLC
# SPDX-License-Identifier: Apache-2.0

# Hardcoded variables
CVMFSEXEC_REPO="https://www.github.com/cvmfs/cvmfsexec.git"
DEFAULT_WORK_DIR="/var/lib/gwms-factory/work-dir"

usage() {
	echo "$0 [--work-dir DIR] [PARAMETER_LIST PLATFORMS_LIST]"
	echo "This script is used to generate cvmfsexec distributions for all"
	echo "supported machine types (platform- and architecture-based)."
	echo "The script takes one parameter {osg|egi|default} which specifies"
	echo "the source to download the latest cvmfs configuration and repositories."
}

build_cvmfsexec_distros() {
    local cvmfsexec_tarballs cvmfsexec_temp cvmfsexec_latest cvmfsexec_distros cvmfs_src mach_type curr_ver=0
    local cvmfs_configurations cvmfs_configurations_list="$1"
    local supported_machine_types supported_machine_types_list="$2"
    local work_dir="$3"
    # Default work-dir (RPM install)
    [ -z "$work_dir" ] &&  work_dir="$DEFAULT_WORK_DIR" || true
	start=$(date +%s)

	# rhel6-x86_64 is not included; currently not supported due to EOL
	# egi for rhel8-x86_64 results in an error - egi does not yet have a centos8 build (as confirmed with Dave)
	# TODO: verify the logic when egi provides a centos8 build

	## factory_config_file="/etc/gwms-factory/glideinWMS.xml"
	#factory_config_file=$3
	## first, checking in the work-dir location for the current version of cvmfsexec
	#work_dir=$(grep -m 1 "submit" "$factory_config_file" | sed 's/.*base_dir="\([^"]*\)".*/\1/')
	# protect aginst non-existence of cvmfsexec directory; fresh install of GWMS with first run of factory upgrade
	if [[ -d "$work_dir/cvmfsexec" && -d "$work_dir/cvmfsexec/tarballs" ]]; then
		cvmfsexec_tarballs=$work_dir/cvmfsexec/tarballs
		if [[ -f "$cvmfsexec_tarballs/.cvmfsexec_version" ]]; then
			curr_ver=$(cat "$cvmfsexec_tarballs"/.cvmfsexec_version)
			echo "Current version found: $curr_ver"
		fi
	else
		# if the cvmfsexec directory does not exist, create one
		# also, create a directory named tarballs under cvmfsexec directory
		cvmfsexec_tarballs="$work_dir/cvmfsexec/tarballs"
		# check if tarballs directory exists; if not, create one; else proceed as usual
		if ! mkdir -p "$cvmfsexec_tarballs" || ! chmod 755 "$cvmfsexec_tarballs"; then
			# if the directory creation or permission change fail, print a message and exit from the script
			echo "Unable to create directory $cvmfsexec_tarballs" >&2
			exit 1
		fi
	fi

	# otherwise, .cvmfsexec_version file does not exist from a previous upgrade or it's a first-time factory upgrade
	cvmfsexec_temp="$work_dir/cvmfsexec/cvmfsexec.tmp"
	# check if the temp directory for cvmfsexec exists
	if mkdir -p "$cvmfsexec_temp"; then
		# cvmfsexec temp directory does not exist (create one) or exists (proceed to reuse)
		chmod 755 "$cvmfsexec_temp"
	fi

	cvmfsexec_latest="$cvmfsexec_temp"/latest
	git clone $CVMFSEXEC_REPO "$cvmfsexec_latest" &> /dev/null
    # cvmfsexec exits w/ 0, so the output should be checked as well
	if ! latest_ver=$("$cvmfsexec_latest"/cvmfsexec -v) || [[ -z "$latest_ver" ]]; then
	    echo "Failed to run the downloaded cvmfsexec" >&2
	    # line to allow testing when cvmfs is not supported
	    [[ -n "$CVMFSEXEC_FAILURES_OK" ]] && exit 0 || true
	    exit 1
    fi
	if [[ -z "$latest_ver" || "$curr_ver" == "$latest_ver" ]]; then
		# if current version and latest version are the same
		echo "Current version and latest version of cvmfsexec are identical!"
		# MM Why checking again the file? Could something delete it in the mean time? Should be checking for != 0 (value when file not found) ? 
		if [[ -f "$cvmfsexec_tarballs/.cvmfsexec_version" ]]; then
			echo "Using (existing) cvmfsexec version $(cat "$cvmfsexec_tarballs"/.cvmfsexec_version)"
		fi
		echo "Skipping the building of cvmfsexec distribution tarballs..."
		rm -rf "$cvmfsexec_latest"
		exit 0
	else
		# if current version and latest version are different
		if [[ -z "$curr_ver" || "$curr_ver" = 0 ]]; then
			# $curr_ver is empty, 0 is the new default; first time run of factory upgrade
			# no version info stored in work-dir/cvmfsexec/tarballs
			echo "Building cvmfsexec distribution(s)..."
		else
			# $curr_ver is not empty; subsequent run of factory upgrade (and not the first time)
			echo "Found newer version of cvmfsexec..."
			echo "Rebuilding cvmfsexec distribution(s) using the latest version..."
		fi

		# build the distributions for cvmfsexec based on the source, os and platform combination
		cvmfsexec_distros="$cvmfsexec_temp"/distros
		if [[ ! -d "$cvmfsexec_distros" ]]; then
			mkdir -p "$cvmfsexec_distros"
		fi

		cvmfs_configurations=($(echo $cvmfs_configurations_list | tr "," "\n"))
		supported_machine_types=($(echo $supported_machine_types_list | tr "," "\n"))

        local successful_builds=0
		for cvmfs_src in "${cvmfs_configurations[@]}"
		do
			for mach_type in "${supported_machine_types[@]}"
			do
				echo -n "Making $cvmfs_src distribution for $mach_type machine..."
				os=${mach_type%-*}  # $(echo $mach_type | awk -F'-' '{print $1}')
				arch=${mach_type#*-}  # $(echo $mach_type | awk -F'-' '{print $2}')
				if "$cvmfsexec_latest"/makedist -m $mach_type $cvmfs_src &> /dev/null ; then
					"$cvmfsexec_latest"/makedist -o "$cvmfsexec_distros"/cvmfsexec-${cvmfs_src}-${os}-${arch} &> /dev/null
					if [[ -e "$cvmfsexec_distros"/cvmfsexec-${cvmfs_src}-${os}-${arch} ]]; then
						echo " Success"
						if tar -cvzf "$cvmfsexec_tarballs"/cvmfsexec_${cvmfs_src}_${os}_${arch}.tar.gz -C "$cvmfsexec_distros" cvmfsexec-${cvmfs_src}-${os}-${arch} &> /dev/null; then
						    ((successful_builds+=1))
                        fi
					fi
				else
					echo " Failed! REASON: $cvmfs_src may not yet have a $mach_type build."
				fi

				# delete the dist directory within cvmfsexec to download the cvmfs configuration
				# and repositories for another machine type
				rm -rf "$cvmfsexec_latest"/dist
			done
		done

		# remove the distros and latest folder under cvmfsexec.tmp
		rm -rf "$cvmfsexec_distros"
		rm -rf "$cvmfsexec_latest"
	fi


	# TODO: store/update version information in the $cvmfsexec_tarballs location for future reconfig/upgrade
    if [[ "$successful_builds" -gt 0 ]]; then
        # update only if there was at least one successful build
	    echo "$latest_ver" > "$cvmfsexec_tarballs"/.cvmfsexec_version
    fi
    
	end=$(date +%s)

	runtime=$((end-start))
	echo "Took $runtime seconds to create $successful_builds cvmfsexec distributions"
}


####################### MAIN SCRIPT STARTS FROM HERE #######################

if [[ $1 == "--work-dir" ]]; then
    work_dir=$2
    shift 2
fi

## first, checking in the work-dir location for the current version of cvmfsexec
#work_dir=$(grep -m 1 "submit" "$factory_config_file" | sed 's/.*base_dir="\([^"]*\)".*/\1/')
# protect aginst non-existence of cvmfsexec directory; fresh install of GWMS with first run of factory upgrade

if [[ $# -eq 0 ]]; then
	echo "Building/Rebuilding of cvmfsexec distributions disabled!"
	exit 0
else
	configurations=$1
	machine_types=$2
fi

echo "Building/Rebuilding of cvmfsexec distributions enabled!"

build_cvmfsexec_distros "$configurations" "$machine_types" "$work_dir"
