#!/bin/bash

echo "[+] Deteniendo interfaz wg0 si está activa..."
wg-quick down wg0 2>/dev/null

echo "[+] Reescribiendo configuración wg0.conf..."

cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
PrivateKey = TU_CLAVE_PRIVADA
Address = 10.2.0.2/32
DNS = 10.2.0.1
Table = 51820
FwMark = 51820

[Peer]
PublicKey = CLAVE_PUBLICA_DEL_SERVIDOR
Endpoint = ENDPOINT_DEL_SERVIDOR:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

chmod 600 /etc/wireguard/wg0.conf

echo "[+] Verificando si wg está instalado..."
if ! command -v wg >/dev/null 2>&1; then
  echo "Instalando WireGuard..."
  apt update && apt install wireguard -y
fi

echo "[+] Activando reenvío de IP..."
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1

echo "[+] Aplicando reglas iptables..."
iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE
iptables -A FORWARD -i wg0 -j ACCEPT
iptables -A FORWARD -o wg0 -j ACCEPT

echo "[+] Levantando interfaz wg0..."
wg-quick up wg0

echo "[+] Estado actual de la VPN:"
wg show

echo "[+] Verificando conexión a internet (VPN)..."
VPN_IP=$(curl -s ifconfig.me)
echo "[+] Tu IP pública vía VPN es: $VPN_IP"