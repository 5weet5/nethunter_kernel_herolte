#!/bin/bash
# NetHunter kernel for Samsung Galaxy S7 build script by jcadduono

################### BEFORE STARTING ################
#
# download a working toolchain and extract it somewhere and configure this
# file to point to the toolchain's root directory.
#
# once you've set up the config section how you like it, you can simply run
# ./build.sh [VARIANT]
#
##################### VARIANTS #####################
#
# xx   = International Exynos & Duos, Canadian Exynos
#        SM-G930F, SM-G930FD, SM-G930X, SM-G930W8
#        SM-G935F, SM-G935FD, SM-G935X, SM-G935W8
#
# kor  = Korean Exynos
#        SM-G930K, SM-G930L, SM-G930S
#
###################### CONFIG ######################

# root directory of NetHunter herolte git repo (default is this script's location)
RDIR=$(pwd)

[ "$VER" ] ||
# version number
VER=$(cat "$RDIR/VERSION")

# directory containing cross-compile arm64 toolchain
TOOLCHAIN=$HOME/build/toolchain/gcc-linaro-4.9-2016.02-x86_64_aarch64-linux-gnu

# amount of cpu threads to use in kernel make process
THREADS=5

############## SCARY NO-TOUCHY STUFF ###############

ABORT()
{
	[ "$1" ] && echo "Error: $*"
	exit 1
}

export ARCH=arm64
export CROSS_COMPILE=$TOOLCHAIN/bin/aarch64-linux-gnu-

[ -x "${CROSS_COMPILE}gcc" ] ||
ABORT "Unable to find gcc cross-compiler at location: ${CROSS_COMPILE}gcc"

[ "$TARGET" ] || TARGET=nethunter
[ "$1" ] && DEVICE=$1
[ "$2" ] && VARIANT=$2
[ "$DEVICE" ] || DEVICE=herolte
[ "$VARIANT" ] || VARIANT=xx

DEFCONFIG=${TARGET}_defconfig
DEVICE_DEFCONFIG=device_${DEVICE}
VARIANT_DEFCONFIG=variant_${DEVICE}_${VARIANT}

[ -f "$RDIR/arch/$ARCH/configs/${DEFCONFIG}" ] ||
ABORT "Config $DEFCONFIG not found in $ARCH configs!"

[ -f "$RDIR/arch/$ARCH/configs/${DEVICE_DEFCONFIG}" ] ||
ABORT "Device config $DEVICE_DEFCONFIG not found in $ARCH configs!"

[ -f "$RDIR/arch/$ARCH/configs/${VARIANT_DEFCONFIG}" ] ||
ABORT "Variant config $VARIANT_DEFCONFIG not found in $ARCH configs!"

export LOCALVERSION=$TARGET-$DEVICE-$VARIANT-$VER

CLEAN_BUILD()
{
	echo "Cleaning build..."
	cd "$RDIR"
	rm -rf build
}

SETUP_BUILD()
{
	echo "Creating kernel config for $LOCALVERSION..."
	cd "$RDIR"
	mkdir -p build
	make -C "$RDIR" O=build "$DEFCONFIG" \
		DEVICE_DEFCONFIG="$DEVICE_DEFCONFIG" \
		VARIANT_DEFCONFIG="$VARIANT_DEFCONFIG" \
		|| ABORT "Failed to set up build"
}

BUILD_KERNEL()
{
	echo "Starting build for $LOCALVERSION..."
	while ! make -C "$RDIR" O=build -j"$THREADS"; do
		read -p "Build failed. Retry? " do_retry
		case $do_retry in
			Y|y) continue ;;
			*) return 1 ;;
		esac
	done
}

BUILD_DTB()
{
	echo "Generating dtb.img..."
	"$RDIR/dtbgen.sh" "$DEVICE" "$VARIANT" || ABORT "Failed to generate dtb.img!"
}

CLEAN_BUILD && SETUP_BUILD && BUILD_KERNEL && BUILD_DTB && echo "Finished building $LOCALVERSION!"
