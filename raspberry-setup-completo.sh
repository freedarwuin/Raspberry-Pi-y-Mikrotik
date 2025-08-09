#!/bin/bash
# raspberry-setup-completo.sh
# Configura Raspberry Pi como gateway WireGuard (cliente ProtonVPN ejemplo)
# Ejecutar como root
set -e

# ---------- Config (editar si hace falta) ----------
WG_CONF="/etc/wireguard/wg0.conf"
WG_IFACE="wg0"
LAN_IFACE="eth0"                # interfaz que conecta la Pi al Mikrotik (ajusta si usas otra)
LAN_SUBNET="192.168.100.0/24"   # red local que quieres NATear (clientes)
PKGS=(wireguard iptables iptables-persistent curl tcpdump conntrack resolvconf)
SYSCTL_FILE="/etc/sysctl.d/99-wg-forward.conf"
IPTABLES_COMMENT_MASQ="WG-MASQ"
IPTABLES_COMMENT_FWD1="WG-FWD-LAN-WG"
IPTABLES_COMMENT_FWD2="WG-FWD-WG-LAN"

# Valores WireGuard (usa los tuyos; estos son los que has estado usando)
WG_PRIVATE="AMnVdmY/Sv/DRqnqytKt3kIrKotinyR6uKjAt62qLWU="
WG_IP="10.2.0.2/32"
WG_DNS="10.2.0.1"
WG_PEER_PUBLIC="vH2i8RY1qc66XfqwrixBpvH4K9GYJatkugJj0GHgoUQ="
WG_ALLOWED_IPS="0.0.0.0/0, ::/0"
WG_ENDPOINT="217.23.3.76:51820"
WG_KEEPALIVE="25"

# ---------- Helpers ----------
function pause() {
    read -rp "Presiona ENTER para continuar..."
}

function is_installed() {
    command -v "$1" >/dev/null 2>&1
}

# ---------- 1) Instalar paquetes ----------
function instalar_paquetes() {
    echo "[*] Instalando paquetes necesarios..."
    apt update -y
    for p in "${PKGS[@]}"; do
        if ! dpkg -s "$p" >/dev/null 2>&1; then
            echo "    -> instalando $p..."
            apt install -y "$p"
        else
            echo "    -> $p ya instalado"
        fi
    done
    echo "[+] Instalación completada."
}

# ---------- 2) Crear wg0.conf ----------
function crear_wg_conf() {
    echo "[*] Creando $WG_CONF (usa las variables en el script, edita si hace falta)..."
    mkdir -p /etc/wireguard
    chmod 700 /etc/wireguard

    cat > "$WG_CONF" <<EOF
[Interface]
PrivateKey = $WG_PRIVATE
Address = $WG_IP
DNS = $WG_DNS

[Peer]
PublicKey = $WG_PEER_PUBLIC
AllowedIPs = $WG_ALLOWED_IPS
Endpoint = $WG_ENDPOINT
PersistentKeepalive = $WG_KEEPALIVE
EOF

    chmod 600 "$WG_CONF"
    echo "[+] $WG_CONF creado."
}

# ---------- 3) Habilitar forwarding (persistente) ----------
function habilitar_forwarding() {
    echo "[*] Habilitando forwarding IPv4/IPv6..."
    sysctl -w net.ipv4.ip_forward=1
    sysctl -w net.ipv6.conf.all.forwarding=1

    # Persistente (fichero separado)
    cat > "$SYSCTL_FILE" <<EOF
# Habilitar forwarding para WireGuard
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF
    sysctl --system >/dev/null 2>&1 || true
    echo "[+] Forwarding habilitado y persistente ($SYSCTL_FILE)."
}

