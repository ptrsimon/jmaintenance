#!/bin/bash
####################
### jmaintenance ###
####################
# repair_functions.bash - definition of the fixing functions
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


# Repair filesystems with fsck
function fs_repair
{
    log "$INFO fs_repair called"
    
    # Check executables
    local target
    for target in "$FSCK_PATH" "$CAT_PATH" "$GREP_PATH" "$AWK_PATH" "$MOUNT_PATH"; do
	! chk_exec "critical" "$target"  && return 1
    done

    # Function to check fsck exit code
    function chk_exit
    {
	case $FSCK_EXIT in
	    0)
		message "critical" "scroll" "OK" "Filesystem $device has no errors"
		;;
	    1)
		message "critical" "scroll" "OK" "Errors on filesystem $device corrected"
		;;
	    4)
		message "critical" "warning" "FAIL" "Unable to correct filesystem errors on $device!"
		;;
	    3|6)
                case $FSCK_EXIT in
		    3)
			message "critical" "halt" "OK" "Errors on filesystem $device corrected, rebooting system!\nAfter reboot, rerun jmaintenance if you haven't completed all tasks\n(this should be the case if you've chosen autopilot)."
			;;
		    6)
			message "critical" "halt" "FAIL" "Failed to correct errors on filesystem $device, rebooting system!\nAfter reboot, rerun jmaintenance if you haven't completed all tasks\n(this should be the case if you've chosen autopilot).\nIf this step fails on the next run as well, you may have a hardware error."
			;;
		esac
		$MOUNT_PATH -o remount,rw "$device"
		if [ $? -eq 0 ]
		then
		    message "optional" "scroll" "OK" "Filesystem $device remounted read-write"
		    log "$OK fsck on $device finished with exit code $FSCK_EXIT, rebooting system..."
		else
		    message "critical" "scroll" "FAIL" "Failed to remount $device read-write!"
		fi
		message "optional" "scroll" "INFO" "Rebooting system..."
		chk_exec "critical" "$SHUTDOWN_PATH"
		if [ $? -eq 0 ]
		then
		    $SHUTDOWN_PATH -r now
		else
		    message "critical" "halt" "WARN" "$SHUTDOWN_PATH not found, please manually reboot the system!"
		    exit $EX_OSERR
		fi
		;;
        esac
    }

    if [ -e /etc/fstab ]
    then
	log "$OK fstab found, remounting filesystems readonly"
	log "$INFO disabling logging temporarily"
	local device
	for device in $($CAT_PATH /etc/fstab | $GREP_PATH "/" | $GREP_PATH --invert-match "#" | $GREP_PATH --invert-match "/media" | $AWK_PATH '{print $2}'); do
	    $MOUNT_PATH -o remount,ro "$device"
	    if [ $? -eq 0 ]
	    then
		message "optional" "scroll" "OK" "Remounted $device readonly"
		$FSCK_PATH -y -f -T -C "$device"
		local FSCK_EXIT=$?
		chk_exit
		$MOUNT_PATH -o remount,rw "$device"
                if [ $? -eq 0 ]
                then
                    message "optional" "scroll" "OK" "Filesystem $device remounted read-write"
		    log "$OK fsck on $device finsihed with exit code $FSCK_EXIT, remounted filesystem"
		else
		    message "critical" "warning" "FAIL" "Failed to remount $device read-write!"
		fi
	    else
		message "critical" "scroll" "FAIL" "Failed to remount $device, not repairing it!"
	    fi
	done
	return 0
    else
	log "$FAIL fstab not found, abort!"
	message "critical" "halt" "FAIL" "fstab not found, abort!"
	return 1
    fi
}

