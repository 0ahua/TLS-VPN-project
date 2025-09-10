# TLS-VPN-project

一个基于TLS 1.3的轻量级VPN解决方案，支持常规密钥交换和后量子密钥交换（PQC），通过Docker容器化部署，提供安全的网络隧道服务。

## 项目概述

本项目实现了一个基于TLS协议的VPN（虚拟专用网络），通过TUN虚拟网络设备构建加密隧道，使客户端与服务器之间的网络通信经过加密保护。与传统VPN相比，该方案具有以下优势：

- **简化部署**：通过Docker容器化消除环境依赖问题
- **现代加密**：基于TLS 1.3实现，提供强加密和前向 secrecy
- **量子抗性**：可选启用后量子密钥交换，抵御未来量子计算威胁
- **轻量高效**：Go语言实现，资源占用低，适合嵌入式和云环境

项目支持两种密钥交换模式：
- 常规模式：使用X25519椭圆曲线密钥交换（成熟稳定，RFC 7748）
- 后量子模式：使用X25519+Kyber768混合密钥交换（抗量子计算攻击，NIST PQC标准候选）

## 核心功能

| 功能 | 描述 |
|------|------|
| 🔒 加密隧道 | 基于TLS 1.3的端到端加密，支持AEAD加密算法（AES-GCM、ChaCha20-Poly1305） |
| 🌐 三层转发 | 通过TUN设备实现IP层数据包转发，支持任意网络协议（TCP/UDP/ICMP等） |
| 🔑 密钥交换 | 支持传统椭圆曲线和后量子密码学混合密钥交换 |
| 🐳 容器部署 | 服务器和客户端均容器化，支持一键启动和跨平台运行 |
| 📊 性能测试 | 内置握手延迟、吞吐量和资源占用测试工具 |
| 🔍 诊断工具 | 提供网络状态检测和数据包捕获功能，便于问题排查 |

## 快速开始

### 环境要求

- **操作系统**：Linux（推荐Ubuntu 20.04+、CentOS 8+）
- **依赖工具**：
  - Docker ≥ 20.10.0
  - Docker Compose ≥ v2.0.0
  - Git
  - 内核模块：`tun`（用于创建虚拟网络接口）
- **权限要求**：需要root或sudo权限（用于网络配置和容器特权模式）

### 部署步骤

1. **准备环境**

   ```bash
   # 检查并加载tun模块
   sudo modprobe tun
   lsmod | grep tun  # 确认模块已加载
   
   # 安装Docker和Docker Compose（如未安装）
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   sudo usermod -aG docker $USER  # 允许当前用户运行docker命令（需重新登录）
   ```

2. **获取代码**

   ```bash
   git clone https://github.com/0ahua/TLS-VPN-project.git
   cd TLS-VPN-project
   ```

3. **生成证书（自签名）**

   项目已包含测试用自签名证书（位于`certs/`目录），建议删除后重新生成：

   ```bash
   # 生成ECC证书（prime256v1曲线）
   sh/sh/generate_certs.sh
   
   # 查看生成的证书信息
   openssl x509 -in certs/server.crt -text -noout
   ```

4. **启动服务**

   ```bash
   # 启动服务器和客户端（默认启用PQC模式）
   docker-compose up -d
   
   # 查看服务状态
   docker-compose ps
   
   # 预期输出：
   #   Name                Command               State           Ports         
   # -------------------------------------------------------------------------
   # vpnclient   /app/client --server vpnserver ...   Up                        
   # vpnserver   /app/server --pqc                    Up      0.0.0.0:4433->4433/tcp
   ```

5. **验证连接**

   ```bash
   # 检查VPN状态报告
   sh/sh/vpn_status_report.sh
   
   # 测试服务器与客户端之间的连通性
   docker exec -it vpnserver ping -c 3 10.0.0.2  # 服务器ping客户端
   docker exec -it vpnclient ping -c 3 10.0.0.1  # 客户端ping服务器
   ```

6. **停止服务**

   ```bash
   # 停止并移除容器
   docker-compose down
   
   # 如需清理数据卷（可选）
   docker volume prune -f
   ```

## 高级配置

### 配置参数说明

服务器和客户端支持以下启动参数：

