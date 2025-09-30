#!/bin/bash
# filepath: para-script/extract_srk_hash.sh
# 用法: ./extract_srk_hash.sh u-boot.imx-ivt_signed

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <signed_image>"
    exit 1
fi

INPUT_FILE=$1

if [ ! -f "$INPUT_FILE" ]; then
    echo "错误：文件 $INPUT_FILE 不存在！"
    exit 1
fi

# 常量定义
IVT_OFFSET=0x0
CSF_POINTER_OFFSET=0x18
IMAGE_BASE_ADDRESS=0x87800000

# 1. 提取CSF指针
CSF_POINTER_HEX=$(od -An -tx4 -N 4 -j $((IVT_OFFSET + CSF_POINTER_OFFSET)) "$INPUT_FILE" | tr -d ' ')
CSF_POINTER=$((16#$CSF_POINTER_HEX))
echo "CSF指针（内存地址）：0x$(printf "%08x" $CSF_POINTER)"

# 2. 计算CSF在文件中的偏移量
CSF_OFFSET=$((CSF_POINTER - IMAGE_BASE_ADDRESS))
echo "CSF在文件中的偏移量：0x$(printf "%08x" $CSF_OFFSET)"

FILE_SIZE=$(stat -c %s "$INPUT_FILE")
if [ "$CSF_OFFSET" -ge "$FILE_SIZE" ]; then
    echo "错误：CSF偏移量超出文件范围！"
    exit 1
fi

# 3. 在CSF区域查找SRK表魔数（0x87），模拟BootROM只查找CSF区前512字节
SRK_MAGIC=135  # 0x87
SRK_SEARCH_LEN=512
SRK_MAGIC_OFFSET=-1

for ((i=0; i<$SRK_SEARCH_LEN; i++)); do
    BYTE=$(od -An -tx1 -N 1 -j $(($CSF_OFFSET + $i)) "$INPUT_FILE" | tr -d ' ')
    BYTE=$((16#$BYTE))
    if [ "$BYTE" -eq "$SRK_MAGIC" ]; then
        SRK_MAGIC_OFFSET=$(($CSF_OFFSET + $i))
        break
    fi
done

if [ "$SRK_MAGIC_OFFSET" -eq -1 ]; then
    echo "错误：未在CSF区前$SRK_SEARCH_LEN 字节内找到SRK表魔数（0x87）"
    exit 1
fi
echo "SRK表魔数找到，文件偏移：0x$(printf "%08x" $SRK_MAGIC_OFFSET)"

# 4. 提取SRK表长度
SRK_LENGTH_OFFSET=$((SRK_MAGIC_OFFSET + 1))
SRK_LENGTH_HEX=$(od -An -tx2 -N 2 -j $SRK_LENGTH_OFFSET "$INPUT_FILE" | tr -d ' ')
SRK_LENGTH=$((16#$SRK_LENGTH_HEX))
# SRK_LENGTH=1024
echo "SRK表长度：$SRK_LENGTH 字节"

# 5. 提取SRK表内容
SRK_TABLE_OFFSET=$((SRK_MAGIC_OFFSET + 3))
dd if="$INPUT_FILE" of=srk_table.bin bs=1 skip=$SRK_TABLE_OFFSET count=$SRK_LENGTH status=none
echo "SRK表已提取到 srk_table.bin"

# 6. 计算SRK表HASH（即SRK_HASH，BootROM就是这样做的）
SRK_HASH=$(sha256sum srk_table.bin | awk '{print $1}')
echo "SRK表HASH（SRK_HASH）: $SRK_HASH"

echo "7. 验证SRK表内容与签名用SRK_1_2_3_4_table.bin内容是否一致"
# 7. 验证SRK表内容与签名用SRK_1_2_3_4_table.bin内容是否一致
CRT_DIR="$(dirname "$0")/../CST/crts"
SRK_TABLE_FILE="$CRT_DIR/SRK_1_2_3_4_table.bin"
SRK_FUSE_FILE="$CRT_DIR/SRK_1_2_3_4_fuse.bin"
echo "SRK_TABLE_FILE: $SRK_TABLE_FILE"
if [ -f "$SRK_TABLE_FILE" ]; then
    cmp -s srk_table.bin "$SRK_TABLE_FILE"
    
    if [ $? -eq 0 ]; then
        echo "✓ 镜像CSF区SRK表内容与签名用SRK_1_2_3_4_table.bin完全一致"
    else
        echo "✗ 镜像CSF区SRK表内容与签名用SRK_1_2_3_4_table.bin不一致"
    fi
else
    echo "警告：未找到 $SRK_TABLE_FILE，无法比对"
fi

echo "8. 验证SRK_HASH与eFuse烧录的SRK_1_2_3_4_fuse.bin内容是否一致"
# 8. 验证SRK_HASH与eFuse烧录的SRK_1_2_3_4_fuse.bin内容是否一致
if [ -f "$SRK_FUSE_FILE" ]; then
    FUSE_HASH=$(xxd -p "$SRK_FUSE_FILE" | tr -d '\n' | xxd -r -p | sha256sum | awk '{print $1}')
    echo "eFuse中SRK_HASH: $FUSE_HASH"
    if [ "$SRK_HASH" == "$FUSE_HASH" ]; then
        echo "✓ SRK表HASH与eFuse中SRK_HASH一致，匹配！"
    else
        echo "✗ SRK表HASH与eFuse中SRK_HASH不一致，不匹配！"
    fi
else
    echo "警告：未找到 $SRK_FUSE_FILE，无法比对efuse"
fi

# 9. 提取公钥并计算HASH（假设4个RSA2048公钥，每个256字节）
PUBLIC_KEY_LEN=256
PUBLIC_KEY_CNT=4
echo "SRK表内各公钥HASH如下："
for ((i=0; i<$PUBLIC_KEY_CNT; i++)); do
    KEY_OFFSET=$((i * PUBLIC_KEY_LEN))
    dd if=srk_table.bin of=pubkey_$i.bin bs=1 skip=$KEY_OFFSET count=$PUBLIC_KEY_LEN status=none
    HASH=$(sha256sum pubkey_$i.bin | awk '{print $1}')
    echo "公钥 $i HASH: $HASH"
done

echo "全部SRK公钥HASH计算完成。"

# 清理临时文件
rm -f pubkey_*.bin #srk_table.bin