#!/bin/sh
#/* @file buildroot2sd.sh
#   @author Oscar Gómez Fuente <oscargomez@tedesys.com>
#   @ingroup TEDESYS GLOBAL S.L.
#   @date 2016-03-07
#   @version 1.0.0
#   @section DESCRIPTION
#    Script to compile buildroot and save boot and rootfs on sd card or eMMC for different raspberry pi models
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
	echo "\t\t3b  -> tedpi-3b  : raspberry pi 3 B v1.1 code: XXX"
	echo "\t-- special models --"
	echo "\t\t2b-pg-fla3 -> tedpi-2b  : raspberry pi 2 B v1.1 code: a01041"
	exit 1
fi

#/* Name of partitions */
NAME_P1="boot"
NAME_P2="rootfs"

#/* Path of bins */
PWD=$(pwd)
PATH_GIT="/home/${USER}/GIT/raspberrypi/buildroot"
if [ "$MODEL" = "1a" -o "$MODEL" = "1b" ]; then
	BUILDROOT_PATH="${PATH_GIT}/buildroot-2016.02-tedpi-1b"
	DTB="${BUILDROOT_PATH}/output/images/bcm2708-rpi-b.dtb"
elif [ "$MODEL" = "1a+" -o "$MODEL" = "1b+" ]; then
	BUILDROOT_PATH="${PATH_GIT}/buildroot-2016.02-tedpi-1b+"
	DTB="${BUILDROOT_PATH}/output/images/bcm2708-rpi-b-plus.dtb"
elif [ "$MODEL" = "cm" ]; then
	BUILDROOT_PATH="${PATH_GIT}/buildroot-2016.02-tedpi-cm"
	DTB="${BUILDROOT_PATH}/output/images/bcm2708-rpi-cm.dtb"
elif [ "$MODEL" = "2b" ]; then
	BUILDROOT_PATH="${PATH_GIT}/buildroot-2016.02-tedpi-2b"
	DTB="${BUILDROOT_PATH}/output/images/bcm2709-rpi-2-b.dtb"
elif [ "$MODEL" = "2b-pg-fla3" ]; then
	BUILDROOT_PATH="${PATH_GIT}/buildroot-2016.02-tedpi-2b-point-grey-flea3"
	DTB="${BUILDROOT_PATH}/output/images/bcm2709-rpi-2-b.dtb"
elif [ "$MODEL" = "3b" ]; then
	BUILDROOT_PATH="${PATH_GIT}/buildroot-2016.02-tedpi-3b"
	DTB="${BUILDROOT_PATH}/output/images/bcm2708-rpi-3b.dtb"
else
	echo "[ERROR] Raspberry pi model unknown: $MODEL"
	exit 1
