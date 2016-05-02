#!/bin/sh
#/* @file image2sd.sh
#   @author Oscar Gómez Fuente <oscargomez@tedesys.com>
#   @ingroup TEDESYS GLOBAL S.L.
#   @date 2016-04-28
#   @version 1.0.0
#   @section DESCRIPTION
#    Script to compile buildroot and save sdcard.img to sd card or eMMC for different raspberry pi models
#
#*/

export LC_ALL=C

DRIVE="$1"
MODEL="$2"

if [ "$#" != "2" ]; then
	echo "[INFO] Usage: $0 path_drive raspberrypi_model"
	echo "\tRaspberry pi models:"
	echo "\t\t1a  -> tedpi-1a  : raspberry pi 1 A code: 0008"
	echo "\t\t1a+ -> tedpi-1a+ : raspberry pi 1 A+ v1.2 code: 0012"
	echo "\t\t1b  -> tedpi-1b  : raspberry pi 1 B v2.1 code: 000e"
	echo "\t\t1b+ -> tedpi-1b+ : raspberry pi 1 B+ v1.1 code: 0010"
	echo "\t\tcm  -> tedpi-cm  : raspberry pi cm v1.1 code: 0011"
	echo "\t\t2b  -> tedpi-2b  : raspberry pi 2 B v1.1 code: a01041"
	echo "\t\t3b  -> tedpi-3b  : raspberry pi 3 B v1.1 code: a02082"
	echo "\t-- special models --"
	echo "\t\t2b-x   -> tedpi-2b: raspberry pi 2 B v1.1 code: a01041"
	exit 1
fi

#/* Name of partitions */
NAME_P1="BOOT"
NAME_P2="rootfs"

#/* Path of bins */
PWD=$(pwd)
PATH_GIT="/home/${USER}/GIT/raspberrypi/buildroot"
if [ "$MODEL" = "1a" -o "$MODEL" = "1b" ]; then
	BUILDROOT_PATH="${PATH_GIT}/buildroot-2016.02-tedpi-1b"
elif [ "$MODEL" = "1a+" -o "$MODEL" = "1b+" ]; then
	BUILDROOT_PATH="${PATH_GIT}/buildroot-2016.02-tedpi-1b+"
elif [ "$MODEL" = "cm" ]; then
	BUILDROOT_PATH="${PATH_GIT}/buildroot-2016.02-tedpi-cm"
elif [ "$MODEL" = "2b" ]; then
	BUILDROOT_PATH="${PATH_GIT}/buildroot-2016.02-tedpi-2b"
elif [ "$MODEL" = "2b-x" ]; then
	BUILDROOT_PATH="${PATH_GIT}/buildroot-2016.02-tedpi-2b-x"
elif [ "$MODEL" = "3b" ]; then
	BUILDROOT_PATH="${PATH_GIT}/buildroot-2016.02-tedpi-3b"
	DTB_OVERLAY_PI3_DISABLE_BT_FILE="pi3-disable-bt-overlay.dtb"
else
	echo "[ERROR] Raspberry pi model unknown: $MODEL"
	exit 1
fi
DTB_OVERLAY_PATH="${BUILDROOT_PATH}/output/images/rpi-firmware/overlays"

echo "[INFO] Raspberry pi model: $MODEL"

#/* root fs */
SD_BOOT_PATH="/media/${USER}/${NAME_P1}"
SD_ROOTFS_PATH="/media/${USER}${NAME_P2}"
#BRCM_DRIVER_PATH="/home/${USER}/GIT/raspberrypi/wlan-firmware/firmware/brcm"
BRCM_DRIVER_PATH="/home/${USER}/GIT/raspberrypi/firmware-nonfree/brcm80211/brcm"
#/* wpa supplicant file configuration*/
WPA_SUPPLICAN_FILE=$SD_ROOTFS_PATH"/etc/wpa_supplicant/wpa_supplicant.conf"
#/* WIFI parameters */
SSID="SSID"
TAG="TAG"
PASSWORD="PASSWORD"

if [ "$DIRVE" = "/dev/sda" ]; then
	echo "[ERROR] DANGER!! You're trying to use the drive of your PC"
	exit 1
elif [ "$DIRVE" = "/" ]; then
	echo "[ERROR] DANGER!! You're trying to use /"
    exit 1
elif [ "$DRIVE" = "${DRIVE%"/dev/"*}" ]; then
	#/* /dev/ is NOT in $DRIVE */
    echo "[ERROR] DANGER!! You're trying to use a not /dev/* device"
    exit 1
fi

if [ ! -e $DRIVE ]; then
	echo "[ERROR] Drive: $DRIVE doesn't exist"
	exit 1
