package main

import (
	"crypto/tls"
	"crypto/x509"
	"flag"
	"io/ioutil"
	"log"
	"os/exec"
	"sync"
	"time"

	"github.com/songgao/water"
)

var handshakeOnly = flag.Bool("handshake-only", false, "只执行 TLS 握手，不启动 VPN")
var pqcEnabled = flag.Bool("pqc", false, "启用后量子密钥交换模式（X25519+Kyber768）")

const (
	MTU         = 1500
	TUN_NAME    = "tun0"
	TUN_IP      = "10.0.0.2"
	TUN_GATEWAY = "10.0.0.1"
	SERVER_ADDR = "vpn-server:443"
)

func main() {
	flag.Parse()

	certPool := x509.NewCertPool()
	serverCert, err := ioutil.ReadFile("/app/certs/server.crt")
	if err != nil {
		log.Fatalf("无法读取服务器证书: %v", err)
	}
	certPool.AppendCertsFromPEM(serverCert)

	// 动态设置 CurvePreferences
	curves := []tls.CurveID{tls.X25519}
	if *pqcEnabled {
		log.Println("🔐 启用 PQC 模式（X25519 + Kyber768）")
		curves = []tls.CurveID{tls.X25519Kyber768Draft00, tls.X25519}
	} else {
		log.Println("🔐 启用 Baseline 模式（仅 X25519）")
	}

	config := &tls.Config{
		RootCAs:            certPool,
		MinVersion:         tls.VersionTLS13,
		InsecureSkipVerify: true,
		CurvePreferences:   curves,
	}

	// 重试 TLS 连接
	var conn *tls.Conn
	for i := 1; i <= 5; i++ {
		log.Printf("尝试连接 VPN Server：%s (第 %d 次)", SERVER_ADDR, i)
		conn, err = tls.Dial("tcp", SERVER_ADDR, config)
		if err == nil {
			break
		}
		log.Printf("连接失败: %v，重试中...", err)
		time.Sleep(2 * time.Second)
	}
	if err != nil {
		log.Fatalf("连接失败: %v", err)
	}
	defer conn.Close()

	log.Printf("✅ 成功建立 TLS 连接，TLS版本: 0x%x", conn.ConnectionState().Version)

	if *handshakeOnly {
		log.Println("🚪 只执行握手测试，程序退出")
		return
	}

	// VPN 流量转发逻辑
	ifce, err := createTunInterface()
	if err != nil {
		log.Fatalf("创建 TUN 接口失败: %v", err)
	}
	setupRouting()

	var wg sync.WaitGroup
	wg.Add(2)

	go tunToVPN(ifce, conn, &wg)
	go vpnToTun(ifce, conn, &wg)

	wg.Wait()
	log.Println("🔌 VPN 客户端已关闭")
}

func createTunInterface() (*water.Interface, error) {
	config := water.Config{DeviceType: water.TUN}
	config.Name = TUN_NAME
	ifce, err := water.New(config)
	if err != nil {
		return nil, err
	}

	exec.Command("ip", "addr", "add", TUN_IP+"/24", "dev", TUN_NAME).Run()
	exec.Command("ip", "link", "set", TUN_NAME, "up").Run()

	log.Printf("TUN 接口启动完成: %s", ifce.Name())
	return ifce, nil
}

func setupRouting() {
	exec.Command("ip", "route", "add", "10.0.0.0/24", "dev", TUN_NAME).Run()

	// 添加 0.0.0.0/1 和 128.0.0.0/1 两段路由，让所有公网走 VPN
	exec.Command("ip", "route", "add", "0.0.0.0/1", "via", TUN_GATEWAY, "dev", TUN_NAME).Run()
	exec.Command("ip", "route", "add", "128.0.0.0/1", "via", TUN_GATEWAY, "dev", TUN_NAME).Run()

	log.Println("📶 分流路由已配置（公网走 VPN）")
	exec.Command("ip", "route", "show").Run()

}

func tunToVPN(ifce *water.Interface, conn *tls.Conn, wg *sync.WaitGroup) {
	defer wg.Done()
	buf := make([]byte, MTU)
	for {
		n, err := ifce.Read(buf)
		if err != nil {
			log.Println("TUN 读取失败:", err)
			return
		}
		conn.Write(buf[:n])
	}
}

func vpnToTun(ifce *water.Interface, conn *tls.Conn, wg *sync.WaitGroup) {
	defer wg.Done()
	buf := make([]byte, MTU)
	for {
		n, err := conn.Read(buf)
		if err != nil {
			log.Println("TLS 读取失败:", err)
			return
		}
		ifce.Write(buf[:n])
	}
}
