#!/bin/bash
# filepath: sign_u-boot_hab.sh
# 用法: ./sign_u-boot_hab.sh u-boot-imx6ull-14x14-emmc.imx 0x87800000

set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <u-boot.imx> <loadaddr>"
    exit 1
fi

IMAGE=$1
LOADADDR=$2
# LOADADDR=0x87800000

if [ ! -f "$IMAGE" ]; then
    echo "Error: $IMAGE not found!"
    exit 1
fi

SCRIPT_DIR=$(dirname "$0")
CST_TOOL="${SCRIPT_DIR}/linux64/bin/cst"
GEN_IVT_SCRIPT="${SCRIPT_DIR}/gen_imx-ivt.sh"
CRT_DIR="${SCRIPT_DIR}/crts"

# 检查必要的工具和文件是否存在
if [ ! -f "$GEN_IVT_SCRIPT" ]; then
    echo "Error: $GEN_IVT_SCRIPT not found!"
    exit 1
fi

if [ ! -f "$CST_TOOL" ]; then
    echo "Error: $CST_TOOL not found!"
    exit 1
fi

if [ ! -d "$CRT_DIR" ]; then
    echo "Error: Certificate directory $CRT_DIR not found!"
    exit 1
fi

# 1. 生成带IVT的镜像
"$GEN_IVT_SCRIPT" "$IMAGE" "$LOADADDR"
echo "生成带IVT的镜像: done"

# 2. 生成CSF描述文件
IVT_IMAGE="${IMAGE}-ivt"
CSF_FILE="${IVT_IMAGE}.csf"
IMG_SIZE=$(wc -c < "$IVT_IMAGE")
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
Blocks = $LOADADDR   0x0000   $IMG_SIZE_HEX   "$IVT_IMAGE"
EOF

echo "生成CSF描述文件: done"
# 3. 生成CSF二进制
# ./linux64/bin/cst -i "$CSF_FILE" -o "${IVT_IMAGE}_csf.bin"
"$CST_TOOL" -i "$CSF_FILE" -o "${IVT_IMAGE}_csf.bin"
echo "生成CSF二进制: done"

# 4. 合成最终签名镜像
cat "$IVT_IMAGE" "${IVT_IMAGE}_csf.bin" > "${IMAGE}-ivt_signed"
echo "合成最终签名镜像: done"

# 5. 检查并清零IVT->DCD指针
DCD_PTR=$(xxd -p -s 12 -l 4 "${IMAGE}-ivt_signed")
if [ "$DCD_PTR" != "00000000" ]; then
    printf "\x00\x00\x00\x00" | dd of="${IMAGE}-ivt_signed" bs=1 seek=12 conv=notrunc
    echo "IVT->DCD指针已清零"
fi

echo "签名完成: ${IMAGE}-ivt_signed"