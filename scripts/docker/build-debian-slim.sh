#!/usr/bin/env bash
set -veu

IMAGES="$(dirname "$0")"/../../images/debian-slim
OUT_ROOTFS_TAR="$IMAGES"/rootfs.tar
OUT_ROOTFS_FLAT="$IMAGES"/rootfs-flat
OUT_FSJSON="$IMAGES"/base-fs.json
CONTAINER_NAME=debian-slim
IMAGE_NAME=i386/debian-slim

mkdir -p "$IMAGES"
docker build -f docker/debian.slim.Dockerfile . --platform linux/386 --rm --tag "$IMAGE_NAME"
docker rm "$CONTAINER_NAME" || true
docker create --platform linux/386 -t -i --name "$CONTAINER_NAME" "$IMAGE_NAME" bash

docker export "$CONTAINER_NAME" > "$OUT_ROOTFS_TAR"

"$(dirname "$0")"/../fs2json.py --out "$OUT_FSJSON" "$OUT_ROOTFS_TAR"

# Note: Not deleting old files here
mkdir -p "$OUT_ROOTFS_FLAT"
"$(dirname "$0")"/../copy-to-sha256.py "$OUT_ROOTFS_TAR" "$OUT_ROOTFS_FLAT"

echo "$OUT_ROOTFS_TAR", "$OUT_ROOTFS_FLAT" and "$OUT_FSJSON" created.
