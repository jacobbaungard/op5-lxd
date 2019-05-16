# op5-lxd

## Unsupported software

While this LXD setup makes use of OP5 Monitor, any code in this repository is **strictly unsupported** and comes completely without any type of warranty. For more information, please see [LICENSE](https://github.com/jacobbaungard/op5-lxd/blob/master/LICENSE).

## Requirements

This script assumes a working LXD installation.

## Why

### What is LXD?

LXD is a next generation system container manager.
It offers a user experience similar to virtual machines but using Linux containers instead.

Read more: https://linuxcontainers.org/lxd/

### Some use cases

* You want a clean install of a certain version of OP5 Monitor on a Centos 6/7 (or both) system/s quickly to test something out.

## Usage

    [Usage]
      ./op5_lxd.sh -v [MONITOR_VERSION]

    [Flags]
      -b	Base the container of this existing LXC image.
      -e	Create an ephemeral container
      -h	Shows this usage text
      -n	Specify a container name
      -o	Specify the CentOS major version to use (6 or 7) - Also recommended when using -b
      -v	The monitor version to install [Required]
