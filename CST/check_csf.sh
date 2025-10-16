#!/bin/bash
# 查看IVT
hexdump -C ../tmp/u-boot-signed.imx | head -40

# 计算CSF区偏移并查看
CSF_POINTER_HEX=$(od -An -tx4 -N 4 -j 0x18 ../tmp/u-boot-signed.imx | tr -d ' ')
CSF_POINTER=$((16#$CSF_POINTER_HEX))    # 0x87891000
IMAGE_BASE=0x87800000
CSF_OFFSET=$(($CSF_POINTER - $IMAGE_BASE))  # 91000
# echo "\nCSF_POINTER = $CSF_POINTER \nCSF_OFFSET = $CSF_OFFSET)\n"
dd if=../tmp/u-boot-signed.imx bs=1 skip=$CSF_OFFSET count=512 | hexdump -C