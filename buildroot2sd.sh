#!/bin/sh
#/** @file buildroot2sd.sh
#    @author Oscar Gomez Fuente <oscargomezf@gmail.com>
#    @ingroup iElectronic
#    @version 1.3.0
#    @date 2016-07-27
#    @section DESCRIPTION
#      Script to compile buildroot and save boot and rootfs on sd card or eMMC for different raspberry pi models
#
# */

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
	echo "\t\t3b-flea3 -> tedpi-3b-flea3 : raspberry pi 3 B v1.1 code: a02082"
	echo "\t\t2b-x     -> tedpi-2b       : raspberry pi 2 B v1.1 code: a01041"
	exit 1
fi

#/* Name of partitions */
NAME_P1="BOOT"
NAME_P2="rootfs"

#/* Path of bins */
PWD=$(pwd)
PATH_GIT="/home/${USER}/GIT/raspberrypi/buildroot"
#PATH_GIT="/home/${USER}/GIT"
if [ "$MODEL" = "1a" -o "$MODEL" = "1b" ]; then
	BUILDROOT_PATH="${PATH_GIT}/buildroot-2016.02-tedpi-1b"
	DTB_FILE="bcm2708-rpi-b.dtb"
elif [ "$MODEL" = "1a+" -o "$MODEL" = "1b+" ]; then
	BUILDROOT_PATH="${PATH_GIT}/buildroot-2016.02-tedpi-1b"
	DTB_FILE="bcm2708-rpi-b-plus.dtb"
elif [ "$MODEL" = "cm" ]; then
	BUILDROOT_PATH="${PATH_GIT}/buildroot-2016.02-tedpi-cm"
	DTB_FILE="bcm2708-rpi-cm.dtb"
elif [ "$MODEL" = "2b" ]; then
	BUILDROOT_PATH="${PATH_GIT}/buildroot-2016.02-tedpi-2b"
	DTB_FILE="bcm2709-rpi-2-b.dtb"
elif [ "$MODEL" = "2b-x" ]; then
	BUILDROOT_PATH="${PATH_GIT}/buildroot-2016.02-tedpi-2b"
	DTB_FILE="bcm2709-rpi-2-b.dtb"
elif [ "$MODEL" = "3b" -o "$MODEL" = "3b-flea3" ]; then
	#BUILDROOT_PATH="${PATH_GIT}/buildroot-2016.02-tedpi-3b"
	BUILDROOT_PATH="${PATH_GIT}/buildroot-2016.02-samia"
	DTB_FILE="bcm2710-rpi-3-b.dtb"
	DTB_OVERLAY_PI3_DISABLE_BT_FILE="pi3-disable-bt-overlay.dtb"
	#DTB_OVERLAY_PI3_DISABLE_BT_FILE="pi3-disable-bt.dtbo"
	#DTB_OVERLAY_PI3_DISABLE_BT_FILE="pi3-miniuart-bt.dtb"
else
	echo "[ERROR] Raspberry pi model unknown: $MODEL"
	exit 1
fi

DTB_PATH="${BUILDROOT_PATH}/output/images"
DTB_OVERLAY_PATH="${BUILDROOT_PATH}/output/images/rpi-firmware/overlays"
DTB_TCA6424A_OVERLAY="tca6424a-overlay.dtb"
DTB_ADS7846_OVERLAY="ads7846-overlay.dtb"

echo "[INFO] Raspberry pi model: $MODEL"

#/* boot and firmware files */
BOOTCODE="${BUILDROOT_PATH}/output/images/rpi-firmware/bootcode.bin"
START="${BUILDROOT_PATH}/output/images/rpi-firmware/start.elf"
FIXUP="${BUILDROOT_PATH}/output/images/rpi-firmware/fixup.dat"
CONFIG="${BUILDROOT_PATH}/output/images/rpi-firmware/config.txt"
CMDLINE="${BUILDROOT_PATH}/output/images/rpi-firmware/cmdline.txt"
#/* kernel */
#KERNEL="${BUILDROOT_PATH}/output/images/zImage"
KERNEL="${BUILDROOT_PATH}/output/images/kernel-marked/zImage"
#/* root fs */
ROOTFS="${BUILDROOT_PATH}/output/images/rootfs.tar"
SD_PATH="/mnt/sd_media"
SD_BOOT_PATH="/media/${USER}/$NAME_P1"
SD_ROOTFS_PATH="/media/${USER}/$NAME_P2"
BR_TARGET_PATH="${BUILDROOT_PATH}/output/target"
#BRCM_DRIVER_PATH="/home/${USER}/GIT/raspberrypi/wlan-firmware/firmware/brcm"
BRCM_DRIVER_PATH="/home/${USER}/GIT/raspberrypi/firmware-nonfree/brcm80211/brcm"
#/* wpa supplicant file configuration*/
WPA_SUPPLICAN_FILE=$SD_ROOTFS_PATH"/etc/wpa_supplicant/wpa_supplicant.conf"
#/* WIFI parameters */
SSID="WLAN_XXX"
TAG="XXXXX"
PASSWORD="XXXXX"

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
elif [ "$SD_BOOT_PATH" = "" ]; then
	echo "[ERROR] DANGER!! SD_BOOT_PATH is emty"
	exit 1
