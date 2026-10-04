#!/bin/bash
#==============================================================
#  JgXeinz VPN  -  Compilar el menu a binario (shc)
#  Esto se corre en el VPS (o en una maquina Ubuntu/Debian x86-64)
#  CUANDO el script ya funcione. Genera 'menu.x' (binario).
#==============================================================
RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

[[ $EUID -ne 0 ]] && { echo -e "${RED}Ejecuta como root (sudo -i)${NC}"; exit 1; }

if ! command -v shc >/dev/null 2>&1; then
  echo -e "${YELLOW}Instalando shc...${NC}"
  apt-get update -y >/dev/null 2>&1
  apt-get install -y shc >/dev/null 2>&1
fi

[[ ! -f menu ]] && { echo -e "${RED}No encuentro el archivo 'menu' en esta carpeta${NC}"; exit 1; }

echo -e "${YELLOW}Compilando menu -> menu.x ...${NC}"
shc -r -f menu -o menu.x
rm -f menu.x.c
chmod +x menu.x

echo -e "${GREEN}Listo. Se genero el binario: menu.x${NC}"
echo -e "Para instalarlo como comando:  ${GREEN}cp menu.x /usr/bin/menu${NC}"
echo ""
echo -e "${YELLOW}NOTA:${NC} el binario es para la misma arquitectura (x86-64)."
echo -e "No va a correr en VPS ARM (como Oracle Ampere)."