# ---------- 4) Aplicar iptables (NAT + FORWARD) ----------
function aplicar_iptables() {
    echo "[*] Aplicando reglas iptables... (agregar comentarios para borrado limpio)"

    # Proteger SSH actual (si existe)
    if [[ -n "${SSH_CONNECTION:-}" ]]; then
        SSH_CLIENT_IP=$(echo "$SSH_CONNECTION" | awk '{print $1}')
        SSH_IFACE=$(ip route get "$SSH_CLIENT_IP" | awk '{print $3; exit}')
        echo "    -> Aceptando SSH desde $SSH_CLIENT_IP vía $SSH_IFACE temporalmente"
        iptables -I INPUT -i "$SSH_IFACE" -p tcp --dport 22 -s "$SSH_CLIENT_IP" -j ACCEPT -m comment --comment "WG-SSH-KEEP"
        iptables -I OUTPUT -o "$SSH_IFACE" -p tcp --sport 22 -d "$SSH_CLIENT_IP" -j ACCEPT -m comment --comment "WG-SSH-KEEP"
    fi

    # Añadir MASQUERADE (si no existe)
    if ! iptables -t nat -C POSTROUTING -s "$LAN_SUBNET" -o "$WG_IFACE" -j MASQUERADE 2>/dev/null; then
        iptables -t nat -A POSTROUTING -s "$LAN_SUBNET" -o "$WG_IFACE" -j MASQUERADE -m comment --comment "$IPTABLES_COMMENT_MASQ"
        echo "    -> MASQUERADE agregado para $LAN_SUBNET -> $WG_IFACE"
    else
        echo "    -> MASQUERADE ya presente"
    fi

    # Reglas FORWARD
    if ! iptables -C FORWARD -i "$LAN_IFACE" -o "$WG_IFACE" -j ACCEPT 2>/dev/null; then
        iptables -A FORWARD -i "$LAN_IFACE" -o "$WG_IFACE" -j ACCEPT -m comment --comment "$IPTABLES_COMMENT_FWD1"
    fi
    if ! iptables -C FORWARD -i "$WG_IFACE" -o "$LAN_IFACE" -j ACCEPT 2>/dev/null; then
        iptables -A FORWARD -i "$WG_IFACE" -o "$LAN_IFACE" -j ACCEPT -m comment --comment "$IPTABLES_COMMENT_FWD2"
    fi

    # Guardar reglas (iptables-persistent / netfilter-persistent)
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save || true
    elif command -v invoke-rc.d >/dev/null 2>&1; then
        iptables-save > /etc/iptables/rules.v4 || true
    fi

    echo "[+] Reglas iptables aplicadas y guardadas."
}

# ---------- 5) Levantar WireGuard (y habilitar en systemd) ----------
function levantar_wireguard() {
    echo "[*] Levantando WireGuard ($WG_IFACE)..."
    # down previo por si queda en mal estado
    wg-quick down "$WG_IFACE" >/dev/null 2>&1 || true
    set +e
    wg-quick up "$WG_IFACE"
    code=$?
    set -e
    if [[ $code -ne 0 ]]; then
        echo "[!] Error al levantar wg-quick up $WG_IFACE (revisa logs)."
        journalctl -xeu wg-quick@"$WG_IFACE".service -n 50 --no-pager || true
        return 1
    fi
    systemctl enable wg-quick@"$WG_IFACE".service >/dev/null 2>&1 || true
    echo "[+] WireGuard levantado y activado en systemd."
}

# ---------- 6) Verificaciones y debug ----------
function pruebas_post() {
    echo
    echo "=== Estado WireGuard ==="
    wg show || true
    echo
    echo "=== Rutas relevantes ==="
    ip rule show
    echo
    echo "=== Tabla de rutas (comprobar tabla wg si la usas) ==="
    ip route show table all 2>/dev/null || true
    echo
    echo "=== iptables NAT POSTROUTING ==="
    iptables -t nat -L POSTROUTING -v -n | grep -E "$WG_IFACE|$IPTABLES_COMMENT_MASQ" || true
    echo
    echo "=== Conexión a internet (vía wg) ==="
    if command -v curl >/dev/null 2>&1; then
        echo "  IP pública (intentar con interfaz wg):"
        curl -s --interface "$WG_IFACE" https://ifconfig.me || echo "  curl via $WG_IFACE falló (¿wg no tiene salida?)"
        echo
    fi
    echo "=== Conntrack (flujos con LAN) ==="
    if command -v conntrack >/dev/null 2>&1; then
        conntrack -L | grep "${LAN_SUBNET%.*}" || true
    fi
    echo
}

