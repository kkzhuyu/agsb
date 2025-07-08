#!/bin/bash

set -e

echo "欢迎使用 Dante Socks5 一键安装脚本"

# 获取输入参数
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

# 安装 dante-server
apt update
apt install -y dante-server

# 创建用户
if ! id -u "$USERNAME" >/dev/null 2>&1; then
  useradd -M -s /usr/sbin/nologin "$USERNAME"
  echo "$USERNAME:$PASSWORD" | chpasswd
  echo "用户 $USERNAME 创建成功"
else
  echo "用户 $USERNAME 已存在，跳过创建"
fi

# 写入配置文件
cat > /etc/danted.conf <<EOF
logoutput: syslog

internal: 0.0.0.0 port = $PORT
external: eth0

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

# 替换网卡名
NET_IFACE=$(ip route get 1 | awk '{print $5; exit}')
sed -i "s/external: eth0/external: $NET_IFACE/" /etc/danted.conf

# 放行端口
if command -v ufw >/dev/null 2>&1; then
  ufw allow "$PORT"/tcp || true
else
  iptables -I INPUT -p tcp --dport "$PORT" -j ACCEPT
fi

# 启动服务
systemctl enable danted
systemctl restart danted

# 显示成功信息
echo
echo "✅ Socks5 安装完成！连接信息如下："
echo "地址：你的服务器公网 IP"
echo "端口：$PORT"
echo "用户名：$USERNAME"
echo "密码：$PASSWORD"
echo
echo "请用支持 Socks5 用户名密码认证的客户端连接。"
