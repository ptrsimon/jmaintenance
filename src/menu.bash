#!/bin/bash
####################
### jmaintenance ###
####################
# menu.bash - main menu
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

function input
{
    printf "\n"
    message "critical" "scroll" "INFO" "Press RETURN to go back to menu"
    read -n1 -s
}

while true; do
    if [ "$FRONTEND" == "ncurses" ]
    then
	$WHIPTAIL_PATH --backtitle "jmaintenance $VERSION" --title "Main Menu" \
	    --cancel-button "Quit" \
	    --menu "Select an action (it is recommended to do them in order)" \
	    0 0 0\
	    "a" "Autopilot (do all tasks)" \
	    "1" "Fix filesystems" \
	    "2" "Fix broken packages" \
	    "3" "Fix system permissions" \
	    "4" "Reinstall all packages" \
	    "5" "Restore system configuration" \
	    "6" "Fix user permissions" \
	    "7" "Free up disk space" \
	    "q" "quit" \
	    2>/tmp/mmch
	choice="$($CAT_PATH /tmp/mmch)"
	printf "\n\n"
    else
	$CLEAR_PATH 2> /dev/null
	printf \
"###############################\n\
#### jmaintenance $VERSION ####\n\
###############################\n\
a Autopilot (do all tasks)\n\
1 Fix filesystems\n\
2 Fix broken packages\n\
3 Fix system permissions\n\
4 Reinstall all packages\n\
5 Restore system configuration\n\
6 Fix user permissions\n\
7 Free up disk space\n\
q quit\n\n\
Choice: "
	local choice
	read -n1 -s choice
	printf "\n"
    fi
    
    case "$choice" in
	"a")
	    fs_repair
	    brokenpkg_repair
	    fix_sysperm
	    sys_reinstall
	    reconfigure
	    fix_usperm
	    freeupdisk
	    ;;
	"1")
	    fs_repair
	    ;;
	"2")
	    brokenpkg_repair
	    ;;
	"3")
	    fix_sysperm
	    ;;
	"4")
	    sys_reinstall
	    ;;
	"5")
	    reconfigure
	    ;;
	"6")
	    fix_usperm
	    ;;
	"7")
	    freeupdisk
	    ;;
	"q")
	    $RM_PATH /tmp/mmch
	    exit $EX_OK
	    ;;
	"")
	    $RM_PATH /tmp/mmch
	    exit $EX_OK
	    ;;
    esac
    input
done