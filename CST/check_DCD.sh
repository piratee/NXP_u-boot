#!/bin/bash
# 5. 检查并清零IVT->DCD指针
IMAGE="../tmp/u-boot-dtb.imx-signed"
IMAGE_DCD0="u-boot-dtb.imx-signed-dcd0"
cp ${IMAGE} "../tmp/${IMAGE_DCD0}"
DCD_PTR=$(xxd -p -s 12 -l 4 "../tmp/${IMAGE_DCD0}")
if [ "$DCD_PTR" != "00000000" ]; then
    printf "\x00\x00\x00\x00" | dd of="../tmp/${IMAGE_DCD0}" bs=1 seek=12 conv=notrunc
    echo "IVT->DCD指针已清零"
fi