fi
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
SD_BOOT_PATH="/media/oscargomez/boot"
SD_ROOTFS_PATH="/media/oscargomez/rootfs"
BR_TARGET_PATH="${BUILDROOT_PATH}/output/target"

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
elif [ ! -f $DTB ]; then
    echo "[ERROR] Missing file: $DTB"
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
else
	#/* compile buidroot */
	cd $BUILDROOT_PATH
	make
	if [ "$?" = "0" ]; then
		echo "[INFO] Compiled buildroot"
		cd $PWD
	else
		echo "[ERROR] Compiling buildroot"
		exit 1
	fi
	#/* copy boot files to sd boot partition */
	sudo sh -c "rm -rf ${SD_BOOT_PATH}/* > /dev/null 2>&1"
	sudo sh -c "cp $BOOTCODE $SD_BOOT_PATH > /dev/null 2>&1"
	if [ "$?" = "0" ]; then
		echo "[INFO] bootcode.bin file copied to $SD_BOOT_PATH successfully"
	else
		echo "[ERROR] Error copying bootcode.bin to $SD_BOOT_PATH"
		exit 1
	fi
	sudo sh -c "cp $START $SD_BOOT_PATH > /dev/null 2>&1"
	if [ "$?" = "0" ]; then
		echo "[INFO] start.elf file copied to $SD_BOOT_PATH successfully"
	else
		echo "[ERROR] Error copying start.elf to $SD_BOOT_PATH"
		exit 1
	fi
	sudo sh -c "cp $FIXUP $SD_BOOT_PATH > /dev/null 2>&1"
	if [ "$?" = "0" ]; then
		echo "[INFO] fixup.dat file copied to $SD_BOOT_PATH successfully"
	else
		echo "[ERROR] Error copying fixup.dat to $SD_BOOT_PATH"
		exit 1
	fi
	sudo sh -c "cp $CONFIG $SD_BOOT_PATH > /dev/null 2>&1"
	if [ "$?" = "0" ]; then
		echo "[INFO] config.txt file copied to $SD_BOOT_PATH successfully"
	else
		echo "[ERROR] Error copying config.txt to $SD_BOOT_PATH"
		exit 1
	fi
	sudo sh -c "cp $CMDLINE $SD_BOOT_PATH > /dev/null 2>&1"
	if [ "$?" = "0" ]; then
		echo "[INFO] cmdline.txt file copied to $SD_BOOT_PATH successfully"
	else
		echo "[ERROR] Error copying cmdline.txt to $SD_BOOT_PATH"
		exit 1
	fi
	sudo sh -c "cp $DTB $SD_BOOT_PATH> /dev/null 2>&1"
	if [ "$?" = "0" ]; then
		echo "[INFO] .dtb file copied to $SD_BOOT_PATH successfully"
	else
		echo "[ERROR] Error copying .dtb to $SD_BOOT_PATH"
		exit 1
	fi
	#/* copy kernel to sd boot partition */
	sudo sh -c "cp $KERNEL $SD_BOOT_PATH > /dev/null 2>&1"
	if [ "$?" = "0" ]; then
		echo "[INFO] Kernel copied to $SD_BOOT_PATH successfully"
	else
		echo "[ERROR] Error copying kernel to $SD_BOOT_PATH"
		exit 1
	fi
	
	#/* Build config.txt */
	sudo sh -c "cat << 'EOF' > "${SD_BOOT_PATH}/config.txt"
# Please note that this is only a sample, we recommend you to change it to fit
# your needs.
# You should override this file using a post-build script.
# See http://buildroot.org/manual.html#rootfs-custom
# and http://elinux.org/RPiconfig for a description of config.txt syntax

kernel=zImage

# To use an external initramfs file
#initramfs rootfs.cpio.gz

# Disable overscan assuming the display supports displaying the full resolution
# If the text shown on the screen disappears off the edge, comment this out
disable_overscan=1

# How much memory in MB to assign to the GPU on Pi models having
# 256, 512 or 1024 MB total memory
gpu_mem_256=100
gpu_mem_512=100
gpu_mem_1024=100

EOF"
	if [ "$MODEL" = "1a" -o "$MODEL" = "1b" ]; then
		sudo sh -c "cat << 'EOF' >> "${SD_BOOT_PATH}/config.txt"
#device tree
device_tree=bcm2708-rpi-b.dtb
EOF"
	elif [ "$MODEL" = "1a+" -o "$MODEL" = "1b+" ]; then
		sudo sh -c "cat << 'EOF' >> "${SD_BOOT_PATH}/config.txt"
#device tree
device_tree=bcm2708-rpi-b-plus.dtb
EOF"
	elif [ "$MODEL" = "cm" ]; then
		sudo sh -c "cat << 'EOF' >> "${SD_BOOT_PATH}/config.txt"
#device tree
device_tree=bcm2708-rpi-cm.dtb
EOF"
	elif [ "$MODEL" = "2b" -o "$MODEL" = "2b-pg-fla3" ]; then
		sudo sh -c "cat << 'EOF' >> "${SD_BOOT_PATH}/config.txt"
#device tree
device_tree=bcm2709-rpi-2-b.dtb
EOF"
	elif [ "$MODEL" = "3b" ]; then
		sudo sh -c "cat << 'EOF' >> "${SD_BOOT_PATH}/config.txt"
#device tree
device_tree=bcm2710-rpi-3-b.dtb
EOF"
	fi
	sudo sh -c "cat << 'EOF' >> "${SD_BOOT_PATH}/config.txt"
