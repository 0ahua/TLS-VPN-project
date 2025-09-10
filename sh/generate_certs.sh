#!/bin/bash
# 创建 certs 目录
mkdir -p certs
cd certs

# 删除旧的证书文件（如果存在）
rm -f server.key server.crt

# 生成 ECC 私钥（prime256v1 更高效）
openssl ecparam -genkey -name prime256v1 -out server.key

# 生成自签名证书，CN 改为 vpn-server（与 Docker Compose 中的服务名一致）
openssl req -new -x509 -key server.key -out server.crt -days 365 \
-subj "/C=CN/ST=State/L=City/O=Organization/OU=Unit/CN=vpn-server"

echo "✅ 证书生成完成！文件已保存在 certs/ 目录下（CN=vpn-server）"
cd ..
