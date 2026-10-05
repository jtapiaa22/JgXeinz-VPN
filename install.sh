#!/bin/bash
#==============================================================
#  JgXeinz VPN  -  Instalador
#==============================================================

# ------------------- CONFIG (edita aca) -------------------
GITHUB_USER="jtapiaa22"
GITHUB_REPO="JgXeinz-VPN"
BRANCH="main"
VPN_GROUP="jgxvpn"
# ----------------------------------------------------------
BASE="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH"

RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'; NC='\033[0m'

[[ $EUID -ne 0 ]] && { echo -e "${RED}Ejecuta como root (usa: sudo -i)${NC}"; exit 1; }

clear
echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}        INSTALADOR  -  JgXeinz VPN        ${NC}"
echo -e "${CYAN}=========================================${NC}\n"

# --- verificacion de KEY ---
read -rp "Ingresa tu KEY de instalacion: " KEY
[[ -z "$KEY" ]] && { echo -e "${RED}KEY vacia${NC}"; exit 1; }
echo -e "${YELLOW}Verificando KEY...${NC}"
KEYS=$(curl -fsSL "$BASE/keys.txt" 2>/dev/null)
if [[ -z "$KEYS" ]]; then
  echo -e "${RED}No se pudo verificar la KEY (sin internet o repo mal configurado).${NC}"
  exit 1
fi
if ! echo "$KEYS" | tr -d '\r' | grep -qx "$KEY"; then
  echo -e "${RED}KEY invalida. Contacta al administrador.${NC}"
  exit 1
fi
echo -e "${GREEN}KEY valida.${NC}\n"

# --- dependencias ---
echo -e "${YELLOW}Instalando dependencias...${NC}"
apt-get update -y >/dev/null 2>&1
apt-get install -y python3 curl wget screen figlet cmake make gcc git dropbear iptables fail2ban >/dev/null 2>&1
# dropbear se deja apagado para que no choque con OpenSSH en el 22 (el menu lo activa)
systemctl disable --now dropbear >/dev/null 2>&1

# --- grupo de usuarios del panel ---
# Todos los usuarios que crea el panel van a este grupo. Asi los distinguimos
# de los usuarios del sistema (root, ubuntu, admin...) y podemos aplicarles
# firewall y reglas de sshd sin tocar a nadie mas.
getent group "$VPN_GROUP" >/dev/null 2>&1 || groupadd "$VPN_GROUP"

# --- badvpn-udpgw (se compila: ya no esta en los repos de Ubuntu) ---
if ! command -v badvpn-udpgw >/dev/null 2>&1; then
  echo -e "${YELLOW}Compilando badvpn-udpgw (para voz/UDP)...${NC}"
  rm -rf /tmp/badvpn
  git clone --depth 1 https://github.com/ambrop72/badvpn.git /tmp/badvpn >/dev/null 2>&1
  mkdir -p /tmp/badvpn/build
  ( cd /tmp/badvpn/build && \
    cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 \
      -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
      -DCMAKE_C_FLAGS="-Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=int-conversion" >/dev/null 2>&1 && \
    make >/dev/null 2>&1 && \
    cp udpgw/badvpn-udpgw /usr/bin/ )
  rm -rf /tmp/badvpn
  command -v badvpn-udpgw >/dev/null 2>&1 \
    && echo -e "${GREEN}badvpn-udpgw instalado${NC}" \
    || echo -e "${RED}No se pudo compilar badvpn (se puede hacer despues)${NC}"
fi

# --- archivos ---
echo -e "${YELLOW}Descargando archivos...${NC}"
mkdir -p /etc/jgxeinz
curl -fsSL "$BASE/proxy.py" -o /etc/jgxeinz/proxy.py
curl -fsSL "$BASE/menu"     -o /usr/bin/menu
chmod +x /usr/bin/menu
# guardamos el nombre del grupo para que el menu lo lea
echo "$VPN_GROUP" > /etc/jgxeinz/group

# --- habilitar login por contrasena (para HTTP Custom) ---
# AWS/cloud desactivan el login por contrasena; hay que forzarlo.
# Ademas dejamos Port 22 explicito: por defecto viene comentado, y si despues
# se agrega otro puerto sin esta linea, el sshd deja de escuchar en el 22.
mkdir -p /etc/ssh/sshd_config.d
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null
grep -qE '^[[:space:]]*Port[[:space:]]+22([[:space:]]|$)' /etc/ssh/sshd_config 2>/dev/null \
  || sed -i 's/^#\?Port .*/Port 22/' /etc/ssh/sshd_config 2>/dev/null
grep -qE '^[[:space:]]*Port[[:space:]]+' /etc/ssh/sshd_config 2>/dev/null \
  || echo "Port 22" >> /etc/ssh/sshd_config
for f in /etc/ssh/sshd_config.d/*.conf; do
  [ -e "$f" ] && sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' "$f"
done
# el prefijo 00- hace que se lea primero (en sshd gana el primer valor)
echo "PasswordAuthentication yes" > /etc/ssh/sshd_config.d/00-jgxeinz.conf

# --- hardening de los usuarios de tunel ---
# Los usuarios del grupo no necesitan terminal ni reenvio de X/agente.
cat > /etc/ssh/sshd_config.d/20-jgxeinz-group.conf <<EOF
Match Group $VPN_GROUP
    PermitTTY no
    X11Forwarding no
    AllowAgentForwarding no
    AllowTcpForwarding yes
EOF

# Ubuntu 22.10+ puede manejar el SSH por socket; reiniciamos ambos.
systemctl restart ssh.socket 2>/dev/null
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null

# --- fail2ban (fuerza bruta contra el login por contrasena) ---
cat > /etc/fail2ban/jail.d/jgxeinz.conf <<'EOF'
[sshd]
enabled = true
maxretry = 5
bantime = 1h
findtime = 10m
EOF
systemctl enable --now fail2ban >/dev/null 2>&1

# --- firewall para los usuarios del tunel ---
# 1) No pueden pegarle a la metadata de la nube (169.254.169.254): si la
#    instancia tiene rol IAM, por ahi se filtran credenciales de tu cuenta.
# 2) Cortamos el puerto 25 saliente para que nadie mande spam por tu IP
#    (los proveedores penalizan rapido por eso).
gid=$(getent group "$VPN_GROUP" | cut -d: -f3)
if [[ -n "$gid" ]]; then
  iptables -C OUTPUT -m owner --gid-owner "$gid" -d 169.254.169.254 -j REJECT 2>/dev/null \
    || iptables -A OUTPUT -m owner --gid-owner "$gid" -d 169.254.169.254 -j REJECT
  iptables -C OUTPUT -m owner --gid-owner "$gid" -p tcp --dport 25 -j REJECT 2>/dev/null \
    || iptables -A OUTPUT -m owner --gid-owner "$gid" -p tcp --dport 25 -j REJECT
fi
DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent >/dev/null 2>&1
netfilter-persistent save >/dev/null 2>&1

clear
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}        INSTALACION COMPLETADA            ${NC}"
echo -e "${GREEN}=========================================${NC}\n"
echo -e "Abri el panel con el comando: ${CYAN}menu${NC}\n"
