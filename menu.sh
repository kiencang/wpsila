#!/bin/bash

# --- Cấu hình màu sắc ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Định nghĩa thư mục gốc ---
# Lấy đường dẫn nơi chứa file script này (thường là /opt/wpsila)
BASE_DIR=$(dirname "$(readlink -f "$0")")

# Kiểm tra quyền Root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Lỗi: Bạn phải chạy script này với quyền Root!${NC}" 
   exit 1
fi

show_menu() {
    clear
    echo -e "${BLUE}================================================${NC}"
    echo -e "${GREEN}    WPSILA MANAGER (Local Version)              ${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo -e "${YELLOW}1.${NC} Cài đặt Caddy Web Server"
    echo -e "${YELLOW}2.${NC} Cài đặt Website WordPress mới"
    echo -e "${YELLOW}3.${NC} Gỡ cài đặt (Xóa) Website WordPress"
    echo -e "${BLUE}------------------------------------------------${NC}"
    echo -e "${YELLOW}8.${NC} Cập nhật toàn bộ công cụ (Update All)"
    echo -e "${YELLOW}0.${NC} Thoát"
    echo -e "${BLUE}================================================${NC}"
    echo -n "Nhập lựa chọn: "
}

# Hàm cập nhật (Tải đè lại toàn bộ các file mới nhất từ GitHub về thư mục Local)
update_tool() {
    echo -e "${BLUE}Đang tải phiên bản mới nhất về máy...${NC}"
    
    # URL gốc trên GitHub (Thay bằng link repo của bạn)
    REPO_URL="https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main"
    
    # Tải và ghi đè các file
    wget -q "$REPO_URL/menu.sh" -O "$BASE_DIR/menu.sh"
    wget -q "$REPO_URL/install_caddy.sh" -O "$BASE_DIR/install_caddy.sh"
    wget -q "$REPO_URL/install_wp.sh" -O "$BASE_DIR/install_wp.sh"
    wget -q "$REPO_URL/remove_web.sh" -O "$BASE_DIR/remove_web.sh"
    
    # Cấp quyền lại cho chắc chắn
    chmod 700 "$BASE_DIR/"*.sh
    
    echo -e "${GREEN}Cập nhật hoàn tất! Khởi động lại menu...${NC}"
    sleep 1
    exec "$BASE_DIR/menu.sh"
}

while true; do
    show_menu
    read choice
    case $choice in
        1)
            # Gọi file cục bộ
            if [[ -f "$BASE_DIR/install_caddy.sh" ]]; then
                bash "$BASE_DIR/install_caddy.sh"
            else
                echo -e "${RED}Lỗi: Không tìm thấy file install_caddy.sh${NC}"
            fi
            echo -e "\n${BLUE}Ấn Enter để quay lại...${NC}"; read ;;
        2)
            if [[ -f "$BASE_DIR/install_wp.sh" ]]; then
                bash "$BASE_DIR/install_wp.sh"
            else
                echo -e "${RED}Lỗi: Không tìm thấy file install_wp.sh${NC}"
            fi
            echo -e "\n${BLUE}Ấn Enter để quay lại...${NC}"; read ;;
        3)
            if [[ -f "$BASE_DIR/remove_web.sh" ]]; then
                bash "$BASE_DIR/remove_web.sh"
            else
                echo -e "${RED}Lỗi: Không tìm thấy file remove_web.sh${NC}"
            fi
            echo -e "\n${BLUE}Ấn Enter để quay lại...${NC}"; read ;;
        8)
            update_tool ;;
        0)
            exit 0 ;;
        *)
            echo -e "${RED}Sai lựa chọn!${NC}"; sleep 1 ;;
    esac
done