elif [ "$SD_ROOTFS_PATH" = "" ]; then
	echo "[ERROR] DANGER!! SD_ROOTFS_PATH is emty"
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

if [ ! -f $BOOTCODE ]; then
	echo "[ERROR] Missing file: $BOOTCODE"
	exit 1
elif [ ! -f $START ]; then
	echo "[ERROR] Missing file: $START"
	exit 1
elif [ ! -f $FIXUP ]; then
	echo "[ERROR] Missing file: $FIXUP"
	exit 1
elif [ ! -f $CONFIG ]; then
	echo "[ERROR] Missing file: $CONFIG"
	exit 1
elif [ ! -f $CMDLINE ]; then
	echo "[ERROR] Missing file: $CMDLINE"
	exit 1
elif [ ! -f $DTB_PATH/$DTB_FILE ]; then
	echo "[ERROR] Missing file: $DTB_PATH/$DTB_FILE"
	exit 1
elif [ ! -f $DTB_OVERLAY_PATH/$DTB_OVERLAY_PI3_DISABLE_BT_FILE -a "$DTB_OVERLAY_PI3_DISABLE_BT_FILE" != "" ]; then
	echo "[ERROR] Missing file: $DTB_OVERLAY_PATH/$DTB_OVERLAY_PI3_DISABLE_BT_FILE"
	exit 1
elif [ ! -f $KERNEL ]; then
	echo "[ERROR] Missing file: $KERNEL"
	exit 1
elif [ ! -f $ROOTFS ]; then
	echo "[ERROR] Missing file: $ROOTFS"
	exit 1
elif [ ! -d $SD_BOOT_PATH ]; then
	echo "[ERROR] Missing file: $SD_BOOT_PATH"
	exit 1
elif [ ! -d $SD_ROOTFS_PATH ]; then
	echo "[ERROR] Missing file: $SD_ROOTFS_PATH"
	exit 1
elif [ "$MODEL" = "2b-x" -a ! -f ${DTB_OVERLAY_PATH}/${DTB_ADS7846_OVERLAY} ]; then
	echo "[ERROR] Missing ${DTB_ADS7846_OVERLAY} file"
	exit 1
elif [ "$MODEL" = "3b-flea3" -a ! -f ${DTB_OVERLAY_PATH}/${DTB_TCA6424A_OVERLAY} ]; then
	echo "[ERROR] Missing ${DTB_TCA6424A_OVERLAY} file"
	exit 1
