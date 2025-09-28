#!/bin/bash
# filepath: verify_hab_signature.sh
# 用法: ./verify_hab_signature.sh <signed_image> <crt_dir>

set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <signed_image> <crt_dir>"
    exit 1
fi

SIGNED_IMAGE=$1
CRT_DIR=$2

# 检查文件是否存在
if [ ! -f "$SIGNED_IMAGE" ]; then
    echo "Error: Signed image $SIGNED_IMAGE not found!"
    exit 1
fi

if [ ! -d "$CRT_DIR" ]; then
    echo "Error: Certificate directory $CRT_DIR not found!"
    exit 1
fi

SRK_TABLE="$CRT_DIR/SRK_1_2_3_4_table.bin"
SRK_FUSE="$CRT_DIR/SRK_1_2_3_4_fuse.bin"

if [ ! -f "$SRK_TABLE" ]; then
    echo "Error: SRK table file $SRK_TABLE not found!"
    exit 1
fi

if [ ! -f "$SRK_FUSE" ]; then
    echo "Error: SRK fuse file $SRK_FUSE not found!"
    exit 1
fi

SCRIPT_DIR=$(dirname "$0")
CST_TOOL="${SCRIPT_DIR}/linux64/bin/cst"
SRK_TOOL="${SCRIPT_DIR}/linux64/bin/srktool"

# 检查工具是否存在
if [ ! -f "$CST_TOOL" ]; then
    echo "Error: CST tool $CST_TOOL not found!"
    exit 1
fi

if [ ! -f "$SRK_TOOL" ]; then
    echo "Error: SRK tool $SRK_TOOL not found!"
    exit 1
fi

echo "=========================================="
echo "HAB Signature Verification"
echo "=========================================="
echo "Signed Image: $SIGNED_IMAGE"
echo "Certificate Directory: $CRT_DIR"
echo "=========================================="

# 1. 显示IVT内容
echo ""
echo "1. Displaying IVT content:"
echo "------------------------------------------"
hexdump -C -n 32 "$SIGNED_IMAGE" | head -n 2

# 2. 计算并比较SRK表和熔丝文件的哈希值
echo ""
echo "2. Comparing SRK table and fuse file hashes:"
echo "------------------------------------------"
SRK_TABLE_HASH=$(sha256sum "$SRK_TABLE" | cut -d' ' -f1)
SRK_FUSE_HASH=$(sha256sum "$SRK_FUSE" | cut -d' ' -f1)

echo "SRK Table Hash: $SRK_TABLE_HASH"
echo "SRK Fuse Hash:  $SRK_FUSE_HASH"

# 3. 使用srktool验证SRK表和熔丝文件的匹配性
echo ""
echo "3. Verifying SRK table and fuse file with srktool:"
echo "------------------------------------------"
if "$SRK_TOOL" -h 4 sha256 -t "$SRK_TABLE" -e "$SRK_FUSE" -v; then
    echo "✓ SRK table and fuse file verification passed!"
else
    echo "✗ ERROR: SRK table and fuse file verification failed!"
    exit 1
fi


# 4. 检查DCD指针是否已清零
echo ""
echo "54. Checking if DCD pointer is zeroed:"
echo "------------------------------------------"
DCD_PTR=$(xxd -p -s 12 -l 4 "$SIGNED_IMAGE")
if [ "$DCD_PTR" = "00000000" ]; then
    echo "✓ DCD pointer is correctly zeroed!"
else
    echo "✗ ERROR: DCD pointer is not zeroed (value: $DCD_PTR)!"
    exit 1
fi

echo ""
echo "=========================================="
echo "All verifications passed successfully!"
echo "The signed image is valid and matches the SRK table and fuse file."
echo "=========================================="

# 5. should be run ing u-boot
# hab_status

# 6. read SRK Table in u-boot
# read srk hash value in fuse : bank 3, from word 0, 8 word
# fuse read 3 0 8