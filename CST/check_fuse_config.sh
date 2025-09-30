#!/bin/bash
# filepath: check_fuse_config.sh
# 用法: ./check_fuse_config.sh <srk_fuse_file> <fuse_device>

set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <srk_fuse_file> <fuse_device>"
    echo "  srk_fuse_file: Path to the SRK fuse file (e.g., SRK_1_2_3_4_fuse.bin)"
    echo "  fuse_device: Path to the fuse device (e.g., /dev/mtd0 or /sys/class/misc/fuse)"
    exit 1
fi

SRK_FUSE_FILE=$1
FUSE_DEVICE=$2

# 检查文件是否存在
if [ ! -f "$SRK_FUSE_FILE" ]; then
    echo "Error: SRK fuse file $SRK_FUSE_FILE not found!"
    exit 1
fi

# 检查熔丝设备是否存在
if [ ! -e "$FUSE_DEVICE" ]; then
    echo "Error: Fuse device $FUSE_DEVICE not found!"
    exit 1
fi

SCRIPT_DIR=$(dirname "$0")
FUSEPROG_TOOL="${SCRIPT_DIR}/linux64/bin/fuseprog"

# 检查fuseprog工具是否存在
if [ ! -f "$FUSEPROG_TOOL" ]; then
    echo "Error: fuseprog tool $FUSEPROG_TOOL not found!"
    echo "Please ensure the CST toolchain is properly installed."
    exit 1
fi

echo "=========================================="
echo "Fuse Configuration Check"
echo "=========================================="
echo "SRK Fuse File: $SRK_FUSE_FILE"
echo "Fuse Device: $FUSE_DEVICE"
echo "=========================================="

# 创建临时文件存储读取的熔丝值
FUSE_READ_FILE=$(mktemp)
trap "rm -f $FUSE_READ_FILE" EXIT

# 根据熔丝设备类型选择读取方法
if [[ "$FUSE_DEVICE" == *"/dev/mtd"* ]]; then
    # MTD设备
    echo "Reading fuses from MTD device..."
    if ! "$FUSEPROG_TOOL" -q -r 0 8 "$FUSE_DEVICE" > "$FUSE_READ_FILE"; then
        echo "✗ ERROR: Failed to read fuses from MTD device $FUSE_DEVICE!"
        exit 1
    fi
elif [[ "$FUSE_DEVICE" == *"/sys/class/misc/fuse"* ]]; then
    # 通过sysfs接口读取
    echo "Reading fuses from sysfs interface..."
    if ! dd if="$FUSE_DEVICE" of="$FUSE_READ_FILE" bs=1 count=8 2>/dev/null; then
        echo "✗ ERROR: Failed to read fuses from sysfs device $FUSE_DEVICE!"
        exit 1
    fi
else
    echo "✗ ERROR: Unsupported fuse device type: $FUSE_DEVICE"
    echo "Supported types: /dev/mtd* or /sys/class/misc/fuse*"
    exit 1
fi

echo "Successfully read fuse values from device."

# 显示SRK熔丝文件内容
echo ""
echo "SRK Fuse File Content:"
echo "------------------------------------------"
hexdump -C "$SRK_FUSE_FILE"

# 显示设备熔丝值
echo ""
echo "Device Fuse Values:"
echo "------------------------------------------"
hexdump -C "$FUSE_READ_FILE"

# 比较读取的熔丝值与SRK熔丝文件
echo ""
echo "Comparing fuse values..."
echo "------------------------------------------"
if cmp -s "$FUSE_READ_FILE" "$SRK_FUSE_FILE"; then
    echo "✓ SUCCESS: Device fuse configuration matches the SRK fuse file!"
    exit 0
else
    echo "✗ ERROR: Device fuse configuration does not match the SRK fuse file!"
    echo ""
    echo "Differences:"
    echo "------------------------------------------"
    diff -y <(hexdump -C "$SRK_FUSE_FILE") <(hexdump -C "$FUSE_READ_FILE") || true
    exit 1
fi
