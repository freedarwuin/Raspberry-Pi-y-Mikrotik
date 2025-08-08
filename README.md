# Configuración de Red para Enrutamiento VPN con Mikrotik y Raspberry Pi (WireGuard)

Este proyecto explica cómo enrutar tráfico seleccionado de una red local (LAN) gestionada por un router Mikrotik hacia una Raspberry Pi que actúa como gateway VPN usando WireGuard. El objetivo es que el tráfico salga a Internet a través de la VPN configurada en la Raspberry Pi.

---

## Contexto

- **Red LAN:** 192.168.100.0/24
- **Mikrotik IP LAN:** 192.168.100.1
- **Raspberry Pi (WireGuard cliente):** 192.168.100.54
- **Equipos cliente:** PC, teléfonos, etc. (ejemplo 192.168.100.7, 192.168.100.68)
- **Interfaz WireGuard:** wg0
- **Puerto WireGuard:** 51820

---

## Objetivos

- Redirigir tráfico de IPs específicas o rangos de la LAN hacia la Raspberry Pi para que salga por la VPN.
- Mantener el resto del tráfico saliendo directamente por el Mikrotik.
- Evitar conflictos de NAT y asegurar el correcto enrutamiento y reenvío.

---

## Paso 1: Configuración en Mikrotik

### 1.1 Crear regla Mangle para marcar tráfico

En Mikrotik, marcar el tráfico proveniente de la IP o rango que quieres enrutar por VPN.

```bash
/ip firewall mangle add chain=prerouting src-address=192.168.100.0/24 action=mark-routing new-routing-mark=to-vpn passthrough=yes comment="Marcar tráfico LAN para VPN"
