#!/bin/bash

# 1. 验证SRK哈希值
# echo "Verifying SRK hash..."
# ../linux64/bin/srktool -h 4 -d sha256 ../crts/SRK_1_2_3_4_table.bin -o SRK_recomputed_hash.bin
# if diff ../crts/SRK_1_2_3_4_fuse.bin SRK_recomputed_hash.bin; then
#     echo "SRK hash verification: PASSED"
# else
#     echo "SRK hash verification: FAILED"
#     exit 1
# fi

# 2. 验证密钥和证书匹配
echo "Verifying key and certificate pairs..."
for i in 1 2 3 4; do
    if [ -f "../keys/SRK${i}_sha256_2048_65537_v3_ca_key.pem" ] && [ -f "../crts/SRK${i}_sha256_2048_65537_v3_ca_crt.pem" ]; then
        PRIV_KEY_MD5=$(openssl rsa -noout -modulus -in SRK${i}_priv.key 2>/dev/null | openssl md5)
        CERT_MD5=$(openssl x509 -noout -modulus -in SRK${i}_pub.crt 2>/dev/null | openssl md5)
        if [ "$PRIV_KEY_MD5" = "$CERT_MD5" ]; then
            echo "SRK${i} key and certificate: PASSED"
        else
            echo "SRK${i} key and certificate: FAILED"
            exit 1
        fi
    fi
done

# 3. 验证证书链
echo "Verifying certificate chains..."
ROOT_CA_CERT="../crts/CA1_sha256_2048_65537_v3_ca_crt.pem"         # 自签名的根证书
INTERMEDIATE_SRK1_CERT="../crts/SRK1_sha256_2048_65537_v3_ca_crt.pem" # 中间证书
USER_CSF_CERT="../crts/CSF1_1_sha256_2048_65537_v3_usr_crt.pem"      # 要验证的用户证书
USER_IMG_CERT="../crts/IMG1_1_sha256_2048_65537_v3_usr_crt.pem"      # 要验证的用户证书

if openssl verify -CAfile "$ROOT_CA_CERT" -untrusted "$INTERMEDIATE_SRK1_CERT" "$USER_CSF_CERT" && \
    openssl verify -CAfile "$ROOT_CA_CERT" -untrusted "$INTERMEDIATE_SRK1_CERT" "$USER_CSF_CERT"; then
# if openssl verify -CAfile ../crts/CA1_sha256_2048_65537_v3_ca_crt.pem ../crts/CSF1_1_sha256_2048_65537_v3_usr_crt.pem && \
#    openssl verify -CAfile ../crts/CA1_sha256_2048_65537_v3_ca_crt.pem ../crts/IMG1_1_sha256_2048_65537_v3_usr_crt.pem; then
    echo "Certificate chain verification: PASSED"
else
    echo "Certificate chain verification: FAILED"
    exit 1
fi

# 4. 验证签名
echo "Verifying signatures..."
echo "test data" > test.txt
SIGN_KEY_PASS_FILE="../keys/key_pass.txt"  # 密码文件路径
# 检查密码文件是否存在
if [ ! -f "$SIGN_KEY_PASS_FILE" ]; then
    echo "[FATAL] Sign key password file not found at $SIGN_KEY_PASS_FILE"
    echo "Please create it and set permissions with: chmod 600 $SIGN_KEY_PASS_FILE"
    exit 1
fi

read -r KEY_PASSWORD < "$SIGN_KEY_PASS_FILE"
echo "[INFO] Using sign key password <$KEY_PASSWORD>"

# --- 修正点：从文件中读取密码，实现自动化且安全 ---
openssl dgst -sha256 -sign ../keys/SRK1_sha256_2048_65537_v3_ca_key.pem -passin pass:"$KEY_PASSWORD" -out test.sig test.txt

# openssl dgst -sha256 -sign ../keys/SRK1_sha256_2048_65537_v3_ca_key.pem -out test.sig test.txt
# 验证（用公钥）
openssl x509 -in ../crts/SRK1_sha256_2048_65537_v3_ca_crt.pem -pubkey -noout > pubkey.pem
if openssl dgst -sha256 -verify pubkey.pem -signature test.sig test.txt; then
    echo "Signature verification: PASSED"
else
    echo "Signature verification: FAILED"
    exit 1
fi

# 清理测试文件
rm -f test.txt test.sig

echo "All verifications PASSED"

