#!/bin/bash
# filepath: secure_boot_20251013.sh
# 用法: ./secure_boot_20251013.sh u-boot-dtb.imx 
# these steps fellow NXP_u-boot/doc/imx/habv4/guides/mx6_mx7_secure_boot.txt
set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <u-boot-dtb.imx>"
    exit 1
fi

IMAGE=$1

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

# 1. generate CSF description file
if [ ! -f ${IMAGE}.log ]; then
    echo "Error: ${IMAGE}.log not found!"
fi

ENTRY_BLOCKS=`grep 'Entry Point:' ${IMAGE}.log`
ENTRY_POINT=`awk '{print $3}' <<< ${ENTRY_BLOCKS}`

HAB_BLOCKS=`grep 'HAB Blocks:' ${IMAGE}.log`
RAM_AUTH_AREA_START=`awk '{print $3}' <<< ${HAB_BLOCKS}`
IMG_SIGN_AREA_START=`awk '{print $4}' <<< ${HAB_BLOCKS}`
IMG_SIGN_AREA_SIZE=`awk '{print $5}' <<< ${HAB_BLOCKS}`

if [ -z "$RAM_AUTH_AREA_START" -o -z "$IMG_SIGN_AREA_START" -o -z "$IMG_SIGN_AREA_SIZE" ]; then
    echo "Error: log file is corrupted"
    shift
    continue
fi

for arg in ENTRY_POINT RAM_AUTH_AREA_START  IMG_SIGN_AREA_START  IMG_SIGN_AREA_SIZE; do
    eval value=\$$arg
    if [ ${value:0:2} != 0x ]; then
        value=0x${value}
        eval $arg=\$value
    fi
done

CSF_FILE="${SCRIPT_DIR}/csf_uboot.txt"

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
# Blocks = 0x877ff400 0x00000000 0x00091c00 "../tmp/u-boot-dtb.imx"
Blocks = $RAM_AUTH_AREA_START   $IMG_SIGN_AREA_START   $IMG_SIGN_AREA_SIZE  "${IMAGE}"
EOF

echo "generate CSF description file: done"
# 3. generate CSF binary file
# ./linux64/bin/cst -i "$CSF_FILE" -o "${IVT_IMAGE}_csf.bin"
"$CST_TOOL" -i "$CSF_FILE" -o "${SCRIPT_DIR}/csf_uboot.bin"
echo "generate CSF binary file: done"

# 4. Merge u-boot.ims and csf.bin
cat "../tmp/u-boot-dtb.imx" "${SCRIPT_DIR}/csf_uboot.bin" > "../tmp/u-boot-signed.imx"

echo "Sign u-boot complete."

# 5. check CSF section in u-boot-signed.imx
# refer to CST/code/hab_csf_parser/README
echo "Check CSF in csf.bin."
csf_parser -d -c "${SCRIPT_DIR}/csf_uboot.bin"
echo "Check CSF in u-boot-signed.imx."
csf_parser -d -s ../tmp/u-boot-signed.imx
echo "Check CSF complete."

# 5. - Flash signed U-Boot binary:

#   sudo dd if=u-boot-signed.imx of=/dev/sd<x> bs=1K seek=1 && sync

FLUSH_IMAGE="../tmp/u-boot-signed.imx"


../para-script/para-download-sd.sh $FLUSH_IMAGE