fi

echo "[INFO] DANGER!! You're trying to modify the data of your drive: $DRIVE"
echo "Do you want to continue? [Y/N]"
read ANSWER

if [ "$ANSWER" != "Y" -a "$ANSWER" != "y" ]; then
	echo "[INFO] Operation cancelled"
	exit 1
fi

echo "[INFO] You've just decided to use the drive: $DRIVE"
echo "[INFO] drive $DRIVE"

#/* compile buidroot */
if [ -d $BUILDROOT_PATH ]; then
	cd $BUILDROOT_PATH
	make
	if [ "$?" = "0" ]; then
		echo "[INFO] Compiled buildroot in: $BUILDROOT_PATH"
		cd $PWD
	else
		echo "[ERROR] Compiling buildroot in: $BUILDROOT_PATH"
		exit 1
	fi
else
	echo "[ERROR] Doesn't exist buildroot directory: $BUILDROOT_PATH"
	exit 1
fi

#/* dd sdcard.img command */
sudo sh -c "dd bs=1M if=${BUILDROOT_PATH}/output/images/sdcard.img | pv | dd of=${DRIVE}"
if [ "$?" = "0" ]; then
	echo "[INFO] dd command successfully"
else
	echo "[ERROR] dd command"
	exit 1
fi

if [ ! -f $DTB_OVERLAY_PATH/$DTB_OVERLAY_PI3_DISABLE_BT_FILE -a "$DTB_OVERLAY_PI3_DISABLE_BT_FILE" != "" ]; then
    echo "[ERROR] Missing file: $DTB_OVERLAY_PATH/$DTB_OVERLAY_PI3_DISABLE_BT_FILE"
    exit 1
else
    #/* copy DTB_OVERLAY files */
	if [ "$DTB_OVERLAY_PI3_DISABLE_BT_FILE" != "" ]; then
		sudo sh -c "mkdir -p $SD_BOOT_PATH/overlays"
        sudo sh -c "cp $DTB_OVERLAY_PATH/$DTB_OVERLAY_PI3_DISABLE_BT_FILE $SD_BOOT_PATH/overlays > /dev/null 2>&1"
        if [ "$?" = "0" ]; then
            echo "[INFO] $DTB_OVERLAY_PI3_DISABLE_BT_FILE file copied to $SD_BOOT_PATH/overlays successfully"
        else
            echo "[ERROR] Error copying .dtb overlay: $DTB_OVERLAY_PI3_DISABLE_BT_FILE to $SD_BOOT_PATH/overlays"
            exit 1
        fi
	fi

	if [ "$DTB_OVERLAY_PI3_DISABLE_BT_FILE" != "" ]; then
		sudo sh -c "mkdir -p $SD_ROOTFS_PATH/lib/firmware/brcm"
		sudo sh -c "cp $BRCM_DRIVER_PATH/brcmfmac43430-sdio.* $SD_ROOTFS_PATH/lib/firmware/brcm"
		if [ "$?" = "0" ]; then
			echo "[INFO] brcmfmac43430-sdio.* files copied to $SD_ROOTFS_PATH/lib/firmware/brcm successfully"
		else
			echo "[ERROR] Error copying /brcmfmac43430-sdio.* files file to $SD_ROOTFS_PATH/lib/firmware/brcm"
			exit 1
		fi
		if [ -f $WPA_SUPPLICAN_FILE ]; then
			sudo sh -c "sed -i 's/SSID/$SSID/g' $WPA_SUPPLICAN_FILE"
			sudo sh -c "sed -i 's/TAG/$TAG/g' $WPA_SUPPLICAN_FILE"
			sudo sh -c "sed -i 's/PASSWORD/$PASSWORD/g' $WPA_SUPPLICAN_FILE"
		else
			echo "[ERROR] Error modifying supplicant config file: $WPA_SUPPLICAN_FILE"
			exit 1
		fi
	fi
	
	#/* umount BOOT partition */
	sync
	sudo sh -c "umount -f ${DRIVE}1 > /dev/null 2>&1"
	if [ "$?" = "0" ]; then
		echo "[INFO] ${DRIVE}1 dismounted successfully"
	else
		echo "[ERROR] Error dismounting ${DRIVE}1"
		exit 1
	fi
	#/* umount rootfs partition */
	sudo sh -c "umount -f ${DRIVE}2 > /dev/null 2>&1"
	if [ "$?" = "0" ]; then
		echo "[INFO] ${DRIVE}2 dismounted successfully"
	else
		echo "[ERROR] Error dismounting ${DRIVE}2"
		exit 1
	fi
fi

echo "[INFO] Process successfully"
exit 0
