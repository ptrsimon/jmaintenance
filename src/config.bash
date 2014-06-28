#!/bin/bash
####################
### jmaintenance ###
####################
# config.bash - configuration
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

## Pass 1 - default options (readonly variables cannot be overridden by CLI of config file options) ##

# Version info
readonly VERSION="0.5-beta"

# $PATH
readonly PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Configuration file location
readonly CONFIGFILE="/etc/jmaintenance.conf"

# Log file location
LOGFILE="/var/log/jmaintenance"

# Logging
LOGGING="true"

# Frontend
if [ -x "$WHIPTAIL_PATH" ]
then
    FRONTEND="ncurses"
else
    $CHMOD_PATH 755 $WHIPTAIL_PATH 2> /dev/null
    if [ $? -eq 0 ]
    then
	FRONTEND="ncurses"
    else
	FRONTEND="text"
    fi
fi
readonly FRONTEND

# Verbosity
VERBOSE="true"

# Display warning messages
NOWARN="false"

# Skip user and runlevel checks?
SKIP_USRCHK="false"
SKIP_RLCHK="false"

# Exit codes (from /usr/include/sysexits.h)
EX_OK=0
EX_USAGE=64
EX_OSERR=71
EX_OSFILE=72
EX_NOPERM=77

# Sample messages
readonly OK="\e[7;32m OK \e[0m"
readonly INFO="\e[7;36mINFO\e[0m"
readonly WARN="\e[7;33mWARN\e[0m"
readonly FAIL="\e[7;31mFAIL\e[0m"

## Pass 2 - include options from config file ##

if [ -f "$CONFIGFILE" ]
then
    source "$CONFIGFILE"
fi

## Pass 3 - option handling happens in main source file ##