| 参数 | 适用对象 | 描述 |
|------|----------|------|
| `--server` | 客户端 | 指定服务器地址（默认：vpnserver） |
| `--port` | 两者 | 指定服务端口（默认：4433） |
| `--pqc` | 两者 | 启用后量子密钥交换模式 |
| `--handshake-only` | 客户端 | 仅进行TLS握手测试，不建立隧道 |
| `--tun-ip` | 两者 | 指定TUN设备IP地址（服务器默认：10.0.0.1，客户端默认：10.0.0.2） |
| `--cert` | 两者 | 证书文件路径（默认：/certs/server.crt） |
| `--key` | 服务器 | 私钥文件路径（默认：/certs/server.key） |

### 自定义部署示例

1. **修改端口和禁用PQC模式**

   编辑`docker-compose.yml`：

   ```yaml
   services:
     vpnserver:
       # ... 其他配置 ...
       command: /app/server --port 8443  # 禁用--pqc参数，使用常规模式，端口改为8443
       ports:
         - "8443:8443"  # 同步修改端口映射
     
     vpnclient:
       # ... 其他配置 ...
       command: /app/client --server vpnserver --port 8443  # 匹配服务器端口
   ```

2. **配置客户端访问公网**

   服务器默认已配置NAT规则允许客户端访问公网，可通过以下方式验证：

   ```bash
   # 在客户端容器中访问外部网站
   docker exec -it vpnclient curl -s https://icanhazip.com  # 应返回服务器公网IP
   ```

3. **多客户端配置**

   如需支持多个客户端，需为每个客户端分配唯一IP并修改路由配置：

   ```bash
   # 示例：添加第二个客户端
   docker run -d --name vpnclient2 --privileged \
     --network vpn-network \
     -v $(pwd)/certs:/certs \
     tls-vpn-client \
     /app/client --server vpnserver --tun-ip 10.0.0.3
   ```

## 测试工具使用

### 1. TLS握手测试
# 测试常规模式握手耗时（默认5次）
sh/sh/test_handshake.sh

# 测试PQC模式握手耗时（10次）
sh/sh/test_handshake.sh 10 pqc

# 示例输出：
# 握手测试（模式：常规，次数：5）
# 平均耗时：12.3ms，最小：9.8ms，最大：15.6ms
### 2. 吞吐量测试
# 运行吞吐量测试（默认30秒）
sh/sh/test_throughput.sh

# 测试结果将显示：
# - 带宽（发送/接收）
# - 抖动（Jitter）
# - 丢包率（Loss）
### 3. 资源占用测试
# 监控10秒内的资源使用情况
sh/sh/test_resource.sh 10

# 输出包含：
# - CPU使用率（用户态/系统态）
# - 内存占用（RSS）
# - 网络I/O
### 4. 数据包捕获分析
# 捕获TLS握手过程（持续30秒）
sh/sh/tls_capture.sh 30

# 捕获TUN隧道流量（持续60秒）
sh/sh/tun0_capture.sh 60

# 生成的.pcap文件可使用Wireshark打开分析
## 故障排除

### 常见问题及解决方法

1. **容器启动失败**

   ```bash
   # 查看详细日志
   docker-compose logs vpnserver
   
   # 常见原因：
   # - tun模块未加载：sudo modprobe tun
   # - 端口被占用：修改docker-compose.yml中的端口映射
   # - 证书文件缺失：重新生成证书sh/sh/generate_certs.sh
   ```

2. **客户端无法连接服务器**

   ```bash
   # 检查网络连通性
   docker exec -it vpnclient ping -c 3 vpnserver
   
   # 检查防火墙规则
   sudo ufw status  # 如启用防火墙，确保4433端口开放
   ```

3. **TUN设备创建失败**

   ```bash
   # 确认宿主机支持TUN
   ls -la /dev/net/tun
   
   # 如显示"No such file or directory"，需创建：
   sudo mkdir -p /dev/net
   sudo mknod /dev/net/tun c 10 200
   sudo chmod 600 /dev/net/tun
   ```

4. **性能问题排查**

   ```bash
   # 检查CPU占用过高的进程
   docker stats
   
   # 分析网络瓶颈
   docker exec -it vpnserver iftop
   ```
## 注意事项

### 安全性考量

- **证书管理**：
  - 测试环境使用自签名证书，仅用于个人小项目实验
  - 定期轮换证书（建议90天），使用`sh/generate_certs.sh`脚本更新
  - 私钥文件`server.key`应设置严格权限（`chmod 600`），避免泄露

- **后量子模式**：
  - Kyber768算法目前处于NIST PQC标准化进程中，可能存在安全风险
  - 本实验仅在研究场景使用PQC模式

- **网络安全**：
  - 限制VPN服务器端口（默认4433）的访问来源，仅允许信任的IP
  - 定期更新依赖库，修复可能的安全漏洞（`go get -u`）




