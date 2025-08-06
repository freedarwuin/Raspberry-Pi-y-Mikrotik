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

## 🔐 Crear una cuenta en ProtonVPN y obtener credenciales

1. Ingresa a la página oficial de ProtonVPN: [https://protonvpn.com/](https://protonvpn.com/)

2. Regístrate con un correo electrónico válido y crea una cuenta gratuita o de pago según tu preferencia.

3. Una vez dentro del panel de usuario, ve a la sección **Downloads** o **WireGuard Configurations** (puede variar según la versión).

4. Genera una configuración WireGuard para tu Raspberry Pi:
    - Elige el país o servidor deseado (por ejemplo, US-Free#11).
    - Descarga o copia la clave privada (`PrivateKey`), la clave pública del servidor (`PublicKey`) y el `Endpoint` (IP y puerto).

5. Copia estos valores y reemplázalos en el archivo `reset_vpn.sh` en las líneas indicadas para que tu Raspberry Pi pueda conectarse a la VPN.

## 🔐 Configuración

Edita `reset_vpn.sh` y reemplaza:

```bash
PrivateKey = TU_CLAVE_PRIVADA
PublicKey  = CLAVE_PUBLICA_DEL_SERVIDOR
Endpoint   = ENDPOINT_DEL_SERVIDOR:51820