dtparam=i2c_arm=on,i2c_arm_baudrate=200000
dtparam=spi=on
dtparam=watchdog=on

EOF"
	if [ "$?" = "0" ]; then
		sudo sh -c "chmod 755 ${SD_BOOT_PATH}/config.txt"
		echo "[INFO] Built ${SD_BOOT_PATH}/config.txt file"
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
	
	#/* Build S18loadmod file */
	sudo sh -c "cat << 'EOF' > "${SD_ROOTFS_PATH}/etc/init.d/S18loadmod"
#!/bin/sh
#
# load modules
#

MODULES_PATH=\"/etc/modules\"
case \"\$1\" in
	start)
		echo \"Loading modules in ${MODULES_PATH}...\"
		for line in \$(cat \${MODULES_PATH});
		do
			[[ \$line = \#* ]] && continue
			modprobe \$line;
		done
		;;
	stop)
		;;
	restart|reload)
		;;
	*)
		echo \"Usage: \$0 {start|stop|restart}\"
		exit 1
esac

exit \$?

EOF"
	if [ "$?" = "0" ]; then
		sudo sh -c "chmod 755 ${SD_ROOTFS_PATH}/etc/init.d/S18loadmod"
		echo "[INFO] Built ${SD_ROOTFS_PATH}/etc/init.d/S18loadmod file"
	fi
	
	#/* Build /etc/modules */
	sudo sh -c "cat << 'EOF' > "${SD_ROOTFS_PATH}/etc/modules"
i2c-dev

EOF"
	if [ "$?" = "0" ]; then
		sudo sh -c "chmod 644 ${SD_ROOTFS_PATH}/etc/modules"
		echo "[INFO] Built ${SD_ROOTFS_PATH}/etc/modules"
	fi

	#/* set up /etc/fstab */
	sudo sh -c "cat << 'EOF' >> "${SD_ROOTFS_PATH}/etc/fstab"
/dev/mmcblk0p1  /boot           vfat    defaults        0       2  

EOF"
	if [ "$?" = "0" ]; then
		sudo sh -c "mkdir -p ${SD_ROOTFS_PATH}/boot"
		echo "[INFO] Set up ${SD_ROOTFS_PATH}/etc/fstab"
	fi
	
	if [ "$MODEL" = "2b-pg-fla3" ]; then
		#/* build /etc/udev/rules.d/40-pgr.rules */
		sudo sh -c "cat << 'EOF' > "${SD_ROOTFS_PATH}/etc/udev/rules.d/40-pgr.rules"

