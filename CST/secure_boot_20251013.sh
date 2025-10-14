#!/bin/bash
# filepath: secure_boot_20251013.sh
# 用法: ./secure_boot_20251013.sh u-boot-dtb.imx 0x877ff420

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <u-boot-dtb.imx> <loadaddr>"
    exit 1
fi

IMAGE=$1
# LOADADDR=$2
LOADADDR=0x877ff420

if [ ! -f "$IMAGE" ]; then
    echo "Error: $IMAGE not found!"
    exit 1
fi

SCRIPT_DIR=$(dirname "$0")
CST_TOOL="${SCRIPT_DIR}/linux64/bin/cst"
CRT_DIR="${SCRIPT_DIR}/crts"

# 检查必要的工具和文件是否存在

if [ ! -f "$CST_TOOL" ]; then
    echo "Error: $CST_TOOL not found!"
    exit 1
fi

if [ ! -d "$CRT_DIR" ]; then
    echo "Error: Certificate directory $CRT_DIR not found!"
    exit 1
fi

# 1. 生成CSF描述文件
CSF_FILE="${IMAGE}-csf"
IMG_SIZE=$(wc -c < "$IMAGE")
IMG_SIZE_HEX=$(printf "0x%x" $IMG_SIZE)

cat > "$CSF_FILE" <<EOF
[Header]
Version = 4.2
Hash Algorithm = sha256
Engine = SW
Engine Configuration = 0
Certificate Format = X509
Signature Format = CMS

[Install SRK]
File = "$CRT_DIR/SRK_1_2_3_4_table.bin"
Source index = 0

[Install CSFK]
File = "$CRT_DIR/CSF1_1_sha256_2048_65537_v3_usr_crt.pem"

[Authenticate CSF]

[Install Key]
Verification index = 0
Target index = 2
File = "$CRT_DIR/IMG1_1_sha256_2048_65537_v3_usr_crt.pem"

[Authenticate Data]
Verification index = 2
# Blocks = $LOADADDR   0x0000   $IMG_SIZE_HEX   "$IVT_IMAGE"
Blocks = 0x877ff400 0x00000000 0x00091c00 "../tmp/u-boot-dtb.imx"
EOF

echo "生成CSF描述文件: done: LOADADDR = $LOADADDR, IMG_SIZE_HEX = $IMG_SIZE_HEX"
# 3. 生成CSF二进制
# ./linux64/bin/cst -i "$CSF_FILE" -o "${IVT_IMAGE}_csf.bin"
"$CST_TOOL" -i "$CSF_FILE" -o "${IMAGE}-csf.bin"
echo "生成CSF二进制: done"

# 4. 合成最终签名镜像
#  $ cat u-boot-dtb.imx csf_uboot.bin > u-boot-signed.imx
cat "$IMAGE" "${IMAGE}-csf.bin" > "${IMAGE}-signed"

echo "签名完成: ${IMAGE}-signed"

# 5. - Flash signed U-Boot binary:

#   sudo dd if=u-boot-signed.imx of=/dev/sd<x> bs=1K seek=1 && sync

FLUSH_IMAGE="${IMAGE}-signed"


../para-script/para-download-sd.sh $FLUSH_IMAGE