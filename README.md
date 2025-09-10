# TLS-VPN-project

一个基于TLS 1.3的轻量级VPN解决方案，支持常规密钥交换和后量子密钥交换（PQC），通过Docker容器化部署，提供安全的网络隧道服务。

## 项目概述

本项目实现了一个基于TLS协议的VPN（虚拟专用网络），通过TUN虚拟网络设备构建加密隧道，使客户端与服务器之间的网络通信经过加密保护。项目支持两种密钥交换模式：
- 常规模式：使用X25519椭圆曲线密钥交换（成熟稳定）
- 后量子模式：使用X25519+Kyber768混合密钥交换（抗量子计算攻击）

项目采用Go语言开发，通过Docker容器化部署，简化了环境配置和跨平台使用流程。

## 项目结构
```bash
TLS-VPN-project/
├── server/           # 服务器端代码
├── client/           # 客户端代码
├── certs/            # 证书文件
├── sh/               # 脚本文件（测试、部署、工具）
│   ├── generate_certs.sh    # 生成证书
│   ├── test_handshake.sh    # 握手测试
│   ├── vpn_status_report.sh # 状态检测
│   └── ...
├── docker-compose.yml       # 容器部署配置
└── README.md                # 项目说明
```

## 核心功能

- ✅ 基于TLS 1.3协议的加密隧道，确保数据传输安全
- ✅ 支持后量子密码学（PQC）密钥交换，增强未来安全性
- ✅ 使用TUN设备实现三层（IP层）VPN，转发完整IP数据包
- ✅ 容器化部署，一键启动服务器和客户端
- ✅ 内置性能测试和状态检测工具
- ✅ 支持自定义证书和网络配置

## 快速开始

### 环境要求

- Linux系统（需支持TUN设备）
- Docker ≥ 20.10 和 Docker Compose ≥ v2
- Git
- 管理员权限（用于创建TUN设备和网络配置）

### 部署步骤

1. **克隆仓库**
   ```bash
   git clone https://github.com/0ahua/TLS-VPN-project.git
   cd TLS-VPN-project
   ```

2. **生成证书（可选）**
   项目已包含测试用自签名证书，建议删除后重新生成：
   ```bash
   sh/sh/generate_certs.sh
   ```

3. **启动服务**
   ```bash
   # 启动服务器和客户端（默认启用PQC模式）
   docker-compose up -d
   
   # 查看服务状态
   docker-compose ps
   ```

4. **验证连接**
   ```bash
   # 检查VPN状态报告
   sh/sh/vpn_status_report.sh
   
   # 查看服务器日志
   docker-compose logs vpnserver
   
   # 查看客户端日志
   docker-compose logs vpnclient
   ```

5. **停止服务**
   ```bash
   docker-compose down
   ```

## 测试工具

项目提供了一系列脚本用于测试VPN性能和功能：

### 1. TLS握手测试# 测试握手耗时（默认5次，可通过参数指定次数）
sh/sh/test_handshake.sh [次数]
### 2. 吞吐量测试# 需先安装iperf3
sh/sh/test_throughput.sh
### 3. 资源占用测试# 监控CPU和内存使用情况
sh/sh/test_resource.sh
### 4. 数据包捕获# 捕获TLS握手数据包（保存为tls_handshake.pcap）
sh/sh/tls_capture.sh

# 捕获TUN隧道数据包（保存为tun0_traffic.pcap）
sh/sh/tun0_capture.sh
## 配置说明

### 核心配置项

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| 服务器端口 | 4433 | 可在`docker-compose.yml`中修改 |
| 服务器TUN IP | 10.0.0.1 | 服务器虚拟网卡IP |
| 客户端TUN IP | 10.0.0.2 | 客户端虚拟网卡IP |
| PQC模式 | 启用 | 可在`docker-compose.yml`中通过`--pqc`参数控制 |

### 自定义配置

1. **修改端口和IP**：
   需同步修改`docker-compose.yml`中的端口映射和服务器/客户端启动参数。

2. **禁用PQC模式**：
   在`docker-compose.yml`中移除`--pqc`参数，使用常规X25519密钥交换。

3. **网络权限控制**：
   可修改`server/run.sh`中的`iptables`规则限制客户端访问权限。

## 注意事项

1. **安全性**：
   - 测试用证书为自签名证书，生产环境需使用可信CA签发的证书
   - 私钥文件`certs/server.key`需严格保密，避免泄露
   - PQC模式（Kyber768）处于标准化阶段，建议仅用于研究场景

2. **环境限制**：
   - 仅支持Linux系统（依赖TUN模块）
   - 宿主机需加载TUN模块：`modprobe tun`
   - 容器需要`--privileged`权限以创建TUN设备

3. **合规性**：
   - 使用本项目需遵守当地法律法规
   - 禁止用于非法活动或绕过网络监管


