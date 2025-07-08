#!/bin/bash
set -e

# 卸载功能
if [[ "$1" == "uninstall" ]]; then
  echo "🧹 正在卸载 Dante Socks5..."
  systemctl stop danted || true
  systemctl disable danted || true
  apt remove --purge -y dante-server || true
  rm -f /etc/danted.conf /root/socks5_qr.png
  echo "✅ 已卸载 Dante Socks5 并清理配置。"
  exit 0
fi

echo "🎉 欢迎使用 Dante Socks5 一键安装脚本"

read -p "请输入代理端口 [默认1099]: " PORT
PORT=${PORT:-1099}

read -p "请输入用户名 [默认socks5user]: " USERNAME
USERNAME=${USERNAME:-socks5user}

read -p "请输入密码 [默认112233]: " PASSWORD
PASSWORD=${PASSWORD:-112233}

echo -e "\n配置如下："
echo "端口: $PORT"
echo "用户名: $USERNAME"
echo "密码: $PASSWORD"
echo

# 安装依赖
apt update
apt install -y dante-server python3 python3-pip

# 安装二维码库
pip3 install -q qrcode[pil]

# 创建用户
if ! id -u "$USERNAME" >/dev/null 2>&1; then
  useradd -M -s /usr/sbin/nologin "$USERNAME"
  echo "$USERNAME:$PASSWORD" | chpasswd
  echo "✅ 用户 $USERNAME 创建成功"
else
  echo "ℹ️ 用户 $USERNAME 已存在，跳过创建"
fi

# 获取主网卡和公网 IP
NET_IFACE=$(ip route get 1 | awk '{print $5; exit}')
IP=$(curl -s ifconfig.me || echo "YOUR_SERVER_IP")

# 写入配置
cat > /etc/danted.conf <<EOF
logoutput: syslog

internal: 0.0.0.0 port = $PORT
external: $NET_IFACE

socksmethod: username
user.notprivileged: nobody

clientmethod: none
client pass {
  from: 0.0.0.0/0 to: 0.0.0.0/0
  log: connect disconnect
}

pass {
  from: 0.0.0.0/0 to: 0.0.0.0/0
  protocol: tcp udp
  log: connect disconnect
}
EOF

# 开放端口
iptables -I INPUT -p tcp --dport "$PORT" -j ACCEPT || true

# 启动服务
systemctl enable danted
systemctl restart danted

# 生成二维码
cat <<EOF > /tmp/gen_qr.py
import qrcode
uri = "socks5://$USERNAME:$PASSWORD@$IP:$PORT"
img = qrcode.make(uri)
img.save("/root/socks5_qr.png")
print("✅ 已生成二维码：/root/socks5_qr.png")
print("📦 内容：", uri)
EOF

python3 /tmp/gen_qr.py
rm /tmp/gen_qr.py

# 完成提示
echo -e "\n🎯 Socks5 服务安装完成！连接信息："
echo "地址：$IP"
echo "端口：$PORT"
echo "用户名：$USERNAME"
echo "密码：$PASSWORD"
echo "二维码图片：/root/socks5_qr.png"
echo -e "\n📦 如需卸载，请执行：\n  bash install_socks5.sh uninstall"