# Repair broken pacakges with dpkg
function brokenpkg_repair
{
    log "$INFO brokenpkg_repair called"

    # check dpkg
    ! chk_exec "critical" "$DPKG_PATH" && return 1
    
    # Pass 1 - dpkg
    $DPKG_PATH --configure -a
    local DPKG_EXIT=$?
    if [ $DPKG_EXIT -eq 0 ]
    then
	log "$OK dpkg --configure -a finished"
	message "critical" "scroll" "OK" "dpkg configuration finished"
    else
	log "$FAIL dpkg --configure -a failed with exit code $DPKG_EXIT"
	message "critical" "scroll" "FAIL" "dpkg failed!"
    fi
    
    # check apt-get
    ! chk_exec "critical" "$APT_GET_PATH" && return 1

    # Pass 2 - apt-get
    $APT_GET_PATH -f install
    local APT_EXIT=$?
    if [ $DPKG_EXIT -eq 0 ]
    then
        log "$OK apt-get -f install finished"
        message "critical" "scroll" "OK" "apt fix finished"
    else
        log "$FAIL apt-get -f install failed with exit code $DPKG_EXIT"
        message "critical" "scroll" "FAIL" "apt fix failed!"
    fi
}

# Restore system directory permissions
function fix_sysperm
{
    log "$INFO fix_sysperm called"
    ! chk_exec "critical" "$CHMOD_PATH" && return 1

    local target
    for target in "/bin" "/sbin" "/usr" "/usr/bin" "/usr/bin" "/boot" "/dev" "/etc" "/home" "/lib" "/media" "/mnt" "/opt" "/run" "/srv" "/sys" "/var"
    do
       	if $CHMOD_PATH 755 "$target";
	then
	    log "$OK restored $target permissions"
	    message "critical" "scroll" "OK" "Restored $target permissions"
	else
	    log "$FAIL failed to restore /bin permissions!"
	    message "critical" "warning" "FAIL" "Failed to restore $target permissions!"
	fi
    done
}

# Reinstall all packages
function sys_reinstall
{
    log "$INFO sys_reinstall called"

    # Bring up networking
    if /etc/init.d/networking start;
    then
	log "$OK Networking started"
	message "optional" "scroll" "OK" "Networking started"
    else
	log "$FAIL Failed to start networking, abort!"
	message "critical" "scroll" "FAIL" "Failed to start networking, abort!"
	return
    fi
    for iface in "$($CAT_PATH /etc/network/interfaces | $GREP_PATH iface | $AWK_PATH '{print $2}')"
    do
	if $IFUP_PATH "$iface";
	then
	    log "$OK Brought up interface $iface, abort!"
	    message "optional" "scroll" "OK" "Brought up interface $iface"
	else
	    log "$FAIL Failed to bring up interface $iface, abort!"
	    message "critical" "scroll" "FAIL" "Failed tobring up interface $iface, abort!"
	fi
    done
    
    log "$INFO Testing network connection..."
    message "optional" "scroll" "INFO" "Testing network connection..."
    if $PING_PATH -c 1 debian.org > /dev/null;
    then
	log "$OK Networking is working"
	message "optional" "scroll" "OK" "Networking is working"
    else
	log "$FAIL Networking is not working!"
	message "critical" "warning" "FAIL" "Networking is not working, unable to reinstall system!"
    fi
    ! chk_exec "critical" "$AWK_PATH" && return 1
    ! chk_exec "critical" "$DPKG_PATH" && return 1
    ! chk_exec "critical" "$XARGS_PATH" && return 1
    ! chk_exec "critical" "$APTITUDE_PATH" && return 1
    
    message "critical" "halt" "INFO" "Now we are going to reinstall all of the packages in order to restore the default permissions. It might take some hours if you have large packages like GNOME or KDE installed.";
    
    $DPKG_PATH --get-selections \* | $AWK_PATH '{print $1}' | $XARGS_PATH -l1 $APTITUDE_PATH reinstall
    local APTITUDE_EXIT=$?
    if [ $APTITUDE_EXIT -eq 0 ]
    then
	log "$OK Reinstallation succeeded"
	message "optional" "scroll" "OK" "Reinstallation succeeded"
    else
	log "$FAIL Reinstallation failed!"
	message "critical" "warning" "FAIL" "Reinstallation failed!"
    fi
}

