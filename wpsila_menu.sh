#!/bin/bash

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# A. Cấu hình màu sắc 
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# B. Định nghĩa thư mục gốc 
BASE_DIR=$(dirname "$(readlink -f "$0")")

# Kiểm tra quyền
# NÂNG QUYỀN NẾU KHÔNG PHẢI LÀ ROOT (cho nhóm có quyền gọi sudo)
# 1. Kiểm tra xem đang chạy với quyền gì
if [[ $EUID -ne 0 ]]; then
   # 2. Nếu không phải root, tự động chạy lại script này bằng sudo
   sudo "$0" "$@"
   # 3. Thoát tiến trình cũ (không phải root) để tiến trình mới (có root) chạy
   exit $?
fi
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# C. Hiển thị menu
show_menu() {
    clear
    echo -e "${BLUE}========================================================${NC}"
    echo -e "${GREEN}            WPSILA MANAGER (Local Version)              ${NC}"
    echo -e "${BLUE}========================================================${NC}"
    echo -e "${YELLOW}1.${NC} <Cai dat (install) Caddy Web Server (mot lan la du)>"
	echo -e "${YELLOW}2.${NC} <Toi uu he thong (mot lan la du)>"
	echo -e "${BLUE}--------------------------------------------------------${NC}"
    echo -e "${YELLOW}3.${NC} >> Cai dat (install) website WordPress moi"
	echo -e "${YELLOW}4.${NC} >> Xem thong tin pass cua trang WordPress vua tao"
	echo -e "${YELLOW}5.${NC} >> Them tai khoan sFTP cho website"
	echo -e "${BLUE}--------------------------------------------------------${NC}"
	echo -e "${YELLOW}6.${NC} >> Cai dat (install) subdomain WordPress moi"	
	echo -e "${BLUE}--------------------------------------------------------${NC}"	
    echo -e "${YELLOW}7.${NC} >> Xoa cai dat (delete) website WordPress"
    echo -e "${BLUE}--------------------------------------------------------${NC}"
    echo -e "${YELLOW}8.${NC} >> Cai dat quan ly database (can thi moi cai)"
    echo -e "${BLUE}--------------------------------------------------------${NC}"	
    echo -e "${YELLOW}0.${NC} >> Exit (thoat)"
    echo -e "${BLUE}========================================================${NC}"
    echo -n "Nhap lua chon (chon so): "
}
# -------------------------------------------------------------------------------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# D. Vòng lặp
while true; do
    show_menu
    read -r choice  # Them -r cho an toan
    case $choice in
        1)
            if [[ -f "$BASE_DIR/install_lcmp.sh" ]]; then
                bash "$BASE_DIR/install_lcmp.sh"
            else
                echo -e "${RED}Loi: Khong tim thay file install_lcmp.sh${NC}"
            fi
            echo -e "\n${BLUE}An Enter de quay lai...${NC}"; read -r ;; # Them -r
        2)
            if [[ -f "$BASE_DIR/mariadb_tune.sh" && -f "$BASE_DIR/php_ini_tune.sh" && -f "$BASE_DIR/pool_tune.sh" ]]; then
                echo -e "${GREEN}>> Dang chay toi uu MariaDB...${NC}"
                bash "$BASE_DIR/mariadb_tune.sh" && \
                
                echo -e "${GREEN}>> Dang chay toi uu PHP INI...${NC}"
                bash "$BASE_DIR/php_ini_tune.sh" && \
                
                echo -e "${GREEN}>> Dang chay toi uu PHP Pool...${NC}"
                bash "$BASE_DIR/pool_tune.sh"
            else
                echo -e "${RED}Loi: Khong tim thay file cai dat toi uu.${NC}"
            fi
            echo -e "\n${BLUE}An Enter de quay lai...${NC}"; read -r ;; # Them -r					
        3)
            if [[ -f "$BASE_DIR/install_wp.sh" ]]; then
                bash "$BASE_DIR/install_wp.sh"
            else
                echo -e "${RED}Loi: Khong tim thay file install_wp.sh${NC}"
            fi
            echo -e "\n${BLUE}An Enter de quay lai...${NC}"; read -r ;; # Them -r	
        4)
            if [[ -f "$BASE_DIR/wpp.sh" ]]; then
                bash "$BASE_DIR/wpp.sh"
            else
                echo -e "${RED}Loi: Khong tim thay file wpp.sh${NC}"
            fi
            echo -e "\n${BLUE}An Enter de quay lai...${NC}"; read -r ;; # Them -r				
        5)
            if [[ -f "$BASE_DIR/setup_sftp.sh" ]]; then
                bash "$BASE_DIR/setup_sftp.sh"
            else
                echo -e "${RED}Loi: Khong tim thay file setup_sftp.sh${NC}"
            fi
            echo -e "\n${BLUE}An Enter de quay lai...${NC}"; read -r ;; # Them -r
        6)
            if [[ -f "$BASE_DIR/install_wp.sh" ]]; then
                bash "$BASE_DIR/install_wp.sh" subdomain
            else
                echo -e "${RED}Loi: Khong tim thay file install_wp.sh${NC}"
            fi
            echo -e "\n${BLUE}An Enter de quay lai...${NC}"; read -r ;; # Them -r				
        7)
            if [[ -f "$BASE_DIR/remove_web.sh" ]]; then
                bash "$BASE_DIR/remove_web.sh"
            else
                echo -e "${RED}Loi: Khong tim thay file remove_web.sh${NC}"
            fi
            echo -e "\n${BLUE}An Enter de quay lai...${NC}"; read -r ;; # Them -r
        8)
            if [[ -f "$BASE_DIR/setup_adminer.sh" ]]; then
                bash "$BASE_DIR/setup_adminer.sh"
            else
                echo -e "${RED}Loi: Khong tim thay file setup_adminer.sh${NC}"
            fi
            echo -e "\n${BLUE}An Enter de quay lai...${NC}"; read -r ;; # Them -r			
        0)
            exit 0 ;;
        *)
            echo -e "${RED}Sai lua chon!${NC}"; sleep 1 ;;
    esac
done
# -------------------------------------------------------------------------------------------------------------------------------