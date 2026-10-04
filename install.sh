#!/bin/bash
#==============================================================
#  JgXeinz VPN  -  Instalador
#==============================================================

# ------------------- CONFIG (edita aca) -------------------
GITHUB_USER="TU_USUARIO"       # <-- tu usuario de GitHub
GITHUB_REPO="Script_VPS"
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
apt-get install -y python3 curl wget screen figlet badvpn >/dev/null 2>&1

# --- archivos ---
echo -e "${YELLOW}Descargando archivos...${NC}"
mkdir -p /etc/jgxeinz
curl -fsSL "$BASE/proxy.py" -o /etc/jgxeinz/proxy.py
curl -fsSL "$BASE/menu"     -o /usr/bin/menu
chmod +x /usr/bin/menu

# --- habilitar login por contrasena (para HTTP Custom) ---
mkdir -p /etc/ssh/sshd_config.d
echo "PasswordAuthentication yes" > /etc/ssh/sshd_config.d/99-jgxeinz.conf
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null

clear
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}        INSTALACION COMPLETADA            ${NC}"
echo -e "${GREEN}=========================================${NC}\n"
echo -e "Abri el panel con el comando: ${CYAN}menu${NC}\n"
