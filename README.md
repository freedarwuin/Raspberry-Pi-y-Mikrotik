# VPN WireGuard Gateway con Raspberry Pi

Este proyecto convierte tu Raspberry Pi en un router que enruta el tráfico a través de una VPN usando **WireGuard**.

## 📦 Contenido

- `reset_vpn.sh`: Script para instalar, configurar y levantar automáticamente la VPN.
- `wg0.conf`: Configuración generada automáticamente.
- `.gitignore`: Protege tu archivo de configuración con claves.

## 🚀 Requisitos

- Raspberry Pi con Debian (Raspbian, Raspberry Pi OS)
- Acceso a internet
- Permisos de superusuario

## 🔐 Configuración

Edita `reset_vpn.sh` y reemplaza:

```bash
PrivateKey = TU_CLAVE_PRIVADA
PublicKey  = CLAVE_PUBLICA_DEL_SERVIDOR
Endpoint   = ENDPOINT_DEL_SERVIDOR:51820
