#!/bin/bash

WG_CONF="/etc/wireguard/wg0.conf"
WG_INTERFACE="wg0"

echo "[+] Verificando si WireGuard está instalado..."
if ! command -v wg >/dev/null || ! command -v wg-quick >/dev/null; then
    echo "[!] WireGuard no está instalado. Instalando..."
    sudo apt update && sudo apt install -y wireguard
else
    echo "[+] WireGuard ya está instalado."
fi

echo "[+] Verificando si iptables está instalado..."
if ! command -v iptables >/dev/null; then
    echo "[!] iptables no está instalado. Instalando..."
    sudo apt install -y iptables
fi

echo "[+] Verificando si resolvconf está instalado..."
if ! command -v resolvconf >/dev/null; then
    echo "[!] resolvconf no está instalado. Instalando..."
    sudo apt install -y resolvconf
fi

echo "[+] Deteniendo interfaz $WG_INTERFACE si está activa..."
sudo wg-quick down $WG_INTERFACE 2>/dev/null
sudo ip link delete $WG_INTERFACE 2>/dev/null

echo "[+] Creando directorio /etc/wireguard si no existe..."
sudo mkdir -p /etc/wireguard
sudo chmod 700 /etc/wireguard

echo "[+] Creando archivo de configuración $WG_CONF..."
sudo tee "$WG_CONF" > /dev/null <<EOF
[Interface]
PrivateKey = 4KZer+OYPcJ5kjjJlB7AUtelQm7XLKELvySjAXTHvno=
Address = 10.2.0.2/32
DNS = 10.2.0.1

[Peer]
PublicKey = FopxTTklZx2W9X1ua1rGHdn+w4F8KVwcBjVmqMFFbAI=
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = 195.181.162.163:51820
PersistentKeepalive = 25
EOF

echo "[+] Activando reenvío de IP..."
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv6.conf.all.forwarding=1

echo "[+] Limpiando reglas NAT anteriores..."
sudo iptables -t nat -D POSTROUTING -o $WG_INTERFACE -j MASQUERADE 2>/dev/null

echo "[+] Aplicando NAT para $WG_INTERFACE..."
sudo iptables -t nat -A POSTROUTING -o $WG_INTERFACE -j MASQUERADE

echo "[+] Levantando interfaz $WG_INTERFACE..."
if sudo wg-quick up $WG_INTERFACE; then
    echo "[+] Interfaz $WG_INTERFACE levantada correctamente."

    echo "[+] Verificando IP pública a través de la VPN..."
    sleep 2
    VPN_IP=$(curl -s --interface $WG_INTERFACE https://ifconfig.me)
    if [[ -n "$VPN_IP" ]]; then
        echo "[✓] Tu IP pública vía VPN es: $VPN_IP"
    else
        echo "[!] No se pudo obtener IP por $WG_INTERFACE. Verifica conectividad."
    fi
else
    echo "[!] Error al levantar la interfaz VPN. Revisa el archivo de configuración."
    echo "    Puedes probar manualmente con: sudo wg-quick up wg0"
    echo "    Y ver logs con: sudo journalctl -xeu wg-quick@wg0.service"
fi
