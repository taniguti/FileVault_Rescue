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
  exit 0
fi

encryptionStatus=`diskutil cs list | grep "Encryption Status" | awk '{print $3}'`
encryptionType=`diskutil cs list| grep "Encryption Type" | awk '{print $3}'`
isRevertible=`diskutil cs list | grep Revertible | awk '{print $2}'`
RevertibleDescription="`diskutil cs list| grep "Revertible" | tr '(' ':' | tr ')' ':' | awk -F: '{print $3}'`"

if [ ${encryptionType:-unknown} = None ]; then
   if [ "$RevertibleDescription:-X" = "no decryption required" ]; then
      sw_vers
      echo "This Mac has a coreStorage logical volume."
      echo "But the coreStorage logical volume is not encrypted."
      echo "Please check it."
      diskutil cs list
      exit 0
   fi
fi

KCPASS=`cat "$PASS" | tr -d '\n'`
security unlock-keychain -p "$KCPASS" "$KC"
if [ $? -ne 0 ]; then exit 1 ; fi

if [ ${isRevertible:-No} = No ]; then
  diskutil cs list
  echo "\n############################################\n"
  echo " I could not revert encypted volume due to "
  echo " limitation of recovery system."
  echo " This Mac's (Recovery System) OS version is..."
  sw_vers
  echo "\nBut I maybe uable to unlock startup volume...\n"
  echo "\n############################################"
fi

convertStatus=`diskutil cs list| grep "Conversion Status" | awk  '{print $3}'`
if [ ${convertStatus:=Null} != Complete ]; then
  conversionDirection=`diskutil cs list| grep "Conversion Direction" | awk '{print $3}'`
  diskutil cs list
  echo "\n############################################\n"
  echo " File Vault conversion is now working."
  echo " You can not touch this volume until conversion"
  echo " finished.\n"
  echo " Conversion Status:      $convertStatus"
  echo " Conversion Direction:   ${conversionDirection:-unknown} "
  echo "\n############################################\n"
  exit 1
fi

if [ ${encryptionStatus:-Unlocked} = Locked ]; then
  diskutil cs unlockVolume "$CSUUID" -recoveryKeychain "$KC"
  if [ $? -ne 0 ]; then exit 1 ; fi
else
  FVdisk=`diskutil cs list | grep Disk | grep -v disk0s2 | awk '{print $2}'`
  echo "Volume ($FVdisk) is already unlocked."
fi

if [ ${isRevertible:-No} = No ]; then 
  echo "\n############################################\n"
  echo " Startup volume has been unlocked."
  echo " You can copy items from the startupdisk to "
  echo " your external volume."
  echo "\n FileVault is still enable."
  echo " Encryption Type: $encryptionType"
  echo "\n############################################\n"
  exit 0 
fi

diskutil cs revert "$CSUUID" -recoveryKeychain "$KC"
if [ $? -ne 0 ]; then exit 1 ; fi

case $OS_VER in
10.9 | 10.9.* )
        while true
        do
                PROGRESS=`diskutil cs list | grep "Conversion Progress:" | awk '{print $3}'`
                if [ ${PROGRESS:-X} = X ]; then
                        diskutil cs list
                        echo "\n############################################\n"
                        echo "Something wong. Abort."
                        echo "\n############################################\n"
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
                okReboot=NO
                diskutil cs list
        fi
        ;;
* )
        okReboot=YES
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
else
 echo "\n############################################\n"
 echo "  Something wrong. DO NOT REBOOT or SHUT DOWN."
 echo "\n############################################\n"
fi

exit ${CODE:-1}