else
	echo "[INFO] Raspberry pi model: $MODEL"

	#/* copy boot files to sd boot partition */
	sudo sh -c "rm -rf ${SD_BOOT_PATH}/* > /dev/null 2>&1"
	#/* bootcode.bin */
	sudo sh -c "cp $BOOTCODE $SD_BOOT_PATH > /dev/null 2>&1"
	if [ "$?" = "0" ]; then
		echo "[INFO] bootcode.bin file copied to $SD_BOOT_PATH successfully"
	else
		echo "[ERROR] Error copying bootcode.bin to $SD_BOOT_PATH"
		exit 1
	fi
	#/* start.elf */
	sudo sh -c "cp $START $SD_BOOT_PATH > /dev/null 2>&1"
	if [ "$?" = "0" ]; then
		echo "[INFO] start.elf file copied to $SD_BOOT_PATH successfully"
	else
		echo "[ERROR] Error copying start.elf to $SD_BOOT_PATH"
		exit 1
	fi
	#/* fixup.dat */
	sudo sh -c "cp $FIXUP $SD_BOOT_PATH > /dev/null 2>&1"
	if [ "$?" = "0" ]; then
		echo "[INFO] fixup.dat file copied to $SD_BOOT_PATH successfully"
	else
		echo "[ERROR] Error copying fixup.dat to $SD_BOOT_PATH"
		exit 1
	fi
	#/* config.txt */
	sudo sh -c "cp $CONFIG $SD_BOOT_PATH > /dev/null 2>&1"
	if [ "$?" = "0" ]; then
		echo "[INFO] config.txt file copied to $SD_BOOT_PATH successfully"
	else
		echo "[ERROR] Error copying config.txt to $SD_BOOT_PATH"
		exit 1
	fi
	#/* cmdline.txt */
	sudo sh -c "cp $CMDLINE $SD_BOOT_PATH > /dev/null 2>&1"
	if [ "$?" = "0" ]; then
		echo "[INFO] cmdline.txt file copied to $SD_BOOT_PATH successfully"
	else
		echo "[ERROR] Error copying cmdline.txt to $SD_BOOT_PATH"
		exit 1
	fi
	#/* copy DTB file */
	sudo sh -c "cp $DTB_PATH/$DTB_FILE $SD_BOOT_PATH> /dev/null 2>&1"
	if [ "$?" = "0" ]; then
		echo "[INFO] $DTB_FILE file copied to $SD_BOOT_PATH successfully"
	else
		echo "[ERROR] Error copying .dtb to $SD_BOOT_PATH"
		exit 1
	fi
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
	#/* copy DTB_ADS7846_OVERLAY */
	if [ "$MODEL" = "2b-x" ]; then
		sudo sh -c "mkdir -p $SD_BOOT_PATH/overlays"
		sudo sh -c "cp $DTB_OVERLAY_PATH/$DTB_ADS7846_OVERLAY $SD_BOOT_PATH/overlays > /dev/null 2>&1"
		if [ "$?" = "0" ]; then
			echo "[INFO] $DTB_ADS7846_OVERLAY file copied to $SD_BOOT_PATH/overlays successfully"
		else
			echo "[ERROR] Error copying .dtb overlay: $DTB_ADS7846_OVERLAY to $SD_BOOT_PATH/overlays"
			exit 1
		fi
	fi
	#/* copy DTB_TCA6424A_OVERLAY */
	if [ "$MODEL" = "3b-flea3" ]; then
		sudo sh -c "mkdir -p $SD_BOOT_PATH/overlays"
		sudo sh -c "cp $DTB_OVERLAY_PATH/$DTB_TCA6424A_OVERLAY $SD_BOOT_PATH/overlays > /dev/null 2>&1"
		if [ "$?" = "0" ]; then
			echo "[INFO] $DTB_TCA6424A_OVERLAY file copied to $SD_BOOT_PATH/overlays successfully"
		else
			echo "[ERROR] Error copying .dtb overlay: $DTB_TCA6424A_OVERLAY to $SD_BOOT_PATH/overlays"
			exit 1
		fi
	fi
	#/* copy kernel to sd boot partition */
	sudo sh -c "cp $KERNEL $SD_BOOT_PATH > /dev/null 2>&1"
	if [ "$?" = "0" ]; then
		echo "[INFO] Kernel copied to $SD_BOOT_PATH successfully"
	else
		echo "[ERROR] Error copying kernel to $SD_BOOT_PATH"
		exit 1
	fi

	#/* umount sd boot partition */
	sync
	sudo sh -c "umount -f ${DRIVE}1 > /dev/null 2>&1"
	if [ "$?" = "0" ]; then
		echo "[INFO] ${DRIVE}1 dismounted successfully"
	else
		echo "[ERROR] Error dismounting ${DRIVE}1"
		exit 1
	fi
	#/* copy root fs to sd rootfs partition */
	sudo sh -c "rm -rf ${SD_ROOTFS_PATH}/* > /dev/null 2>&1"
	sudo sh -c "tar -xvf $ROOTFS -C $SD_ROOTFS_PATH > /dev/null 2>&1"
	if [ "$?" = "0" ]; then
		echo "[INFO] $ROOTFS file untar and copied to $SD_ROOTFS_PATH successfully"
	else
		echo "[ERROR] Error copying $ROOTFS file to $SD_ROOTFS_PATH"
		exit 1
	fi

	if [ "$DTB_OVERLAY_PI3_DISABLE_BT_FILE" != "" ]; then
		sudo sh -c "mkdir -p $SD_ROOTFS_PATH/lib/firmware/brcm"
		sudo sh -c "cp $BRCM_DRIVER_PATH/brcmfmac43430-sdio.* $SD_ROOTFS_PATH/lib/firmware/brcm"
		if [ "$?" = "0" ]; then
			echo "[INFO] brcmfmac43430-sdio.* files copied to $SD_ROOTFS_PATH/lib/firmware/brcm successfully"
		else
			echo "[ERROR] Error copying brcmfmac43430-sdio.* files file to $SD_ROOTFS_PATH/lib/firmware/brcm"
			exit 1
		fi
		if [ -f $WPA_SUPPLICAN_FILE ]; then
			echo "[INFO] Creating wpa supplicant file: $WPA_SUPPLICAN_FILE"
			sudo sh -c "sed -i 's/SSID/$SSID/g' $WPA_SUPPLICAN_FILE"
			sudo sh -c "sed -i 's/TAG/$TAG/g' $WPA_SUPPLICAN_FILE"
			sudo sh -c "sed -i 's/PASSWORD/$PASSWORD/g' $WPA_SUPPLICAN_FILE"
		else
			echo "[ERROR] Error modifying supplicant config file: $WPA_SUPPLICAN_FILE"
			exit 1
		fi
	fi
	#/* umount sd rootfs partition */
	sync
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
