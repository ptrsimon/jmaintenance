#!/bin/bash
####################
### jmaintenance ###
####################
# main.bash - main source file
#
# Copyright (C) 2014 Peter Simon
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#


### BEGIN SCRIPT ###
SCRIPTPATH="/usr/sbin/jmaintenance/"
if cd $SCRIPTPATH 2> /dev/null;
then
    :
else
    printf "\e[7;31mFAIL\e[0m Failed to change working directory!\nMake sure you are root and the program resides in $SCRIPTPATH.\nAbort.\n"
    exit 71 # OSERR
fi

# Function to include files # USAGE: include FILE
function include
{
    local target="$1"
    if source "$target";
    then
	:
    else
	printf "ERROR! failed to include $target, abort!\n"
	exit 71 # OSERR
    fi
}

# Executable paths
include "exec_paths.bash"

# Configuration and option handling
include "config.bash"
while getopts "Ll:URWVhv" "option"
do
    case "$option" in
	"L")
	    LOGGING="false"
	    ;;
	"l")
	    LOGGING="true"
	    LOGFILE="$OPTARG"
	    ;;
	"U")
	    SKIP_USRCHK="true"
	    ;;
	"R")
	    SKIP_RLCHK="true"
	    ;;
	"W")
	    NOWARN="true"
	    ;;
	"V")
            VERBOSE="false"
	    exec 2>/dev/null
            ;;
	"h")
	    printf "Usage: maintenance [OPTIONS]\n"
            printf "Perform system maintenance and recovery in single-user mode.\n\n"
            printf "Options:\n"
            printf " -l <LOGFILE>\tspecify logfile location\n"
            printf " -L\t\tdisable logging\n"
            printf " -R\t\tskip runlevel check (USE WITH CAUTION!)\n"
            printf " -U\t\tskip user check\n"
            printf " -W\t\tdisable warning messages (USE WITH CAUTION!)\n"
            printf " -V\t\tdisble verbose output (silent)\n"
            printf " -h\t\tdisplay this help and exit\n"
            printf " -v\t\tdisplay version information and exit\n"
            exit $EX_OK
	    ;;
	"v")
	    printf "jmaintenance $VERSION\n"
            printf "Copyright (C) 2014 Péter Simon\n"
            printf "License GPLv2+: GNU GPL version 2 or later <http://gnu.org/licenses/gpl.html>.\n"
            printf "This is free software: you are free to change and redistribute it.\n"
            printf "There is NO WARRANTY, to the extent permitted by law.\n\n"
            printf "Written by Péter Simon.\n"
            exit $EX_OK
            ;;
	*)
            exit $EX_USAGE
            ;;
    esac
done

# Basic function definitions
include "basic_functions.bash"

# Create log file
if [ "$LOGGING" == "true" ]
then
    : >> "$LOGFILE"
    if [ $? -eq 0 ]
    then
	LOGGING="true"
	message "optional" "scroll" "OK" "Logfile created"
	date="$($DATE_PATH +"%Y %m/%d %H:%M")"
	log "\n$INFO jmaintenance started at $date"
    else
	LOGGING="false"
	message "critical" "warning" "WARN" "Failed to create logfile, no logging!"
    fi
else
    message "optional" "scroll" "INFO" "Not creating logfile"
fi

## System checks ##

# Pass 1 - check chmod
if [ -e "$CHMOD_PATH" ]
then
    log "$OK $CHMOD_PATH exists"
    message "optional" "scroll" "OK" "$CHMOD_PATH exists"
else
    log "$FAIL $CHMOD_PARH doesn't exist, abort!"
    message "critical" "halt" "FAIL" "$CHMOD_PATH doesn't exist, abort!"
    exit $EX_OSFILE
fi
if [ -x "$CHMOD_PATH" ]
then
    log "$OK $CHMOD_PATH is executable"
    message "optional" "scroll" "OK" "$CHMOD_PATH is executable"
else
    log "$WARN $CHMOD_PATH is not executable, attempting setfacl!"
    message "critical" "scroll" "WARN" "$CHMOD_PATH is not executable, attempting setfacl!"
    $SETFACL_PATH --set u::rwx,g::r-x,o::r-x "$CHMOD_PATH" 2>/dev/null
    SETFACL_EXIT=$?
    if [ $SETFACL_EXIT -eq 0 ]
    then
	log "$OK setfacl succeeded"
	message "critical" "scroll" "OK" "setfacl succeeded"
    else
	log "$WARN setfacl aborted with error code $SETFACL_EXIT, attempting to install acl"
        message "critical" "scroll" "WARN" "setfacl aborted, attempting to install package acl..."
	$APT_GET_PATH update > /dev/null
	$APT_GET_PATH install acl > /dev/null
	if [ $? -eq 0 ]
	then
	    log "$OK installed acl, rerunning setfacl"
	    message "optional" "scroll" "OK" "installed acl, rerunning setfacl"
	    $SETFACL_PATH --set u::rwx,g::r-x,o::r-x "$CHMOD_PATH" 2>/dev/null
	    SETFACL_EXIT=$?
	    if [ $SETFACL_EXIT -eq 0 ]
	    then
		log "$OK setfacl succeeded"
		message "critical" "scroll" "OK" "setfacl succeeded"
	    else
		log "$FAIL setfacl failed, abort!"
		message "critical" "halt" "FAIL" "setfacl failed, abort!"
		exit $EX_OSERR
	    fi
	else
	    log "$FAIL failed to install acl, abort!"
	    message "crtical" "halt" "FAIL" "Failed to install acl, abort!"
	    exit $EX_OSERR
	fi
    fi
fi
# Pass 2 - Check whoami and user
if [ "$SKIP_USRCHK" == "false" ]
then
    chk_exec "optional" "$WHOAMI_PATH"
    if [ $? -eq 0 ]
    then
	if [ "$($WHOAMI_PATH)" == "root" ]
	then
	    message "optional" "scroll" "OK" "Running as root"
	    log "$OK Running as root"
	else
	    message "critical" "scroll" "FAIL" "Not running as root, abort!"
	    log "$FAIL Not running as root, abort!"
	    exit $EX_NOPERM
	fi
    else
	log "$WARN User check skipped!"
	message "critical" "scroll" "WARN" "User check skipped!"
    fi
else
    log "$WARN User check skipped!"
    message "critical" "scroll" "WARN" "User check skipped!"
fi
# Pass 3 - Check runlevel
if [ "$SKIP_RLCHK" == "false" ]
then
    chk_exec "optional" "$RUNLEVEL_PATH"
    chk_exec "optional" "$AWK_PATH"
    if [ "$($RUNLEVEL_PATH | $AWK_PATH '{print $2}')" == "S" ]
    then
	log "$OK System is in single-user mode"
	message "optional" "scroll" "OK" "System is in single-user mode"
    else
	log "$FAIL System is not in single-user mode, abort!"
	message "critical" "halt" "FAIL" "System is not in single-user mode, abort!"
	exit $EX_OSERR
    fi
else
    log "$WARN Runlevel check skipped!"
    message "critical" "scroll" "WARN" "Runlevel check skipped!"
fi

# Repairing functions
include repair_functions.bash

# Start menu
include menu.bash