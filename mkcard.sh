#! /bin/sh
#/* @file mkcard.sh
#   @author Oscar Gómez Fuente <oscargomez@tedesys.com>
#   @ingroup TEDESYS GLOBAL S.L.
#   @date 2016-03-04
#   @version 1.0.0
#   @section DESCRIPTION
#    Script to format sd card  with two partition boot.vfat (boot flag) and rootfs.ext4
#    Resources:
#      
#       Parts of the procudure base on the work of Denys Dmytriyenko
#    http://wiki.omap.com/index.php/MMC_Boot_Format
#*/

export LC_ALL=C

if [ "$#" != "1" ]; then
	echo "[INFO] Usage: $0 path_drive" 
	exit 1
fi

DRIVE=$1

if [ "$DIRVE" = "/dev/sda" ]; then
	echo "[ERROR] DANGER!! You're trying to destroyed the partition table of your PC" 
	exit 1
fi

if [ ! -e $DRIVE ]; then
	echo "[ERROR] Drive: $DRIVE doesn't exist" 
	exit 1
fi

echo "[INFO] DANGER!! You're trying to destroyed the partition table of your: $DRIVE" 
echo "Do you want to continue? [Y/N]" 
read ANSWER

if [ "$ANSWER" != "Y" -a "$ANSWER" != "y" ]; then
	echo "[INFO] Operation cancelled" 
	exit 1
fi

echo "[INFO] You've just decided to use the partition table of your: $DRIVE" 

#/* Name of partitions */
NAME_P1="boot" 
NAME_P2="rootfs" 

echo "[INFO] drive $DRIVE" 

dd if=/dev/zero of=$DRIVE bs=1024 count=1024 > /dev/null 2>&1
if [ "$?" = "0" ]; then
	echo  "[INFO] SD card deleted successfully" 
fi

SIZE=$(fdisk -l $DRIVE 2>&1 | grep Disk | grep bytes | awk '{print $5}')
echo "[INFO] Disk Size: $SIZE bytes" 

CYLINDERS=$(echo $SIZE/255/63/512 | bc)
echo "[INFO] Number Cylinders: $CYLINDERS" 

{
	echo ,9,0x0C,*
	echo ,,,-
} | sfdisk -D -H 255 -S 63 -C $CYLINDERS $DRIVE > /dev/null 2>&1

sleep 1

#if [ -x `which kpartx` ]; then
#    echo -ne "kpartx -a ${DRIVE}\n" 
#fi

# handle various device names.
# note something like fdisk -l /dev/loop0 | egrep -E '^/dev' | cut -d' ' -f1 
# won't work due to https://bugzilla.redhat.com/show_bug.cgi?id=649572

DRIVE_NAME=$(basename $DRIVE)
DEV_DIR=$(dirname $DRIVE)

#Partition 1
PARTITION1=${DRIVE}1
if [ ! -b $PARTITION1 ]; then
	PARTITION1=${DRIVE}p1
fi

if [ ! -b $PARTITION1 ]; then
	PARTITION1=${DEV_DIR}/mapper/${DRIVE_NAME}p1
fi

PARTITION2=${DRIVE}2
if [ ! -b $PARTITION2 ]; then
	PARTITION2=${DRIVE}p2
fi
if [ ! -b $PARTITION2 ]; then
	PARTITION2=${DEV_DIR}/mapper/${DRIVE_NAME}p2
fi

#/* now make partitions. */
#/* partition 1. */
if [ -b $PARTITION1 ]; then    
	umount $PARTITION1 > /dev/null 2>&1
	mkfs.vfat -F 32 -n $NAME_P1 $PARTITION1 > /dev/null 2>&1
	if [ "$?" = "0" ]; then
		echo "[INFO] Created vfat partition for boot in $PARTITION1" 
	else
		echo "[ERROR] Error creating vfat partition for boot in $PARTITION1" 
		exit 1
	fi    
else
	echo "[ERROR] Can't find boot partition in /dev" 
	exit 1
fi
#/* partition 2. */
if [ -b $PARITION2 ]; then
	umount $PARTITION2 > /dev/null 2>&1
	mkfs.ext4 -L $NAME_P2 $PARTITION2 > /dev/null 2>&1
	if [ "$?" = "0" ]; then
		echo "[INFO] Created ext4 partition for rootfs in $PARTITION2" 
	else
		echo "[INFO] Error creating ext4 partition for rootfs in $PARTITION2" 
		exit 1
	fi
else
	echo "[INFO] Can't find rootfs partition in /dev" 
	exit 1
fi

echo "[INFO] Process successfully" 

exit 0
