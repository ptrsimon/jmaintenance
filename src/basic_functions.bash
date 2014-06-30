#!/bin/bash
####################
### jmaintenance ###
####################
# basic_functions.bash - definition of critical functions
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

# Display on-screen messages (Usage: message PRIORITY TYPE PREFIX MESSAGE)
# PRIORITY: critical/optional
# TYPE: halt/scroll/warning
# PREFIX: OK/INFO/WARN/FAIL/NONE
function message
{
    local PRIORITY="$1"
    local TYPE="$2"
    local PREFIX="$3"
    local MESSAGE="$4"

    if [[ "$PRIORITY" == "optional" && "$VERBOSE" == "false" ]]
    then
	return
    fi

    function output_ncurses
    {
	! $WHIPTAIL_PATH --yes-button "Continue" --no-button "Abort" --yesno "$MESSAGE" 0 0 2> /dev/null && \
	    log "$INFO Aborted by user, exiting" && \
	    printf "\n$INFO Aborted by user, exiting\n" && \
	exit $EX_OK
    }

    function output_text
    {
	case "$PREFIX" in
	    "OK")
		MESSAGE="$OK $MESSAGE"
		;;
	    "INFO")
		MESSAGE="$INFO $MESSAGE"
		;;
	    "WARN")
                MESSAGE="$WARN $MESSAGE"
                ;;
	    "FAIL")
                MESSAGE="$FAIL $MESSAGE"
                ;;
	    "NONE")
		:
		;;
	esac
	if [ "$TYPE" == "halt" ]
	then
	    printf "\n"
	fi
	printf "$MESSAGE\n"
	case "$TYPE" in
	    "halt")
		printf "Press any key to continue."
		read -n1 -s
		printf "\n"
		;;
	    "warning")
		local kstroke
		printf "Press \"c\" to continue, any other key to abort."
		read -n1 -s kstroke
		printf "\n"
		if [ "$kstroke" == "c" ]
		then
		    log "$INFO warning ignored by user"
		else
		    log "$INFO aborted by user, exiting"
		    exit $EK_OK
		fi
		;;
	    *)
		:
		;;
	esac
    }
    
    if [[ "$FRONTEND" == "ncurses"  && "$TYPE" == "halt" ]]
    then
	output_ncurses
	if [[ $? -ne 0 && $? -ne 255 ]]
	then
	    output_text
	    return
	else
	    return
	fi
    else
	output_text
	return
    fi
}

# Write to log file (Usage: log LOGMESSAGE)
function log
{
    local MESSAGE="$1"
    if [ "$LOGGING" == "true" ]
    then
	printf "$MESSAGE\n" >> "$LOGFILE"
	return
    else
	return
    fi
}

# Check if an executable is usable (Usage: chk_crit PRIORITY TARGET)
# PRIORITY: optional/critical
function chk_exec
{
    PRIORITY="$1"
    TARGET="$2"
    # Pass 1 - checking existence
    if [ -e "$TARGET" ]
    then
	log "$OK $TARGET exists"
	message "optional" "scroll" "OK" "$TARGET exists"
    else
	if [ "$PRIORITY" == "critical" ]
	then
	    log "$FAIL $TARGET doesn't exist, abort!"
	    message "critical" "scroll" "FAIL" "$TARGET doesn't exist, abort!"
	    return 1
	else
	    log "$WARN $TARGET doesn't exist, some features are not available!"
	    message "critical" "warning" "WARN" "$TARGET doesn't exist, some features are not available!\nHINT: it's usually safe to continue, it won't affect maintenance process."
	    return 1
	fi
    fi
    # Pass 2 - checking exec permission
    if [ -x "$TARGET" ]
    then
	log "$OK $TARGET executable"
	message "optional" "scroll" "OK" "$TARGET executable"
    else # Attempt chmod
	log "$WARN $TARGET is not executable, attempting chmod..."
	message "critical" "scroll" "WARN" "$TARGET is not executable, attempting chmod..."
	if $CHMOD_PATH +x $TARGET;
	then
	    log "$OK chmod succeeded on $TARGET"
	    message "critical" "scroll" "OK" "chmod succeeded on $TARGET"
	else
	    if [ "$PRIORITY" == "critical" ]
	    then
		log "$FAIL chmod failed on $TARGET, abort!"
		message "critical" "scroll" "FAIL" "chmod failed on $TARGET, abort!"
		return 1
	    else
		log "$WARN chmod failed on $TARGET, some features are not available!"
		message "critical" "warning" "WARN" "chmod failed on $TARGET, some features are not available!\nHINT: it's usually safe to continue, it won't affect maintenance process."
	    fi
        fi
    fi
    return 0
}