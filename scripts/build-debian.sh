#!/usr/bin/env bash
set -veu

while [[ $# -gt 0 ]]; do
  case $1 in
    --image)
      IMAGE_NAME="$2"
      shift
      shift
      ;;
    --dockerfile)
      DOCKERFILE="$2"
      shift
      shift
      ;;
    --size)
      SIZE="$2"
      shift
      shift
      ;;
    --memory)
      MEMORY="$2"
      shift
      shift
      ;;
  esac
done

echo "image          = ${IMAGE_NAME}"
echo "dockerfile     = ${DOCKERFILE}"


IMAGES="$(dirname "$0")"/../images/"$IMAGE_NAME"
SYS_CFG="$(dirname "$0")"/docker/syslinux.cfg
OUT_ROOTFS_TAR="$IMAGES"/rootfs.tar
CONTAINER_NAME="$IMAGE_NAME"
IMAGE_TAG=i386/"$IMAGE_NAME"
IMAGE_HDA="$IMAGES"/linux.img

mkdir -p "$IMAGES"

cd docker
docker build -f ./"$DOCKERFILE" . --platform linux/386 --rm --tag "$IMAGE_TAG"
cd ..

docker rm "$CONTAINER_NAME" || true
docker create --platform linux/386 -t -i --name "$CONTAINER_NAME" "$IMAGE_TAG" bash
docker export ${CONTAINER_NAME} -o "${OUT_ROOTFS_TAR}"
echo "$OUT_ROOTFS_TAR" created.


IMG_SIZE=$(expr ${SIZE} \* 1024 \* 1024)
SECTOR_SIZE=$(expr ${SIZE} \* 1024 \* 1024 \/ 512 \- 2048)
echo hdd size is $IMG_SIZE $SECTOR_SIZE.
dd if=/dev/zero of="$IMAGE_HDA" bs=${IMG_SIZE} count=1

sfdisk "$IMAGE_HDA" <<EOF
label: dos
label-id: 0x5d8b75fc
device: new.img
unit: sectors

linux.img1 : start=2048, size=${SECTOR_SIZE}, type=83, bootable
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
echo "nameserver 8.8.8.8" > /tmp/v86/etc/resolv.conf

dd if=/usr/lib/syslinux/mbr/mbr.bin of="$IMAGE_HDA" bs=440 count=1 conv=notrunc

umount /tmp/v86
losetup -D

zstd -9 "$IMAGE_HDA" -o "$IMAGES"/linux.img.zst
echo "$IMAGE_HDA" image created.

node ./build-state.js --image "$IMAGE_NAME" --memory ${MEMORY}
zstd -9 "$IMAGES"/state.bin -o "$IMAGES"/state.bin.zst
echo snapshot created.
