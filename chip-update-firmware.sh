#!/bin/bash

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $SCRIPTDIR/common.sh

DL_DIR=".dl"
IMAGESDIR=".new/firmware/images"

DL_URL="http://opensource.nextthing.co/chip/images"

WGET="wget"

FLAVOR=server
BRANCH=stable

PROBES=(spl-40000-1000-100.bin
 spl-400000-4000-500.bin
 spl-400000-4000-680.bin
 sunxi-spl.bin
 u-boot-dtb.bin
 uboot-40000.bin
 uboot-400000.bin)

UBI_PREFIX="chip"
UBI_SUFFIX="ubi.sparse"
UBI_TYPE="400000-4000-680"

while getopts "sgpbfnhB:N:F:" opt; do
  case $opt in
    s)
      echo "== Server selected =="
      FLAVOR=server
      ;;
    g)
      echo "== Gui selected =="
      FLAVOR=gui
      ;;
    p)
      echo "== Pocketchip selected =="
      FLAVOR=pocketchip
      ;;
    b)
      echo "== Buildroot selected =="
      FLAVOR=buildroot
      ;;
    f)
      echo "== Force clean and download =="
      rm -rf .dl/ .new/
      ;;
    n)
      echo "== No Limit mode =="
      NO_LIMIT="while itest.b *0x80400000 -ne 03; do i2c mw 0x34 0x30 0x03; i2c read 0x34 0x30 1 0x80400000; done; "
      ;;
    B)
      BRANCH="$OPTARG"
      echo "== ${BRANCH} branch selected =="
      ;;
    N)
      CACHENUM="$OPTARG"
      echo "== Build number ${CACHENUM} selected =="
      ;;
    F)
      FORMAT="$OPTARG"
      echo "== Format ${FORMAT} selected =="
      ;;
    h)
      echo ""
      echo "== Help =="
      echo ""
      echo "  -s  --  Server             [Debian + Headless]"
      echo "  -g  --  GUI                [Debian + XFCE]"
      echo "  -p  --  PocketCHIP"
      echo "  -b  --  Buildroot"
      echo "  -f  --  Force clean"
      echo "  -n  --  No limit           [enable greater power draw]"
      echo "  -B  --  Branch(optional)   [eg. -B testing]"
      echo "  -N  --  Build#(optional)   [eg. -N 150]"
      echo "  -F  --  Format(optional)   [eg. -F Toshiba_4G_MLC]"
      echo ""
      echo ""
      exit 0
      ;;
    \?)
      echo "== Invalid option: -$OPTARG ==" >&2
      exit 1
      ;;
  esac
done

function require_directory {
  if [[ ! -d "${1}" ]]; then
      mkdir -p "${1}"
  fi
}

function dl_probe {

  if [ -z $CACHENUM ]; then
    CACHENUM=$(curl -s $DL_URL/$BRANCH/$FLAVOR/latest)
  fi

  if [[ ! -d "$DL_DIR/$BRANCH-$FLAVOR-b${CACHENUM}" ]]; then
    echo "== New image available =="

    rm -rf $DL_DIR/$BRANCH-$FLAVOR*
    
    mkdir -p $DL_DIR/${BRANCH}-${FLAVOR}-b${CACHENUM}
    pushd $DL_DIR/${BRANCH}-${FLAVOR}-b${CACHENUM} > /dev/null
    
    echo "== Downloading.. =="
    for FILE in ${PROBES[@]}; do
      if ! $WGET $DL_URL/$BRANCH/$FLAVOR/${CACHENUM}/$FILE; then
        echo "!! download of $BRANCH-$FLAVOR-$METHOD-b${CACHENUM} failed !!"
        exit $?
      fi
    done
    popd > /dev/null
  else
    echo "== Cached probe files located =="
  fi

  echo "== Staging for NAND probe =="
  ln -s ../../$DL_DIR/${BRANCH}-${FLAVOR}-b${CACHENUM}/ $IMAGESDIR
  if [[ -f ${IMAGESDIR}/ubi_type ]]; then rm ${IMAGESDIR}/ubi_type; fi

  if [ -z $FORMAT ]; then
    detect_nand
  else
    case $FORMAT in
      "Hynix_8G_MLC")
        export nand_erasesize=400000
        export nand_oobsize=680
        export nand_writesize=4000
        UBI_TYPE="400000-4000-680"
      ;;
      "Toshiba_4G_MLC")
        export nand_erasesize=400000
        export nand_oobsize=500
        export nand_writesize=4000
        UBI_TYPE="400000-4000-500"
      ;;
      "Toshiba_512M_MLC")
        export nand_erasesize=40000
        export nand_oobsize=100
        export nand_writesize=1000
        UBI_TYPE="400000-1000-100"
      ;;
      \?)
    	echo "== Invalid format: $FORMAT ==" >&2
    	exit 1
    ;;
    esac
  fi

  if [[ ! -f "$DL_DIR/$BRANCH-$FLAVOR-b${CACHENUM}/$UBI_PREFIX-$UBI_TYPE.$UBI_SUFFIX" ]]; then
    echo "== Downloading new UBI, this will be cached for future flashes. =="
    pushd $DL_DIR/${BRANCH}-${FLAVOR}-b${CACHENUM} > /dev/null
    if ! $WGET $DL_URL/$BRANCH/$FLAVOR/${CACHENUM}/$UBI_PREFIX-$UBI_TYPE.$UBI_SUFFIX; then
      echo "!! download of $BRANCH-$FLAVOR-$METHOD-b${CACHENUM} failed !!"
    exit $?
    fi
    popd > /dev/null
    else
      echo "== Cached UBI located =="
  fi
}

echo == preparing images ==
require_directory "$IMAGESDIR"
rm -rf ${IMAGESDIR}
require_directory "$DL_DIR"

##pass
dl_probe || (
  ##fail
  echo -e "\n FLASH VERIFICATION FAILED.\n\n"
  echo -e "\tTROUBLESHOOTING:\n"
  echo -e "\tIs the FEL pin connected to GND?"
  echo -e "\tHave you tried turning it off and turning it on again?"
  echo -e "\tDid you run the setup script in CHIP-SDK?"
  echo -e "\tDownload could be corrupt, it can be re-downloaded by adding the '-f' flag."
  echo -e "\n\n"
  exit 1
)

##pass
flash_images && ready_to_roll || (
  ##fail
  echo -e "\n FLASH VERIFICATION FAILED.\n\n"
  echo -e "\tTROUBLESHOOTING:\n"
  echo -e "\tIs the FEL pin connected to GND?"
  echo -e "\tHave you tried turning it off and turning it on again?"
  echo -e "\tDid you run the setup script in CHIP-SDK?"
  echo -e "\tDownload could be corrupt, it can be re-downloaded by adding the '-f' flag."
  echo -e "\n\n"
)