# ---------- 7) Borrar todo (seguro) ----------
function borrar_todo() {
    echo "[!] Ejecutando borrado seguro..."
    echo "[*] Restaurando ruta por defecto si es necesario..."
    # No forzamos eliminación de route default; solo intentamos asegurar SSH si estamos remotos:
    if [[ -n "${SSH_CONNECTION:-}" ]]; then
        SSH_CLIENT_IP=$(echo "$SSH_CONNECTION" | awk '{print $1}')
        SSH_IFACE=$(ip route get "$SSH_CLIENT_IP" | awk '{print $3; exit}')
        echo "    -> Manteniendo SSH desde $SSH_CLIENT_IP / $SSH_IFACE"
        iptables -I INPUT -i "$SSH_IFACE" -p tcp --dport 22 -s "$SSH_CLIENT_IP" -j ACCEPT -m comment --comment "WG-SSH-KEEP"
        iptables -I OUTPUT -o "$SSH_IFACE" -p tcp --sport 22 -d "$SSH_CLIENT_IP" -j ACCEPT -m comment --comment "WG-SSH-KEEP"
    fi

    echo "[*] Deteniendo WireGuard..."
    wg-quick down "$WG_IFACE" >/dev/null 2>&1 || true
    systemctl disable wg-quick@"$WG_IFACE".service >/dev/null 2>&1 || true

    echo "[*] Eliminando reglas iptables agregadas por este script..."
    # Intentamos borrar las reglas específicas (seguro aunque no existan)
    iptables -t nat -D POSTROUTING -s "$LAN_SUBNET" -o "$WG_IFACE" -j MASQUERADE 2>/dev/null || true
    iptables -D FORWARD -i "$LAN_IFACE" -o "$WG_IFACE" -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -i "$WG_IFACE" -o "$LAN_IFACE" -j ACCEPT 2>/dev/null || true
    iptables -D INPUT -p tcp --dport 22 -j ACCEPT -m comment --comment "WG-SSH-KEEP" 2>/dev/null || true
    iptables -D OUTPUT -p tcp --sport 22 -j ACCEPT -m comment --comment "WG-SSH-KEEP" 2>/dev/null || true

    # Limpiar persistencia de iptables (si se usó iptables-persistent)
    if [[ -f /etc/iptables/rules.v4 ]]; then
        iptables-save > /etc/iptables/rules.v4 || true
    fi

    echo "[*] Borrando archivo de configuración WireGuard..."
    rm -f "$WG_CONF" || true
    rm -f /etc/wireguard/*.bak 2>/dev/null || true

    echo "[*] Eliminando sysctl persistente añadido..."
    rm -f "$SYSCTL_FILE" || true
    sysctl --system >/dev/null 2>&1 || true

    # Preguntar si desinstalar paquetes
    read -rp "[?] ¿Desinstalar paquetes instalados por este script? (s/N): " resp
    if [[ "${resp,,}" == "s" ]]; then
        apt remove --purge -y "${PKGS[@]}" || true
        apt autoremove -y || true
        echo "[+] Paquetes eliminados."
    fi

    echo "[✓] Limpieza completa. Reinicia la Pi si quieres."
}

# ---------- Menu interactivo ----------
function menu() {
    while true; do
        clear
        echo "=== Raspberry Pi WireGuard Gateway ==="
        echo "1) Instalar paquetes necesarios"
        echo "2) Crear / actualizar /etc/wireguard/wg0.conf (cantidad: current values in script)"
        echo "3) Habilitar forwarding persistente"
        echo "4) Aplicar reglas iptables (MASQUERADE + FORWARD) y persistirlas"
        echo "5) Levantar WireGuard (wg-quick up) y habilitar systemd"
        echo "6) Pruebas / estado (wg, iptables, conntrack, IP pública)"
        echo "7) Monitor (tcpdump wg0)"
        echo "8) Borrar todo (seguro) - deja la Pi como nueva"
        echo "9) Mostrar resumen de instalados/no instalados"
        echo "0) Salir"
        echo "======================================"
        read -rp "Selecciona: " opt
        case $opt in
            1) instalar_paquetes; pause ;;
            2) crear_wg_conf; pause ;;
            3) habilitar_forwarding; pause ;;
            4) aplicar_iptables; pause ;;
            5) levantar_wireguard; pause ;;
            6) pruebas_post; pause ;;
            7) echo "[*] Ctrl+C para detener tcpdump"; tcpdump -n -i "$WG_IFACE" not port 51820 || true; pause ;;
            8) read -rp "¿Seguro? Esto eliminará la config WireGuard. (s/N): " r; if [[ "${r,,}" == "s" ]]; then borrar_todo; fi; pause ;;
            9)
                echo "Paquetes requeridos:"
                for p in "${PKGS[@]}"; do
                    if dpkg -s "$p" >/dev/null 2>&1; then
                        echo "  [OK] $p"
                    else
                        echo "  [NO] $p"
                    fi
                done
                pause
                ;;
            0) exit 0 ;;
            *) echo "Opción inválida"; pause ;;
        esac
    done
}

menu
