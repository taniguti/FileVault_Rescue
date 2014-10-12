#!/bin/sh

WDIR=`pwd`
KC="${WDIR}/FileVaultMaster.keychain"
PASS="${WDIR}/pass.txt"
OS_VER=`sw_vers -productVersion`

if [ ! -f "$KC" ];   then echo "Not found $KC"   ; exit 1 ; fi
if [ ! -f "$PASS" ]; then echo "Not found $PASS" ; exit 1 ; fi

CSUUID=`diskutil cs list | grep Logical | tail -1 | awk '{print $4}'`
if [ ${CSUUID:-x} = x ];then
	echo "Humm, this Mac may not been FileVaulted."
	echo "Please check it."
	diskutil cs list
	exit 1
fi

KCPASS=`cat "$PASS" | tr -d '\n'`
security unlock-keychain -p "$KCPASS" "$KC"
if [ $? -ne 0 ]; then exit 1 ; fi

diskutil cs unlockVolume "$CSUUID" -recoveryKeychain "$KC"
if [ $? -ne 0 ]; then exit 1 ; fi

diskutil cs revert "$CSUUID" -recoveryKeychain "$KC"
if [ $? -ne 0 ]; then exit 1 ; fi


case $OS_VER in
10.10 | 10.10.* )
        okReboot=YES
        ;;
10.9 | 10.9.* | *)
        while true
        do
	              PROGRESS=`diskutil cs list | grep "Conversion Progress:" | awk '{print $3}'`
	              if [ ${PROGRESS:-X} = X ]; then
		                    echo "Something wong. Abort."
		                    diskutil cs list
		                    break
	              fi
	              echo "Conversion: $PROGRESS done."
	              if [ $PROGRESS = "100%" ]; then
		                    break
	              fi
	              sleep 10
        done

        diskutil cs revert "$CSUUID" -recoveryKeychain "$KC"
        if [ $? -ne 0 ]; then exit 1 ; fi

        MSG="`diskutil cs list`"
        echo "$MSG"
        if [ "$MSG" = "No CoreStorage logical volume groups found" ]; then
	              okReboot=YES
        else
	              diskutil cs list
        fi
        ;;
esac

if [ ${okReboot:-NO} = "YES" ]; then
	echo "OK. You can reboot now."
	echo "Do you want to reboot now? [y/n]"
	while true
	do
        	read ANS
        	R=`echo $ANS | tr [:upper:] [:lower:]`
	
        	case ${R:-n} in
        	y | yes )
			systemsetup -setstartupdisk "`systemsetup -liststartupdisks | tail -1`"
			sync
			sync
			sync
			/sbin/reboot
                	;;
        	n | no )
			CODE=0
                	break
                	;;
        	* )
                	echo "Do you want to reboot now? [y/n]"
                	;;
        	esac
	done
fi

exit ${CODE:-1}
