#!/bin/bash

WDIR=`pwd`
KEYCHAIN_FILE="${WDIR}/FileVaultMaster.keychain"
PASS_FILE="${WDIR}/pass.txt"
INFODIR="${WDIR}/diskutil_outputs"
if [ -d "$INFODIR" ]; then
    LOGDIR="${INFODIR}/`sw_vers -productVersion`"
    mkdir -p "${LOGDIR}"
    sw_vers | awk -v T="`date +%F" "%T" "%Z`" '{print T":"$0}' >> "${LOGDIR}/sw_vers.txt"
    gatherlog=YES
fi

message(){
    TYPE=$1
    shift
    echo "`date +%F" "%T" "%Z` [$TYPE] $@" >&2
}

unlock_KeyChain(){
    KC="$1"
    PASS="$2"

    if [ ! -f "$KC" ];   then message ERROR "Not found $KC"   ; exit 1 ; fi
    if [ ! -f "$PASS" ]; then message ERROR "Not found $PASS" ; exit 1 ; fi
    KCPASS=`head -1 "$PASS" | tr -d '\n\r'`
    security unlock-keychain -p "$KCPASS" "$KC"

    if [ $? -eq 0 ]; then
	message INFO $KC unlocked.
    else
        message ERROR Failed to unlock ${KC}.
        exit 1
    fi
}

isEncryptCS(){
    encryptionType=`diskutil cs list | grep "Encryption Type" | awk '{print $3}'`
    if [ ${encryptionType:-unknown} = None ]; then
      message INFO This Mac has a coreStorage logical volume.
      message INFO But the coreStorage logical volume is not encrypted.
      message INFO Please check it.
      diskutil cs list
      exit 0
    fi

    convertStatus=`diskutil cs list    | grep "Conversion Status" | awk '{print $3}'`
    if [ ${convertStatus:=Null} != Complete ]; then
        conversionDirection=`diskutil cs list| grep "Conversion Direction" | awk '{print $3}'`
        diskutil cs list
        message INFO File Vault conversion is now working.
        message INFO You DO NOT touch this volume until conversion finished.
        message INFO Conversion Status: $convertStatus
        message INFO Conversion Direction: ${conversionDirection:-unknown}
        exit 1
    fi
}

isEncryptAPFS(){
    encryptionStatus=`diskutil ap list | awk '$2 == "Encrypted:" {print $3}' | grep -c "Yes"`

    if [ ${encryptionStatus:-0} -ne 1 ]; then
        message INFO This Mac has an AppleFileSystem volume.
        message INFO But the AppleFileSystem volume is not encrypted.
        message INFO Or multipule encrypted volumes.
        message INFO Please check it.
        diskutil ap list
        exit 0
    fi

    return `diskutil ap list | awk '$NF == "role)" {print $6}'`
}

unlockCS(){
    FILE="$1"
    CSUUID=`diskutil cs list | grep Logical | tail -1 | awk '{print $NF}'`

    encryptionStatus=`diskutil cs list | grep "Encryption Status" | awk '{print $3}'`
    if [ ${encryptionStatus:-Unlocked} = Locked ]; then
        diskutil cs unlockVolume "$CSUUID" -recoveryKeychain "$FILE"
        if [ $? -eq 0 ]; then
            message INFO OK I unlock it.
        else
            diskuti cs list
            message ERROR Failed to unlock volume with ${FILE}.
            exit 1
        fi
    else
        FVdisk=`diskutil cs list | grep Disk | grep -v disk0s2 | awk '{print $2}'`
        message INFO Volume \(${FVdisk}\) is already unlocked.
    fi

    isRevertible=`diskutil cs list | awk '$1 == "Revertible:" {print $2}'`
    if [ ${isRevertible:-No} = Yes ]; then
        message INFO This storage can be revertible.
    else
        diskutil cs list
        message ERROR I could not revert encypted volume due to limitation of recovery system.
        message ERROR But you can copy itmes from unlocked volume to another storage.
        exit 1
    fi
    if [ ${gatherlog:-NO} = YES ]; then
	    diskutil cs list > ${LOGDIR}/filevault_unlocked_`date +%F"-"%T"-"%Z`.txt
    fi
}


watchConversion(){
	sleep 10
    if [ ${gatherlog:-NO} = YES ]; then
	    diskutil cs list > ${LOGDIR}/filevault_convertion_inprogress_`date +%F"-"%T"-"%Z`.txt
    fi
    while true
    do
        PROGRESS=`diskutil cs list | grep "Conversion Progress:" | awk '{print $3}'`
        if [ ${PROGRESS:-X} = X ]; then
            diskutil cs list
            message ERROR Something wong. Abort.
            exit 1
        fi
        echo "Conversion: $PROGRESS done."
        if [ $PROGRESS = "100%" ]; then
            if [ ${gatherlog:-NO} = YES ]; then
	            diskutil cs list > ${LOGDIR}/filevault_convertion_done_`date +%F"-"%T"-"%Z`.txt
            fi
            sleep 10
            break
        fi
    done
}

