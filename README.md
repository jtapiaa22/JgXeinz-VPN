# JgXeinz VPN

Panel de administración para servidores VPS (Ubuntu / Debian), pensado para gestionar
usuarios SSH y túneles (WebSocket + BadVPN/UDPGW) usados con apps tipo HTTP Custom.

Compatible con **Ubuntu 22.04 / 24.04 / 26.04** y **Debian 12 / 13** (arquitectura x86-64).

---

## Instalación

En el VPS, como root (`sudo -i`):

```bash
apt-get update -y && apt-get install -y curl
bash <(curl -fsSL https://raw.githubusercontent.com/jtapiaa22/JgXeinz-VPN/main/install.sh)
```

El instalador pide una **KEY**. Si la key está en `keys.txt`, instala el panel.

Después se abre con:

```bash
menu
```

---

## Funciones

- **Usuarios:** crear, usuario de prueba (con borrado automático), remover, cambiar fecha,
  **renovar (sumar días sobre el vencimiento actual)**, cambiar límite, cambiar contraseña,
  remover expirados, reporte. Los nombres se validan y el usuario se crea solo si `useradd`
  tuvo éxito.
- **Grupo `jgxvpn`:** todos los usuarios del panel entran a este grupo. Así se distinguen de
  los usuarios del sistema (root, ubuntu, admin…), que el panel nunca toca.
- **Monitor online / Limiter:** cuentan sesiones de SSH **y Dropbear**.
- **Modo de conexión:** puertos SSH (con el 22 siempre protegido), WebSocket (proxy Python),
  BadVPN/UDPGW, Dropbear, OpenVPN, SSL Tunnel (stunnel), SSLH, Squid.
- **OpenVPN** autentica con los **mismos usuarios y contraseñas del panel** (PAM); el `.ovpn`
  del cliente pide usuario y contraseña, no lleva certificado compartido.
- **Tráfico por usuario:** la regla se crea al dar de alta y se persiste (sobrevive reinicios).
- **Herramientas:** optimizar red (BBR), banner, dominio, importar usuarios, **zona horaria**,
  **estado de servicios** (ver logs / reiniciar), desinstalar.
- **Info del VPS** y **Backup** de usuarios (incluye contraseñas **y fechas de vencimiento**).

---

## Seguridad

El panel deja el login por contraseña abierto (lo necesita HTTP Custom), así que el instalador
agrega varias protecciones:

- **fail2ban** contra fuerza bruta en el SSH.
- **Hardening** de los usuarios de túnel (`Match Group jgxvpn`): sin TTY, sin reenvío de X ni de agente.
- **Bloqueo de la metadata de la nube** (`169.254.169.254`) para los usuarios del túnel: evita que
  alguien saque las credenciales del rol IAM de la instancia.
- **Puerto 25 saliente cerrado** para esos usuarios, para que nadie mande spam por tu IP.

> Pendiente/opcional: validar la KEY del lado del servidor (un Worker de Cloudflare con la key
> atada a la IP del VPS) en lugar de `keys.txt` público, que es seguridad blanda.

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

## Pendiente (próximas pasadas)

- Cuota de datos por usuario (GB/mes) cortando con la medición de iptables.
- Backup automático diario con rotación y envío afuera (Telegram / scp / S3).
- Timer diario que elimine expirados y corte sus sesiones activas.
- Swap y `unattended-upgrades` desde Herramientas.
- Let's Encrypt para stunnel cuando hay dominio.
- Bot de Telegram para crear/renovar/consultar desde el celu.
- Xray (VLESS/VMess sobre WS+TLS), udp-custom real y SlowDNS (dnstt).

---

## Aviso

Script para administrar tu propio servidor. Usalo de acuerdo a las leyes de tu país
y a los términos de servicio de tu proveedor. Sin garantía.
