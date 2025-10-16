#!/bin/bash
# filepath: secure_boot_20251013.sh
# 用法: ./secure_boot_20251013.sh u-boot-dtb.imx 
# these steps fellow NXP_u-boot/doc/imx/habv4/guides/mx6_mx7_secure_boot.txt
set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <u-boot-dtb.imx> <loadaddr>"
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

# 1. 生成CSF描述文件
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

CSF_FILE="../tmp/csf_uboot.txt"

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

echo "生成CSF描述文件."
# 3. 生成CSF二进制
# ./linux64/bin/cst -i "$CSF_FILE" -o "${IVT_IMAGE}_csf.bin"
"$CST_TOOL" -i "$CSF_FILE" -o "../tmp/csf_uboot.bin"
echo "生成CSF二进制: done"
# If keep IVT->CSF:
# hab_status only raise 1 HAB Event below:
# => hab_status

# Secure boot disabled

# HAB Configuration: 0xf0, HAB State: 0x66

# --------- HAB Event 1 -----------------
# event data:
#         0xdb 0x00 0x08 0x42 0x33 0x05 0x0a 0x00

# STS = HAB_FAILURE (0x33)
# RSN = HAB_INV_IVT (0x05)
# CTX = HAB_CTX_AUTHENTICATE (0x0A)
# ENG = HAB_ENG_ANY (0x00)



# 4. change IVT->CSF and Boot_data->start,  Boot_data->length
# 4.1 change IVT->CSF with image real length
# if IVT->CSF changed, hab_status will raise 6 HAB Events, below:
# => hab_status

# Secure boot disabled

# HAB Configuration: 0xf0, HAB State: 0x66

# --------- HAB Event 1 -----------------
# event data:
#         0xdb 0x00 0x08 0x42 0x33 0x05 0x0a 0x00

# STS = HAB_FAILURE (0x33)
# RSN = HAB_INV_IVT (0x05)
# CTX = HAB_CTX_AUTHENTICATE (0x0A)
# ENG = HAB_ENG_ANY (0x00)


# --------- HAB Event 2 -----------------
# event data:
#         0xdb 0x00 0x08 0x42 0x33 0x11 0xcf 0x00

# STS = HAB_FAILURE (0x33)
# RSN = HAB_INV_CSF (0x11)
# CTX = HAB_CTX_CSF (0xCF)
# ENG = HAB_ENG_ANY (0x00)


# --------- HAB Event 3 -----------------
# event data:
#         0xdb 0x00 0x14 0x42 0x33 0x0c 0xa0 0x00
#         0x00 0x00 0x00 0x00 0x87 0x7f 0xf4 0x00
#         0x00 0x00 0x00 0x20

# STS = HAB_FAILURE (0x33)
# RSN = HAB_INV_ASSERTION (0x0C)
# CTX = HAB_CTX_ASSERT (0xA0)
# ENG = HAB_ENG_ANY (0x00)


# --------- HAB Event 4 -----------------
# event data:
#         0xdb 0x00 0x14 0x42 0x33 0x0c 0xa0 0x00
#         0x00 0x00 0x00 0x00 0x87 0x7f 0xf4 0x2c
#         0x00 0x00 0x01 0xe8

# STS = HAB_FAILURE (0x33)
# RSN = HAB_INV_ASSERTION (0x0C)
# CTX = HAB_CTX_ASSERT (0xA0)
# ENG = HAB_ENG_ANY (0x00)


# --------- HAB Event 5 -----------------
# event data:
#         0xdb 0x00 0x14 0x42 0x33 0x0c 0xa0 0x00
#         0x00 0x00 0x00 0x00 0x87 0x7f 0xf4 0x20
#         0x00 0x00 0x00 0x01

# STS = HAB_FAILURE (0x33)
# RSN = HAB_INV_ASSERTION (0x0C)
# CTX = HAB_CTX_ASSERT (0xA0)
# ENG = HAB_ENG_ANY (0x00)


# --------- HAB Event 6 -----------------
# event data:
#         0xdb 0x00 0x14 0x42 0x33 0x0c 0xa0 0x00
#         0x00 0x00 0x00 0x00 0x87 0x80 0x00 0x00
#         0x00 0x00 0x00 0x04

# STS = HAB_FAILURE (0x33)
# RSN = HAB_INV_ASSERTION (0x0C)
# CTX = HAB_CTX_ASSERT (0xA0)
# ENG = HAB_ENG_ANY (0x00)
# --------------------HAB Event log end---------------------------------------