ATTRS{idVendor}==\"1e10\", ATTRS{idProduct}==\"2000\", MODE=\"0664\", GROUP=\"$grpname\"
ATTRS{idVendor}==\"1e10\", ATTRS{idProduct}==\"2001\", MODE=\"0664\", GROUP=\"$grpname\"
ATTRS{idVendor}==\"1e10\", ATTRS{idProduct}==\"2002\", MODE=\"0664\", GROUP=\"$grpname\"
ATTRS{idVendor}==\"1e10\", ATTRS{idProduct}==\"2003\", MODE=\"0664\", GROUP=\"$grpname\"
ATTRS{idVendor}==\"1e10\", ATTRS{idProduct}==\"2004\", MODE=\"0664\", GROUP=\"$grpname\"
ATTRS{idVendor}==\"1e10\", ATTRS{idProduct}==\"2005\", MODE=\"0664\", GROUP=\"$grpname\"
ATTRS{idVendor}==\"1e10\", ATTRS{idProduct}==\"3000\", MODE=\"0664\", GROUP=\"$grpname\"
ATTRS{idVendor}==\"1e10\", ATTRS{idProduct}==\"3001\", MODE=\"0664\", GROUP=\"$grpname\"
ATTRS{idVendor}==\"1e10\", ATTRS{idProduct}==\"3004\", MODE=\"0664\", GROUP=\"$grpname\"
ATTRS{idVendor}==\"1e10\", ATTRS{idProduct}==\"3005\", MODE=\"0664\", GROUP=\"$grpname\"
ATTRS{idVendor}==\"1e10\", ATTRS{idProduct}==\"3006\", MODE=\"0664\", GROUP=\"$grpname\"
ATTRS{idVendor}==\"1e10\", ATTRS{idProduct}==\"3007\", MODE=\"0664\", GROUP=\"$grpname\"
ATTRS{idVendor}==\"1e10\", ATTRS{idProduct}==\"3008\", MODE=\"0664\", GROUP=\"$grpname\"
ATTRS{idVendor}==\"1e10\", ATTRS{idProduct}==\"300A\", MODE=\"0664\", GROUP=\"$grpname\"
ATTRS{idVendor}==\"1e10\", ATTRS{idProduct}==\"300B\", MODE=\"0664\", GROUP=\"$grpname\"
ATTRS{idVendor}==\"1e10\", ATTRS{idProduct}==\"3100\", MODE=\"0664\", GROUP=\"$grpname\"
ATTRS{idVendor}==\"1e10\", ATTRS{idProduct}==\"3101\", MODE=\"0664\", GROUP=\"$grpname\"
ATTRS{idVendor}==\"1e10\", ATTRS{idProduct}==\"3102\", MODE=\"0664\", GROUP=\"$grpname\"
ATTRS{idVendor}==\"1e10\", ATTRS{idProduct}==\"3103\", MODE=\"0664\", GROUP=\"$grpname\"
ATTRS{idVendor}==\"1e10\", ATTRS{idProduct}==\"3104\", MODE=\"0664\", GROUP=\"$grpname\"
ATTRS{idVendor}==\"1e10\", ATTRS{idProduct}==\"3105\", MODE=\"0664\", GROUP=\"$grpname\"
ATTRS{idVendor}==\"1e10\", ATTRS{idProduct}==\"3106\", MODE=\"0664\", GROUP=\"$grpname\"
ATTRS{idVendor}==\"1e10\", ATTRS{idProduct}==\"3107\", MODE=\"0664\", GROUP=\"$grpname\"
ATTRS{idVendor}==\"1e10\", ATTRS{idProduct}==\"3108\", MODE=\"0664\", GROUP=\"$grpname\"
ATTRS{idVendor}==\"1e10\", ATTRS{idProduct}==\"3109\", MODE=\"0664\", GROUP=\"$grpname\"
ATTRS{idVendor}==\"1e10\", ATTRS{idProduct}==\"3300\", MODE=\"0664\", GROUP=\"$grpname\"
KERNEL==\"raw1394\", MODE=\"0664\", GROUP=\"$grpname\"
KERNEL==\"video1394*\", MODE=\"0664\", GROUP=\"$grpname\"
SUBSYSTEM==\"firewire\", GROUP=\"pgrimaging\"
SUBSYSTEM==\"usb\", GROUP=\"pgrimaging\"

EOF"
		if [ "$?" = "0" ]; then
			sudo sh -c "chmod 644 ${SD_ROOTFS_PATH}/etc/udev/rules.d/40-pgr.rules"
			echo "[INFO] Built ${SD_ROOTFS_PATH}/etc/udev/rules.d/40-pgr.rules"
		fi
		#/* set up /etc/group */
		sudo sh -c "cat << 'EOF' >> "${SD_ROOTFS_PATH}/etc/group"
pgrimaging:x:1001:root

EOF"
		if [ "$?" = "0" ]; then
			echo "[INFO] Set up ${SD_ROOTFS_PATH}/etc/group"
		fi
		
		FLY_CAPTURE_PATH="/home/oscargomez/Desktop/point_grey_documents/flycapture.2.9.3.13_armhf"
		sudo sh -c "cp -r --preserve=mode ${FLY_CAPTURE_PATH}/bin/ ${FLY_CAPTURE_PATH}/include/ ${FLY_CAPTURE_PATH}/lib/ ${SD_ROOTFS_PATH}"
		if [ "$?" = "0" ]; then
			echo "[INFO] Point Grey Flea3 Fly capture bins for arm saved correctly to ${SD_ROOTFS_PATH}"
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
