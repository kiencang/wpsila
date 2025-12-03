#!/bin/bash

# --- Cấu hình màu sắc ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Định nghĩa thư mục gốc ---
BASE_DIR=$(dirname "$(readlink -f "$0")")

# Kiểm tra quyền Root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Loi: Ban phai chay lenh nay duoi quyen Root!${NC}" 
   exit 1
fi

show_menu() {
    clear
    echo -e "${BLUE}================================================${NC}"
    echo -e "${GREEN}    WPSILA MANAGER (Local Version)              ${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo -e "${YELLOW}1.${NC} Cai dat (install) Caddy Web Server"
    echo -e "${YELLOW}2.${NC} Cai dat (install) Website WordPress moi"
    echo -e "${YELLOW}3.${NC} Go cai dat (delete) Website WordPress"
    echo -e "${BLUE}------------------------------------------------${NC}"
    echo -e "${YELLOW}0.${NC} Exit (thoat)"
    echo -e "${BLUE}================================================${NC}"
    echo -n "Nhap lua chon: "
}

while true; do
    show_menu
    read -r choice  # Them -r cho an toan
    case $choice in
        1)
            if [[ -f "$BASE_DIR/install_caddy.sh" ]]; then
                bash "$BASE_DIR/install_caddy.sh"
            else
                echo -e "${RED}Loi: Khong tim thay file install_caddy.sh${NC}"
            fi
            echo -e "\n${BLUE}An Enter de quay lai...${NC}"; read -r ;; # Them -r
        2)
            if [[ -f "$BASE_DIR/install_wp.sh" ]]; then
                bash "$BASE_DIR/install_wp.sh"
            else
                echo -e "${RED}Loi: Khong tim thay file install_wp.sh${NC}"
            fi
            echo -e "\n${BLUE}An Enter de quay lai...${NC}"; read -r ;; # Them -r
        3)
            if [[ -f "$BASE_DIR/remove_web.sh" ]]; then
                bash "$BASE_DIR/remove_web.sh"
            else
                echo -e "${RED}Loi: Khong tim thay file remove_web.sh${NC}"
            fi
            echo -e "\n${BLUE}An Enter de quay lai...${NC}"; read -r ;; # Them -r
        0)
            exit 0 ;;
        *)
            echo -e "${RED}Sai lua chon!${NC}"; sleep 1 ;;
    esac
done