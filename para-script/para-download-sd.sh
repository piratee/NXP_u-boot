#!/bin/bash

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <u-boot.imx>"
    exit 1
fi

# 定义变量
DEVICE="/dev/sdb"
# IMAGE="tmp/u-boot-imx6ull-para.imx"
IMAGE=$1

# 检查设备是否存在
if [ -e "$DEVICE" ]; then
    echo "检测到设备 $DEVICE"
    
    # 检查镜像文件是否存在
    if [ ! -f "$IMAGE" ]; then
        echo "错误：镜像文件 $IMAGE 不存在"
        exit 1
    fi
    
    echo "警告：即将烧录 u-boot 到 $DEVICE"
    echo "此操作将会清空设备上的所有数据！"
    read -p "确定要继续吗？(输入 'yes' 继续): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "操作已取消"
        exit 1
    fi
    
    # 确保设备未被挂载
    # echo "检查设备是否被挂载..."
    # if mount | grep -q "$DEVICE"; then
    #     echo "设备已挂载，正在尝试卸载..."
    #     sudo umount ${DEVICE}* 2>/dev/null
    #     if [ $? -ne 0 ]; then
    #         echo "错误：无法卸载设备"
    #         exit 1
    #     fi
    # fi
    
    # 烧录镜像
    echo "正在烧录 u-boot 到 $DEVICE..."
    sudo dd if="$IMAGE" of="$DEVICE" bs=1k seek=1 conv=fsync
    
    if [ $? -eq 0 ]; then
        echo "烧录完成！"
         # 同步缓存，确保所有数据已写入
        echo "同步数据中..."
        sync
        
        # 弹出设备
        echo "正在弹出设备..."
        sudo eject "$DEVICE"
        
        if [ $? -eq 0 ]; then
            echo "设备已安全弹出，可以移除SD卡"
        else
            echo "警告：设备弹出失败，但数据已写入完成"
            echo "您可以手动移除SD卡"
        fi
    else
        echo "错误：烧录失败"
        exit 1
    fi
    
else
    echo "错误：设备 $DEVICE 不存在"
    exit 1
fi

exit 0