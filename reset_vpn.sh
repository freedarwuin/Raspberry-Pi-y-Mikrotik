#!/bin/bash
# =========================================
# VPN Setup y Gestión - Raspberry Pi Gateway
# Autor: Dar + ChatGPT
# Versión: Final Segura
# =========================================

PKGS="wireguard iptables resolvconf tcpdump conntrack"
WG_CONF="/etc/wireguard/wg0.conf"
WG_IFACE="wg0"
VPN_TEST_URL="https://ifconfig.me"

# Función: Verificar acceso a internet
function check_internet() {
    echo "[*] Verificando acceso a internet..."
    if ping -c 2 8.8.8.8 >/dev/null 2>&1; then
        echo "[+] Conexión a internet OK"
        return 0
    else
        echo "[!] No hay acceso a internet, intentando restaurar..."
        ip route add default via $(ip route | grep -m1 "^default" | awk '{print $3}') dev eth0 2>/dev/null
        sleep 3
        if ping -c 2 8.8.8.8 >/dev/null 2>&1; then
            echo "[+] Internet restaurado"
            return 0
        else
            echo "[X] No se pudo restaurar internet. Revisa la conexión física."
            return 1
        fi
    fi
}

# Función: Actualizar sistema
function update_system() {
    check_internet || return 1
    echo "[*] Actualizando paquetes..."
    apt update && apt upgrade -y
    echo "[+] Sistema actualizado"
}

# Función: Instalar dependencias
function install_packages() {
    check_internet || return 1
    echo "[*] Instalando paquetes necesarios..."
    apt install -y $PKGS
    echo "[+] Instalación completada"
}

# Función: Configurar WireGuard
function setup_wireguard() {
    check_internet || return 1
    echo "[*] Creando configuración de WireGuard..."
    mkdir -p /etc/wireguard
    cat > $WG_CONF <<EOF
[Interface]
PrivateKey = 8AX1O20y6ClP8tpA6PCbA03uTuZ+1SE9IkVmLC5/eFw=
Address = 10.2.0.2/32
DNS = 10.2.0.1

[Peer]
PublicKey = wweP0YfxgQTCes+5UoXfhLbWXvHXGnwQkozFzvBA/i4=
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = 185.177.126.102:51820
PersistentKeepalive = 25
EOF
    chmod 600 $WG_CONF
    echo "[+] Configuración de WireGuard creada"
}

# Función: Levantar WireGuard y reglas
function start_vpn() {
    check_internet || return 1
    echo "[*] Levantando WireGuard..."
    wg-quick up $WG_IFACE
    echo "[+] VPN activada"
}

# Función: Verificar tráfico
function verify_vpn() {
    echo "[*] IP pública actual:"
    curl -s $VPN_TEST_URL
    echo
}

# Función: Monitorear tráfico wg0
function monitor_tcpdump() {
    if ! command -v tcpdump >/dev/null 2>&1; then
        echo "[!] tcpdump no está instalado"
        return 1
    fi
    echo "[*] Iniciando tcpdump en $WG_IFACE (Ctrl+C para salir)..."
    tcpdump -n -i $WG_IFACE
}

# Función: Ver conexiones con conntrack
function monitor_conntrack() {
    if ! command -v conntrack >/dev/null 2>&1; then
        echo "[!] conntrack no está instalado"
        return 1
    fi
    echo "[*] Conexiones activas relacionadas a la VPN:"
    conntrack -L | grep 10.2.0.
}

# Función: Detener WireGuard
function detener_wg() {
    echo "[+] Deteniendo interfaz $WG_IFACE si existe..."
    wg-quick down $WG_IFACE 2>/dev/null
}

# Función: Borrar todo sin perder SSH
function borrar_todo() {
    echo "[!] Restaurando ruta principal antes de limpiar..."
    ip route add default via $(ip route | grep -m1 "^default" | awk '{print $3}') dev eth0 2>/dev/null

    detener_wg

    echo "[*] Limpiando reglas de iptables relacionadas con la VPN..."
    iptables -t nat -F
    iptables -F
    iptables -X

    echo "[*] Borrando configuración de WireGuard..."
    rm -f $WG_CONF

    read -p "[?] ¿Quieres desinstalar los paquetes VPN? (s/n): " resp
    if [[ "$resp" == "s" || "$resp" == "S" ]]; then
        apt remove --purge -y $PKGS
        apt autoremove -y
        echo "[+] Paquetes desinstalados"
    else
        echo "[+] Paquetes conservados"
    fi

    echo "[✓] Limpieza completa y conexión LAN restaurada"
}

# Menú principal
while true; do
    clear
    echo "===== VPN Gateway Setup ====="
    echo "1) Actualizar sistema"
    echo "2) Instalar paquetes"
    echo "3) Configurar WireGuard"
    echo "4) Levantar VPN"
    echo "5) Verificar IP pública"
    echo "6) Monitor tcpdump"
    echo "7) Monitor conntrack"
    echo "8) Borrar todo (seguro)"
    echo "9) Salir"
    echo "============================="
    read -p "Selecciona: " opt
    case $opt in
        1) update_system ;;
        2) install_packages ;;
        3) setup_wireguard ;;
        4) start_vpn ;;
        5) verify_vpn ;;
        6) monitor_tcpdump ;;
        7) monitor_conntrack ;;
        8) borrar_todo ;;
        9) exit 0 ;;
        *) echo "Opción inválida" ;;
    esac
    read -p "Presiona ENTER para continuar..."
done
