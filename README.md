# JgXeinz VPN

Panel de administración para servidores VPS (Ubuntu / Debian), pensado para gestionar
usuarios SSH y túneles (WebSocket + BadVPN/UDPGW) usados con apps tipo HTTP Custom.

Compatible con **Ubuntu 22.04 / 24.04 / 26.04** y **Debian 12 / 13** (arquitectura x86-64).

---

## Instalación

En el VPS, como root (`sudo -i`):

```bash
apt-get update -y && apt-get install -y curl
bash <(curl -fsSL https://raw.githubusercontent.com/TU_USUARIO/Script_VPS/main/install.sh)
```

El instalador pide una **KEY**. Si la key está en `keys.txt`, instala el panel.

Después se abre con:

```bash
menu
```

> Cambiá `TU_USUARIO` por tu usuario real de GitHub, acá y en `install.sh`.

---

## Funciones (etapa 1)

- **Usuarios:** crear, usuario de prueba (con borrado automático), remover, cambiar fecha,
  cambiar límite, cambiar contraseña, remover expirados, reporte.
- **Monitor online:** conexiones activas por usuario.
- **Modo de conexión:** puertos SSH, WebSocket (proxy Python), BadVPN/UDPGW (para voz/UDP).
- **Info del VPS** y **Backup** de usuarios (incluye las contraseñas).

Pendiente para la etapa 2: límite real de conexiones (limiter), tráfico por usuario,
Dropbear, OpenVPN, SSL Tunnel, SSLH, SlowDNS, Squid, banner editable, speedtest, optimizar.

---

## Sistema de KEY

El instalador compara la key ingresada contra las líneas de `keys.txt` en este repo.
Para dar de alta o de baja una key, editás `keys.txt` y hacés commit.

**Importante:** una key dentro de un script es seguridad *blanda*. Si el repo es público,
cualquiera puede leer `keys.txt`, y alguien técnico puede leer el script y saltear el chequeo.
Sirve para controlar instalaciones casuales, no es un candado real.

### Proteger el código (binario)

Cuando el script ya funcione, podés compilar el `menu` a binario con `build.sh` (usa `shc`):

```bash
bash build.sh
cp menu.x /usr/bin/menu
```

Esto dificulta la lectura del código, pero tampoco es infalible (es reversible con esfuerzo)
y el binario solo corre en la misma arquitectura (x86-64, no ARM).

---

## Puertos en AWS

Recordá que además de abrir un puerto en el panel, hay que abrirlo en el
**grupo de seguridad** de tu instancia EC2 (ej: 22, 80, 8080).

---

## Aviso

Script para administrar tu propio servidor. Usalo de acuerdo a las leyes de tu país
y a los términos de servicio de tu proveedor. Sin garantía.
