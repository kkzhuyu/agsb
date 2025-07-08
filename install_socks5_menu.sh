#!/bin/bash
set -e

CONFIG_FILE="/etc/danted.conf"
QR_FILE="/root/socks5_qr.png"
SERVICE="danted"

# 获取主网卡
get_iface() {
  ip route get 1 | awk '{print $5; exit}'
}

# 获取公网 IP
get_ip() {
  curl -s ifconfig.me || curl -s ip.sb || echo "YOUR_SERVER_IP"
}

install_socks5() {
  read -p "请输入代理端口 [默认1099]: " PORT
  PORT=${PORT:-1099}

  read -p "请输入用户名 [默认socks5user]: " USERNAME
  USERNAME=${USERNAME:-socks5user}

  read -p "请输入密码 [默认112233]: " PASSWORD
  PASSWORD=${PASSWORD:-112233}

  echo "安装 Dante Socks5 中..."
  apt update
  apt install -y dante-server python3 python3-pip
  pip3 install -q qrcode[pil]

  if ! id -u "$USERNAME" >/dev/null 2>&1; then
    useradd -M -s /usr/sbin/nologin "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd
  fi

  NET_IFACE=$(get_iface)
  IP=$(get_ip)

  cat > $CONFIG_FILE <<EOF
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

  iptables -I INPUT -p tcp --dport "$PORT" -j ACCEPT || true
  systemctl enable $SERVICE
  systemctl restart $SERVICE

  cat <<PYEOF > /tmp/gen_qr.py
import qrcode
uri = "socks5://$USERNAME:$PASSWORD@$IP:$PORT"
img = qrcode.make(uri)
img.save("$QR_FILE")
print("✅ 二维码保存路径: $QR_FILE")
print("📦 内容:", uri)
PYEOF

  python3 /tmp/gen_qr.py
  rm -f /tmp/gen_qr.py

  echo "✅ 安装完成！"
}

uninstall_socks5() {
  echo "卸载 Dante Socks5..."
  systemctl stop $SERVICE || true
  systemctl disable $SERVICE || true
  apt remove --purge -y dante-server || true
  rm -f $CONFIG_FILE $QR_FILE
  echo "✅ 卸载完成。"
}

service_control() {
  echo "1. 启动 Socks5"
  echo "2. 停止 Socks5"
  echo "3. 重启 Socks5"
  read -p "请选择操作 [1-3]: " opt
  case "$opt" in
    1) systemctl start $SERVICE && echo "已启动" ;;
    2) systemctl stop $SERVICE && echo "已停止" ;;
    3) systemctl restart $SERVICE && echo "已重启" ;;
    *) echo "无效选项" ;;
  esac
}

modify_config() {
  echo "正在打开配置文件：$CONFIG_FILE"
  nano "$CONFIG_FILE"
  systemctl restart $SERVICE
}

show_config() {
  echo "当前配置文件内容："
  echo "---------------------------------------------------"
  cat "$CONFIG_FILE"
  echo "---------------------------------------------------"
}

while true; do
  echo
  echo "================= Socks5 管理菜单 ================="
  echo "1. 安装 Socks5"
  echo "2. 卸载 Socks5"
  echo "---------------------------------------------------"
  echo "3. 关闭、开启、重启 Socks5"
  echo "4. 修改 Socks5 配置"
  echo "5. 显示 Socks5 配置文件"
  echo "0. 退出"
  echo "==================================================="
  read -p "请输入选项 [0-5]: " choice

  case "$choice" in
    1) install_socks5 ;;
    2) uninstall_socks5 ;;
    3) service_control ;;
    4) modify_config ;;
    5) show_config ;;
    0) echo "退出"; exit 0 ;;
    *) echo "无效选项，请重试" ;;
  esac
done
