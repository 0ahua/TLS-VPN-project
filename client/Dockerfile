# 使用轻量级基础镜像
# FROM debian:bullseye-slim
# FROM docker.m.daocloud.io/library/debian:bullseye-slim
FROM debian:bookworm
# 安装必要的系统工具
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    iptables iproute2 bash curl tcpdump iperf3 coreutils ca-certificates iputils-ping net-tools dnsutils telnet traceroute && \
    ln -sf /bin/bash /bin/sh && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 拷贝已经编译好的二进制文件
COPY client/main /app/client

# 拷贝服务端证书用于验证 TLS 连接
COPY ../certs/server.crt /app/certs/server.crt
COPY certs/server.crt /usr/local/share/ca-certificates/server.crt
RUN update-ca-certificates

# 复制项目其余文件
COPY client/ .

# 设置默认命令（可通过 docker-compose 覆盖）
CMD ["/app/client"]





# FROM ghcr.io/cloudflare/cloudflare-go:1.20-pq


# 安装必要的工具（包括更新 CA 证书需要的工具）
# RUN apk update && apk add --no-cache iproute2 bash curl tcpdump ca-certificates iperf3 coreutils bc

# 设置工作目录
# WORKDIR /app

# 先复制 go.mod 和 go.sum 文件，利用 Docker 缓存加速依赖下载
# COPY client/go.mod client/go.sum ./
# RUN go mod tidy

# 复制项目其余文件
# COPY client/ .

# 信任 server.crt 自签名证书（从挂载路径复制）
# 注意：/app/certs/server.crt 会通过 docker-compose.yml 中的 volume 挂载进来
# COPY certs/server.crt /usr/local/share/ca-certificates/server.crt
# RUN update-ca-certificates

# 构建可执行文件
# RUN go build -o main client.go

# 设置构建好的可执行文件为可执行权限
# RUN chmod +x ./main

# 启动命令
# CMD ["./main"]


