#!/bin/bash


function show_usage {
    printf '%s\n' "[Description]"
    printf '  %s\n' "Command line utility to spin up a linux container with a specific OP5 Monitor version"
    printf '  %s\n' "This utility assumes a valid LXD installation."
    printf '\n  %s\n' "This software is UNSUPPORTED and comes with strictly no warranty!"
    printf '  %s\n' "See the included license for more information."

    printf '\n%s\n' "[Usage]"
    printf '  %s\n' "$0 -v [MONITOR_VERSION]"

    printf '\n%s\n' "[Flags]"
    printf '  %s\t%s\n' "-b" "Base the container of this existing LXC image."
    printf '  %s\t%s\n' "-d" "Print debug messages"
    printf '  %s\t%s\n' "-e" "Create an ephemeral container"
    printf '  %s\t%s\n' "-h" "Shows this usage text"
    printf '  %s\t%s\n' "-n" "Specify a container name"
    printf '  %s\t%s\n' "-o" "Specify the EL major version to use (6 or 7, 8rocky, 8stream) - Also recommended when using -b"
    printf '  %s\t%s\n' "-v" "The monitor version to install [Required]"

}

# Runs a command and make sure we exit if it fails
safeRunCommand() {
    if [ -n "$debug" ]; then
	"$@"
    else
	"$@" > /dev/null
    fi


   if [ $? != 0 ]; then
      printf "Error when executing command: '$*'"
      exit $ERROR_CODE
   fi
}

function download_if_missing {
    _baseurl=$1
    _filename=$2

    if [ -n "$OP5LXD_TARBALL_PATH" ]; then
	download_dir=$OP5LXD_TARBALL_PATH
    else
	download_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
    fi

    if [ ! -d "$download_dir" ]; then
	echo "Download directory doesn't exist: $download_dir"
	return 1
    fi

    if [ ! -f $download_dir/$_filename ] || [[ "$_filename" == *"9beta"* ]]; then
	curl $_baseurl/$_filename -o $download_dir/$_filename -s
	return $?
    else
	echo "[>>>] install file already found, skipping downloading"
    fi
    return 0
}

function download_monitor {
    BASEURL_7='https://d2ubxhm80y3bwr.cloudfront.net/Downloads/op5_monitor_archive'
    BASEURL_8='https://d2ubxhm80y3bwr.cloudfront.net/Downloads/op5_monitor_archive/Monitor8/Tarball'
    BASEURL_9='https://op5-filebase.s3.eu-west-1.amazonaws.com/Downloads/op5_monitor_archive/Monitor9/Tarball/beta'
    # Known filenames
    declare -A filenames
    filenames["7.5.0"]="op5-monitor-7.5.0.x64.tar.gz"
    filenames["7.4.11"]="op5-monitor-7.4.11.x64.tar.gz"
    filenames["7.4.6"]="op5-monitor-7.4.6.x64.tar.gz"
    filenames["7.4.5"]="op5-monitor-7.4.5-20180806.tar.gz"
    filenames["7.4.3"]="op5-monitor-7.4.3-20180612.tar.gz"
    filenames["7.4.4"]="OP5-Monitor-7.4.4-20180711.tar.gz"
    filenames["7.4.2"]="op5-monitor-7.4.2-20180515.tar.gz"
    filenames["7.4.1"]="op5-monitor-7.4.1-20180420.tar.gz"
    filenames["7.4.0"]="op5-monitor-7.4.0-20180320.tar.gz"
    filenames["7.3.21"]="op5-monitor-7.3.21-20180226.tar.gz"
    filenames["7.3.20"]="op5-monitor-7.3.20-20180124.tar.gz"
    filenames["7.3.19"]="op5-monitor-7.3.19-20171212.tar.gz"
    filenames["7.3.2"]="op5-monitor-7.3.2-20161114.tar.gz"
    filenames["7.0.0"]="op5-monitor-7.0.0-20140903.tar.gz"
    filenames["9beta"]="op5-monitor-9beta-latest.tar.gz"

    echo "[>>>] Attempting to download OP5 Monitor $1"

    # the version has a known filename
    if [[ -v filenames["$1"] ]] ; then
	filename=${filenames["$1"]}
	if [[ $1 == 9* ]] ; then
	    download_if_missing $BASEURL_9 $filename
	    download_ok=$?
	elif [[ $1 == 8* ]] ; then
	    download_if_missing $BASEURL_8 $filename
	    download_ok=$?
	elif [[ $1 == 7* ]] ; then
	    download_if_missing $BASEURL_7 $filename
	    download_ok=$?
	fi
	if [ $download_ok -eq 0 ]; then
	    return 0
	fi
    fi

    # Try to guess the URL... Yay for consistent naming.
    if [[ $1 == 9* ]] ; then
	filename="op5-monitor-$1.tar.gz"
	download_if_missing $BASEURL_9 $filename
	download_ok=$?
    elif [[ $1 == 8* ]] ; then
	filename="op5-monitor-$1-x64.tar.gz"
	download_if_missing $BASEURL_8 $filename
	download_ok=$?
	if [ $download_ok -ne 0 ]; then
	    filename="op5-monitor-$1.x64.tar.gz"
	    download_if_missing $BASEURL_8 $filename
	    download_ok=$?
	fi
    elif [[ $1 == 7* ]] ; then
	filename="op5-monitor-$1.x64.tar.gz"
	download_if_missing $BASEURL_7 $filename
	download_ok=$?
    else
	download_ok=1
    fi
    if [ $download_ok -eq 0 ]; then
	return 0
    fi

    # TODO: Try some crazy HTML parsing of the actual download page

    return 1
}

