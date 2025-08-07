# 🌐 VPN WireGuard Gateway con Raspberry Pi

Este proyecto convierte tu Raspberry Pi en un gateway para enrutar tráfico de red a través de una VPN **WireGuard**, ideal para integrarse con un router Mikrotik u otro sistema que necesite un gateway seguro y automático.

---

## 📦 Archivos del Proyecto

- `reset_vpn.sh`: Script principal para instalar, configurar y levantar automáticamente la VPN.
- `wg0.conf`: Archivo generado automáticamente con la configuración WireGuard.
- `.gitignore`: Para evitar subir archivos sensibles (como claves privadas).

---

## ✅ Requisitos

- Raspberry Pi con Raspberry Pi OS o Debian
- Conexión a internet
- Acceso como superusuario (`root`)
- Configuración activa en [ProtonVPN](https://protonvpn.com/) o cualquier proveedor compatible con WireGuard

---

## 🔐 Obtener Credenciales desde ProtonVPN

1. Ve a [https://protonvpn.com/](https://protonvpn.com/)
2. Regístrate e inicia sesión
3. Accede a la sección "WireGuard"
4. Elige el país/servidor deseado (por ejemplo: `US-Free#11`)
5. Copia:
   - **PrivateKey**
   - **PublicKey** del servidor
   - **Endpoint** (IP:puerto del servidor)
   - **DNS** (opcional)

---

## ⚙️ ¿Qué hace el script `reset_vpn.sh`?

1. Verifica e instala dependencias (`wireguard`, `conntrack`, `resolvconf`)
2. Limpia configuraciones anteriores (`iptables`, `wg0`)
3. Habilita el reenvío IP
4. Crea automáticamente el archivo `/etc/wireguard/wg0.conf`
5. Activa la interfaz WireGuard (`wg0`)
6. Aplica reglas NAT (`iptables`)
7. Muestra diagnóstico en caso de errores

---

## 📝 Configuración en el Script

Edita el script y reemplaza las siguientes variables:


🚀 Instalación y Ejecución
bash
Copiar
Editar
chmod +x reset_vpn.sh
sudo bash reset_vpn.sh
Si todo está correcto, deberías ver:

IP pública desde interfaz VPN (wg0)

Interfaz wg0 levantada

Conectividad a internet activa

🛠️ Diagnóstico y Soporte
Si falla la conexión, el script muestra en pantalla qué parte falló.

Puedes revisar el log con:

bash
Copiar
Editar
journalctl -xeu wg-quick@wg0
🧪 Verificar estado de VPN
bash
Copiar
Editar
wg show
ip a show wg0
curl ifconfig.me
🔄 Resetear completamente
Ejecutar nuevamente el script reset_vpn.sh eliminará configuraciones anteriores y reinstalará todo desde cero.

🧠 Sugerencia para Mikrotik
Puedes usar Mangle y Routing Mark para enviar tráfico desde un cliente específico a través de la Raspberry Pi y esta lo enruta por la VPN.

👨‍💻 Autor
Darwuin Jose Pedroza
Telegram: @freedarwuin


```bash
PRIVATE_KEY="TU_CLAVE_PRIVADA"
PEER_PUBLIC_KEY="CLAVE_PUBLICA_DEL_SERVIDOR"
ENDPOINT="IP_DEL_SERVIDOR:51820"
DNS_SERVER="10.2.0.1"


