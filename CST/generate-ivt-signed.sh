#!/bin/bash
# cd d:/Ubuntu/shared-room/git-respo/NXP/Layerscape_Software_Development_Kit(LSDK)/NXP_u-boot/CST

# 1. 生成带IVT的镜像
./gen_imx-ivt.sh ../tmp/u-boot-imx6ull-para.imx 0x87800000

# 2. 生成CSF文件
IMG_SIZE=$(stat -c %s ../tmp/u-boot-imx6ull-para.imx-ivt)
IMG_SIZE_HEX=$(printf "0x%x" $IMG_SIZE)
cat > ../tmp/u-boot-imx6ull-para.imx-ivt.csf <<EOF
[Header]
Version = 4.2
Hash Algorithm = sha256
Engine = SW
Engine Configuration = 0
Certificate Format = X509
Signature Format = CMS

[Install SRK]
File = "./crts/SRK_1_2_3_4_table.bin"
Source index = 0

[Install CSFK]
File = "./crts/CSF1_1_sha256_2048_65537_v3_usr_crt.pem"

[Authenticate CSF]

[Install Key]
Verification index = 0
Target index = 2
File = "./crts/IMG1_1_sha256_2048_65537_v3_usr_crt.pem"

[Authenticate Data]
Verification index = 2
Blocks = 0x87800000 0x0000 $IMG_SIZE_HEX "../tmp/u-boot-imx6ull-para.imx-ivt"
EOF

# 3. 生成CSF二进制
./linux64/bin/cst -i ../tmp/u-boot-imx6ull-para.imx-ivt.csf -o ../tmp/u-boot-imx6ull-para.imx-ivt_csf.bin

# 4. 合成签名镜像
cat ../tmp/u-boot-imx6ull-para.imx-ivt ../tmp/u-boot-imx6ull-para.imx-ivt_csf.bin > ../tmp/u-boot.imx-ivt_signed

echo "签名完成，文件已生成：../tmp/u-boot-new.imx-ivt_signed"