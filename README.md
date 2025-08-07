# 🌐 VPN WireGuard Gateway con Raspberry Pi

Convierte tu Raspberry Pi en un router VPN usando **WireGuard** y enruta el tráfico de tu red local a través de un túnel seguro.

## 📦 Archivos incluidos

- `reset_vpn.sh`: Script automático para instalar, configurar, limpiar reglas y levantar la VPN.
- `wg0.conf`: Archivo de configuración generado dinámicamente por el script.
- `.gitignore`: Ignora el archivo `wg0.conf` para no subir claves sensibles al repositorio.

---

## 🚀 Requisitos

- Raspberry Pi con sistema basado en Debian (Raspbian / Raspberry Pi OS).
- Acceso a Internet (temporal o permanente).
- Permisos de superusuario (`sudo`).
- Paquetes necesarios: `wireguard`, `resolvconf`, `iptables`.

---

## 🔧 Instalación de dependencias (si no se instalan automáticamente)

```bash
sudo apt update
sudo apt install -y wireguard resolvconf iptables
