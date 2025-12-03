#!/bin/bash

# --- Cấu hình màu sắc cho đẹp ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Kiểm tra quyền Root ---
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Lỗi: Bạn phải chạy script này với quyền Root!${NC}" 
   exit 1
fi

# --- Hàm hiển thị Menu ---
show_menu() {
    clear
    echo -e "${BLUE}================================================${NC}"
    echo -e "${GREEN}    WPSILA MANAGER - QUẢN LÝ WORDPRESS & CADDY  ${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo -e "${YELLOW}1.${NC} Cài đặt Caddy Web Server"
    echo -e "${YELLOW}2.${NC} Cài đặt Website WordPress mới"
    echo -e "${YELLOW}3.${NC} Gỡ cài đặt (Xóa) Website WordPress"
    echo -e "${YELLOW}0.${NC} Thoát"
    echo -e "${BLUE}================================================${NC}"
    echo -n "Nhập lựa chọn của bạn [0-3]: "
}

# --- Hàm xử lý logic ---
while true; do
    show_menu
    read choice
    
    case $choice in
        1)
            echo -e "${GREEN}Đang khởi chạy script cài đặt Caddy...${NC}"
            bash <(curl -sL https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main/install_caddy.sh)
            echo -e "\n${BLUE}Ấn Enter để quay lại menu chính...${NC}"
            read
            ;;
        2)
            echo -e "${GREEN}Đang khởi chạy script cài đặt WordPress...${NC}"
            bash <(curl -sL https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main/install_wp.sh)
            echo -e "\n${BLUE}Ấn Enter để quay lại menu chính...${NC}"
            read
            ;;
        3)
            echo -e "${GREEN}Đang khởi chạy script gỡ cài đặt Web...${NC}"
            bash <(curl -sL https://raw.githubusercontent.com/kiencang/wpsila/refs/heads/main/remove_web.sh)
            echo -e "\n${BLUE}Ấn Enter để quay lại menu chính...${NC}"
            read
            ;;
        0)
            echo -e "${GREEN}Cảm ơn bạn đã sử dụng WPSILA! Tạm biệt.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Lựa chọn không hợp lệ! Vui lòng thử lại.${NC}"
            sleep 2
            ;;
    esac
done