askreboot(){
    message INFO OK. You can reboot now.
    message INFO Do you want to reboot now? [y/n]
    while true
    do
        read ANS
        R=`echo $ANS | tr [:upper:] [:lower:]`

        case ${R:-n} in
        y | yes )
            macOSversion=`sw_vers -productVersion| awk -F. '{print $2}'`
            if [ $macOSversion -lt 12 ]; then
                /usr/sbin/systemsetup -setstartupdisk \
                    "`/usr/sbin/systemsetup -liststartupdisks | tail -1`"
            fi
            sync; sync; sync; /sbin/reboot
            ;;
        n | no )
            exit 0
            ;;
        * )
            message INFO Do you want to reboot now? [y/n]
            ;;
        esac
    done
}

decryptCS(){
    FILE="$1"
    CSUUID=`diskutil cs list | grep Logical | tail -1 | awk '{print $NF}'`
    macOSversion=`sw_vers -productVersion| awk -F. '{print $2}'`

    RevertibleDescription="`diskutil cs list | awk '$1 == "Revertible:" {print $0}'| tr '()' ':' | awk -F: '{print $(NF -1)}'`"
    # "unlock and decryption required"
    #
    diskutil cs revert "$CSUUID" -recoveryKeychain "$FILE"
    if [ $? -eq 0 ]; then
        message INFO Start to revert.
    else
        diskutil cs list
        message ERROR Failed to revert storage.
        exit 1
    fi

    if [ ${gatherlog:-NO} = YES ]; then
        diskutil cs list > ${LOGDIR}/filevault_reverted_1st_`date +%F"-"%T"-"%Z`.txt
    fi

    case $macOSversion in
    9)
        watchConversion
        diskutil cs revert "$CSUUID" -recoveryKeychain "$FILE"
        if [ $? -eq 0 ]; then
            message INFO Complete reverted.
        else
            diskutil cs list
            message ERROR Failed to revert storage.
            exit 1
        fi
        if [ ${gatherlog:-NO} = YES ]; then
            diskutil cs list > ${LOGDIR}/filevault_reverted_2nd_`date +%F"-"%T"-"%Z`.txt
        fi
        askreboot
        ;;
    *)
        : `sw_vers -productVersion`
        askreboot
        ;;
    esac
}

unlockAPFS(){
   devfile=$1
   diskutil ap unlockvolume $devfile
}

decryptAPFS(){
   devfile=$1
   diskutil ap decryptVolume $devfile
}

################################
# M A I N
################################

# Check Kind of FileSystem
diskutil cs list > /dev/null 2>&1
if [ $? -eq 0 ]; then
    if [ "`diskutil cs list | awk 'NR == 1 {print $1}'`" = "No" ]; then
        isCoreStorage=NO
    else
        isCoreStorage=YES
        message INFO Found CoreStorage.
    fi
else
    isCoreStorage=NO
fi
diskutil ap list > /dev/null 2>&1
if [ $? -eq 0 ]; then
    if [ "`diskutil ap list | awk 'NR == 1 {print $1}'`" = "No" ]; then
        isAppleFileSystem=NO
    else
        isAppleFileSystem=YES
        message INFO Found AppleFileSystem.
    fi
else
    isAppleFileSystem=NO
fi

if [ "${isCoreStorage}${isAppleFileSystem}" = "NONO" ];then
    message INFO Unexpected File System type.
    message INFO Maybe no need decript.
    diskutil list
    exit 1
fi

if [ "${isCoreStorage}${isAppleFileSystem}" = "YESYES" ];then
    message WARN There are both APFS and CoreStorage Volume.
    message WARN Unmount volumes which is not startup disk.
    exit 1
fi

# Unlock and decrypt
if [ $isCoreStorage = YES ]; then
    isEncryptCS
    unlock_KeyChain "$KEYCHAIN_FILE" "$PASS_FILE"
    unlockCS "$KEYCHAIN_FILE"
    decryptCS "$KEYCHAIN_FILE"
fi

if [ $isAppleFileSystem = YES ]; then
    message INFO This script would not work for File Vaulted APFS.
    message INFO File Vaulted APFS could not decrypt with Institutional Recovery Key.
#    target=`isEncryptAPFS`
#    unlock_KeyChain "$KEYCHAIN_FILE" "$PASS_FILE"
#    unlockAPFS $target
#    decryptAPFS $target
fi

exit 0

# for Emacsen
# Local Variables:
# mode: sh
# sh-dasic-offset: 4
# sh-indentation: 4
# tab-width: 4
# indent-tabs-mode: nil
# coding: utf-8
# End:

# vi: set ts=4 sw=4 sts=4 et ft=sh fenc=utf-8 ff=unix :
