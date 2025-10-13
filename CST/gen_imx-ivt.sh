#!/bin/bash
# filepath: gen_u-boot_ivt.sh

# 用法: ./gen_u-boot_ivt.sh u-boot-dtb.imx 0x877ff420

set -e

if [ $# -ne 2 ]; then
    # echo "Usage: $0 <u-boot-dtb.imx> <loadaddr>"
    echo "Usage: $0 <u-boot-dtb.imx>"
    exit 1
fi

IMAGE=$1
LOADADDR=$2
# LOADADDR=0x877ff420

if [ ! -f "$IMAGE" ]; then
    echo "Error: $IMAGE not found!"
    exit 1
fi

# 1. 镜像本体对齐到0x1000
IMAGE_SIZE=$(wc -c < "$IMAGE")
ALIGNED_SIZE=$(( ($IMAGE_SIZE + 0x1000 - 1) & ~ (0x1000 - 1) ))
objcopy -I binary -O binary --pad-to $ALIGNED_SIZE --gap-fill=0x00 "$IMAGE" "${IMAGE}-pad"

# 2. 生成IVT头（输出为int.bin）
SCRIPT_DIR=$(dirname "$0")
# echo "SCRIPT_DIR: ${SCRIPT_DIR}"
"$SCRIPT_DIR/var-genIVT.sh" $LOADADDR $(printf "0x%x" $ALIGNED_SIZE)

# 3. 拼接IVT头和镜像本体，生成目标文件
cat ivt.bin "${IMAGE}-pad" > "${IMAGE}-ivt"

echo "生成完成: ${IMAGE}-ivt"