# cp ../tmp/u-boot-dtb.imx ../tmp/u-boot-dtb-new-CSF.imx
# 计算 CSF_POINTER
# CSF_POINTER=$((ENTRY_POINT + IMG_SIGN_AREA_SIZE))
# echo "CSF_POINTER = $ENTRY_POINT + $IMG_SIGN_AREA_SIZE = $CSF_POINTER"
# 将 CSF_POINTER 转换为4字节的小端序十六进制
# CSF_BYTES=$(printf "%08x" $CSF_POINTER | sed 's/\(..\)\(..\)\(..\)\(..\)/\\x\4\\x\3\\x\2\\x\1/')
# 写入CSF指针
# printf "$CSF_BYTES" | dd of=../tmp/u-boot-dtb-new-CSF.imx bs=1 seek=$((0x18)) count=4 conv=notrunc
# printf '\x00\x1c\x89\x87' | dd of=../tmp/u-boot-dtb-new-CSF.imx bs=1 seek=$((0x18)) count=4 conv=notrunc
# echo "写入CSF指针: CSF_BYTES = $CSF_BYTES"

# 4.2 change Boot_data->start,  Boot_data->length
# boot data can,t modify, or uboot can not boot up 
# BOOT_DATA_START=$RAM_AUTH_AREA_START
# BOOT_DATA_START_BYTES=$(printf "%08x" $BOOT_DATA_START | sed 's/\(..\)\(..\)\(..\)\(..\)/\\x\4\\x\3\\x\2\\x\1/')
# printf "$BOOT_DATA_START_BYTES" | dd of=../tmp/u-boot-dtb-new-CSF.imx bs=1 seek=$((0x20)) count=4 conv=notrunc

# BOOT_DATA_LENGTH=$IMG_SIGN_AREA_SIZE
# BOOT_DATA_LENGTH_BYTES=$(printf "%08x" $BOOT_DATA_LENGTH | sed 's/\(..\)\(..\)\(..\)\(..\)/\\x\4\\x\3\\x\2\\x\1/')
# printf "$BOOT_DATA_LENGTH_BYTES" | dd of=../tmp/u-boot-dtb-new-CSF.imx bs=1 seek=$((0x24)) count=4 conv=notrunc
# echo "Boot data start: $BOOT_DATA_START_BYTES, length: $BOOT_DATA_LENGTH_BYTES"

# 5. 合成最终签名镜像
cat "../tmp/u-boot-dtb.imx" "../tmp/csf_uboot.bin" > "../tmp/u-boot-signed.imx"
cat "../tmp/u-boot-dtb-new-CSF.imx" "../tmp/csf_uboot.bin" > "../tmp/u-boot-dtb-new-CSF-signed.imx"
# cat "$IMAGE" "${IMAGE}-csf.bin" > "${IMAGE}-signed"

echo "签名完成"

IMG_SIZE=$(wc -c < "$IMAGE")
IMG_SIZE_HEX=$(printf "0x%x" $IMG_SIZE)

echo "$IMAGE: IMG_SIZE = $IMG_SIZE, IMG_SIZE_HEX = $IMG_SIZE_HEX"

IMG_SIZE_new=$(wc -c < "../tmp/u-boot-signed.imx")
IMG_SIZE_HEX_new=$(printf "0x%x" $IMG_SIZE_new)

echo "../tmp/u-boot-signed.imx: IMG_SIZE_new = $IMG_SIZE_new, IMG_SIZE_HEX_new = $IMG_SIZE_HEX_new"

echo "Convert u-boot-dtb-new-CSF-signed.imx to u-boot-dtb-new-CSF-signed.hex"
hexdump -C ../tmp/u-boot-dtb-new-CSF-signed.imx > ../tmp/u-boot-dtb-new-CSF-signed.hex

echo "copy csf.bin from signed image"
dd if=../tmp/u-boot-dtb-new-CSF-signed.imx of=../tmp/csf_cat.bin bs=1 skip=$IMG_SIZE
hexdump ../tmp/csf_cat.bin > ../tmp/csf_cat.hex


# 5. - Flash signed U-Boot binary:

#   sudo dd if=u-boot-signed.imx of=/dev/sd<x> bs=1K seek=1 && sync

FLUSH_IMAGE="../tmp/u-boot-signed.imx"


../para-script/para-download-sd.sh $FLUSH_IMAGE