ephemeral=""
container_name=""

# Parse arguments
while getopts "h?v:o:b:en:d" opt; do
    case "$opt" in
    h)
        show_usage
        exit 0
	;;
    \?)
        show_usage
        exit 1
	;;
    v)  pat="\b[7-8]\b\.\b[0-9]\b.\b[0-9][0-9]?\b"
	ver9beta="9beta"
	if [[ $OPTARG =~ $pat ]]; then
	    version=$OPTARG
	elif [[ $OPTARG == "$ver9beta" ]]; then
	    version=$OPTARG
	else
	    show_usage
	    echo "Invalid monitor version"
	    exit 1
	fi
        ;;
    o)  shopt -s nocasematch #ignore case
	if [[ "$OPTARG" == "6" || "$OPTARG" == "7" ||
	    "$OPTARG" == "8rocky" || "$OPTARG" == "8stream" ]]; then
	    el_version="${OPTARG}"
	else
	    show_usage
	    echo "Invalid OS version choice"
	    exit 1
	fi
	;;
    b)  base_image=$OPTARG
	;;
    e)  ephemeral="--ephemeral"
	;;
    n)  container_name=$OPTARG
	;;
    d)	debug=1
	;;
    esac
done

# we require a -v flag
if [ "x" == "x$version" ]; then
  echo "-v [monitor version] is required"
  show_usage
  exit 1
fi

if [[  -z ${el_version+x} && -z ${base_image+x} ]]; then
    echo "[>>>] No OS version or base image set. Assuming CentOS 7 (EL7)"
    el_version="7"
fi

# try to find the installation package
download_monitor $version
if [ $? -ne 0 ] ; then
    echo "[>>>] Failed to download OP5 Monitor $version"
    exit 1
fi

# launch an image
if [ -n "$base_image" ]; then
    lxc_output=$(lxc launch $base_image $container_name $ephemeral)
else
    image=""
    if [[ "$el_version" == "6" || "$el_version" == "7" ]]; then
        image="centos/$el_version"
    elif [[ "$el_version" == "8rocky" ]]; then
	image="rockylinux/8"
    elif [[ "$el_version" == "8stream" ]]; then
	image="centos/8-Stream"
    fi
    lxc_output=$(lxc launch images:$image $container_name $ephemeral)
fi

# catch errors
if [[ $lxc_output == *"Error:"* ]]; then
    echo $lxc_output
    exit 1
fi

# get the container name -- if not know
if [ -z "$container_name" ]; then
    container_name=${lxc_output##*:}
    array=( $container_name )
    container_name=${array[0]}
fi

echo "[>>>] Started container: $container_name"
echo "[>>>] Installing OP5 Monitor on the container"

# might take some time for network ie to come up
sleep 10

# actual installation steps
safeRunCommand lxc exec $container_name -- mkdir /root/op5_install/
safeRunCommand lxc file push $download_dir/$filename $container_name/root/op5_install/
# few additional EL7 things
if [[ $el_version == "7" || $el_version == "8"* ]] ; then
    safeRunCommand lxc exec $container_name -- /bin/bash -c "yum install -y firewalld"
    safeRunCommand lxc exec $container_name -- /bin/bash -c "systemctl enable firewalld"
    safeRunCommand lxc exec $container_name -- /bin/bash -c "systemctl start firewalld"
fi
if [[ $el_version == "8"* ]] ; then
    safeRunCommand lxc exec $container_name -- /bin/bash -c "dnf install -y selinux-policy dnf-plugins-core"
fi
safeRunCommand lxc exec $container_name -- /bin/bash -c "yum install -y tar which"
safeRunCommand lxc exec $container_name -- /bin/bash -c "tar -xf /root/op5_install/$filename -C /root/op5_install/"
safeRunCommand lxc exec $container_name -- /bin/bash -c "rm -f /root/op5_install/$filename"
safeRunCommand lxc exec $container_name -- /bin/bash -c "cd /root/op5_install/*onitor* && ./install.sh --noninteractive"

echo "[>>>] Installation finished on container: $container_name"

#cleanup install files on container
safeRunCommand lxc exec $container_name -- /bin/bash -c "rm -rf /root/op5_install"

#ensure we set the hostname correctly
safeRunCommand lxc exec $container_name -- hostnamectl set-hostname $container_name

container_ip=( $(lxc list --format csv -c 4 $container_name) )
container_ip=${container_ip[0]}

echo "[>>>] You should now be able to access OP5 Monitor $version on: https://$container_ip/monitor"
echo "[>>>] Enjoy!"
