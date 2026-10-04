#!/bin/bash
#==============================================================
#  JgXeinz VPN  -  Instalador
#==============================================================

# ------------------- CONFIG (edita aca) -------------------
GITHUB_USER="jtapiaa22"
GITHUB_REPO="JgXeinz-VPN"
BRANCH="main"
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
apt-get install -y python3 curl wget screen figlet cmake make gcc git dropbear iptables >/dev/null 2>&1
# dropbear se deja apagado para que no choque con OpenSSH en el 22 (el menu lo activa)
systemctl disable --now dropbear >/dev/null 2>&1

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

# --- habilitar login por contrasena (para HTTP Custom) ---
# AWS/cloud desactivan el login por contrasena; hay que forzarlo.
mkdir -p /etc/ssh/sshd_config.d
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null
for f in /etc/ssh/sshd_config.d/*.conf; do
  [ -e "$f" ] && sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' "$f"
done
# el prefijo 00- hace que se lea primero (en sshd gana el primer valor)
echo "PasswordAuthentication yes" > /etc/ssh/sshd_config.d/00-jgxeinz.conf
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null

clear
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}        INSTALACION COMPLETADA            ${NC}"
echo -e "${GREEN}=========================================${NC}\n"
echo -e "Abri el panel con el comando: ${CYAN}menu${NC}\n"