# Reconfigure all packages with
function reconfigure
{
    log "$INFO reconfigure called"

    # check dpkg-reconfigure
    ! chk_exec "critical" "$DPKG_RECONFIGURE_PATH" && return 1
    
    message "critical" "halt" "INFO" "Now we are going to reconfigure all of your installed packages. Some questions may be asked during this. If you don't know what to answer, the default choice is usually a good one."
    $DPKG_RECONFIGURE_PATH -pcritical --all --force
    local DPKG_RECONFIGURE_EXIT=$?
    printf "\n"
    if [ $DPKG_RECONFIGURE_EXIT -eq 0 ]
    then
	log "$OK dpkg-reconfigure -pcritical --all -force finished"
	message "critical" "scroll" "OK" "reconfiguration finished"
    else
	log "$FAIL dpkg-reconfigure -pcritical --all -force failed with error code $DPKG_RECONFIGURE_EXIT"
	message "critical" "scroll" "FAIL" "reconfiguration failed!"
    fi
}

# Restore user permissions
function fix_usperm
{
    log "$INFO fix_usperm called"

    ! chk_exec "critical" "$FIND_PATH" && return 1
    ! chk_exec "critical" "$CHMOD_PATH" && return 1
    ! chk_exec "critical" "$CHOWN_PATH" && return 1
    ! chk_exec "critical" "$XARGS_PATH" && return 1
    ! chk_exec "critical" "$GREP_PATH" && return 1
    ! chk_exec "critical" "$AWK_PATH" && return 1

    message "critical" "halt" "INFO" "Now we're going to restore the permissions of your personal files\n(the ones under /home)."

    # Pass 1 - file modes
    if $FIND_PATH /home/ -type f -print0 | $XARGS_PATH -0 $CHMOD_PATH 0644;
    then
	log "$OK restored permissions of files under /home"
	message "critical" "scroll" "OK" "Restored permissions of files under /home"
    else
	log "$FAIL failed to restore permissions of files under /home"
	message "critical" "scroll" "FAIL" "Failed to restore permissions of files under /home!"
    fi

    # Pass 2 - directory modes 
    if $FIND_PATH /home/ -type d -print0 | $XARGS_PATH -0 $CHMOD_PATH 0755;
    then
        log "$OK restored permissions of directories under /home"
	message "critical" "scroll" "OK" "Restored permissions of directories under /home"
    else
        log "$FAIL failed to restore permissions of directories under /home"
	message "critical" "scroll" "FAIL" "Failed to restore permissions of directories under /home!"
    fi

    # Pass 3 - ownerships
    local target
    for target in $($CAT_PATH /etc/passwd | $GREP_PATH /home/ | $AWK_PATH -F : '{print $1}')
    do
	if $CHOWN_PATH -R "$target":"$target" /home/"$target"/;
	then
	    log "$OK Fixed ownerships of user $target"
	    message "critical" "scroll" "OK" "Fixed ownerships of user $target"
	else
	    log "$FAIL Failed to fix ownerships of user $target!"
	    message "critical" "scroll" "FAIL" "Failed to fix ownerships of user $target!"
	fi
    done    
}

# Free up disk space
function freeupdisk
{
    log "$INFO freeupdisk called"

    ! chk_exec "critical" "$APT_GET_PATH" && return 1
    ! chk_exec "critical" "$RM_PATH" && return 1

    # Pass 1 - clear APT cache
    if $APT_GET_PATH clean;
    then
	log "$OK Cleaned APT cache"
	message "critical" "scroll" "OK" "Cleaned APT cache"
    else
	log "$FAIL Failed to clean APT cache!"
	message "critical" "scroll" "FAIL" "Failed to clean APT cache!"
    fi

    # Pass 2 - KDE, desktop, thumbnails cache
    local target
    for target in "/home/*/.kde/cache-*" "/home/*/.cache" "/home/*/.thumbs" "/home/*/.thumbnails"
    do
	if [ -d $target ]
	then
	    if $RM_PATH -rf $target;
	    then
		log "$OK Cleared $target"
		message "critical" "scroll" "OK" "Cleared $target"
	    else
		log "$FAIL Failed to clear $target!"
		message "critical" "scroll" "FAIL" "Failed to clear $target!"
	    fi
	fi
    done
}