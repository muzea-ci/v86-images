#!/usr/bin/env bash
set -veu

IMAGES="$(dirname "$0")"/../../images/debian-filer
SYS_CFG="$(dirname "$0")"/syslinux.cfg
OUT_ROOTFS_TAR="$IMAGES"/rootfs.tar
CONTAINER_NAME=debian-filer
IMAGE_NAME=i386/debian-filer
IMAGE_HDA="$IMAGES"/linux.img

mkdir -p "$IMAGES"
docker build -f ./debian.filer.Dockerfile . --platform linux/386 --rm --tag "$IMAGE_NAME"
docker rm "$CONTAINER_NAME" || true
docker create --platform linux/386 -t -i --name "$CONTAINER_NAME" "$IMAGE_NAME" bash

docker export "$CONTAINER_NAME" -o "$OUT_ROOTFS_TAR"

echo "$OUT_ROOTFS_TAR" created.


IMG_SIZE=$(expr 1024 \* 1024 \* 1024)
dd if=/dev/zero of="$IMAGE_HDA" bs=${IMG_SIZE} count=1

sfdisk "$IMAGE_HDA" <<EOF
label: dos
label-id: 0x5d8b75fc
device: new.img
unit: sectors

linux.img1 : start=2048, size=2095104, type=83, bootable
EOF


OFFSET=$(expr 512 \* 2048)
losetup -o ${OFFSET} /dev/loop5 "$IMAGE_HDA"
mkfs.ext3 /dev/loop5
mkdir -p /tmp/v86
mount -t auto /dev/loop5 /tmp/v86
tar -xvf "$OUT_ROOTFS_TAR" -C /tmp/v86

extlinux --install /tmp/v86/boot/
cp "$SYS_CFG" /tmp/v86/boot/syslinux.cfg

echo "host9p      /mnt        9p      trans=virtio,version=9p2000.L,rw        0   0" >> /tmp/v86/etc/fstab

dd if=/usr/lib/syslinux/mbr/mbr.bin of="$IMAGE_HDA" bs=440 count=1 conv=notrunc

umount /tmp/v86
losetup -D

zstd -9 "$IMAGE_HDA" -o "$IMAGES"/linux.img.zstd
echo "$IMAGE_HDA" created.
