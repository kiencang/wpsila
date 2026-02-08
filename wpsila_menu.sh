#!/bin/bash

# -----------------------------------------------------------
# Menu điều khiển cho wpsila
# File: wpsila_menu.sh
# File này được tải mỗi khi gõ wpsila trong VPS
# -----------------------------------------------------------

# +++

# -------------------------------------------------------------------------------------------------------------------------------
# A. Cấu hình & Định nghĩa
# -------------------------------------------------------------------------------------------------------------------------------
# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Thư mục gốc (Canonical path)
BASE_DIR=$(dirname "$(readlink -f "$0")")

# -------------------------------------------------------------------------------------------------------------------------------
# B. Kiểm tra quyền ROOT
# -------------------------------------------------------------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
   sudo -E "$0" "$@"
   exit $?
fi

# -------------------------------------------------------------------------------------------------------------------------------
# C. Các hàm hỗ trợ (Helper Functions)
# -------------------------------------------------------------------------------------------------------------------------------

# Hàm tạm dừng màn hình
pause_screen() {
    echo -e "\n${BLUE}>> Nhan Enter de quay lai Menu...${NC}"
    read -r
}

# Hàm thực thi script con an toàn
# Sử dụng: run_script "tên_file.sh" [tham_số_1] [tham_số_2]
run_script() {
    local script_name="$1"
    shift # Đẩy tham số $1 ra, các tham số còn lại ($@) sẽ là tham số cho script con
    local script_path="$BASE_DIR/$script_name"

    if [[ -f "$script_path" ]]; then
        # Cấp quyền thực thi (phòng trường hợp mất quyền x)
        chmod +x "$script_path" 
        # Chạy script
        bash "$script_path" "$@"
    else
        echo -e "${RED}LOI: Khong tim thay file $script_name tai: $BASE_DIR${NC}"
    fi
    
    pause_screen
}

# Hiển thị Menu
show_menu() {
    clear
    echo -e "${BLUE}===============================================================${NC}"
    echo -e "${GREEN}                   WPSILA WORDPRESS BLOG                   ${NC}"
    echo -e "${BLUE}===============================================================${NC}"
    echo -e "  ${YELLOW}1.${NC} <Cai dat Caddy Web Server (mot lan la du)>"
    echo -e "  ${YELLOW}2.${NC} <Toi uu he thong (mot lan la du)>"
    echo -e "${BLUE}---------------------------------------------------------------${NC}"
    echo -e "  ${YELLOW}3.${NC} >> Cai dat Website WordPress moi"
    echo -e "  4. >> Xem pass WordPress vua tao"
    echo -e "${BLUE}---------------------------------------------------------------${NC}"
    echo -e "  ${YELLOW}5.${NC} >> Them tai khoan sFTP"
    echo -e "  6. >> Xem pass sFTP"
    echo -e "${BLUE}---------------------------------------------------------------${NC}"
    echo -e "  ${YELLOW}7.${NC} >> Cai dat Subdomain WordPress"
    echo -e "${BLUE}---------------------------------------------------------------${NC}"
    echo -e "  ${YELLOW}8.${NC} >> Xoa (delete) Website WordPress"
    echo -e "${BLUE}---------------------------------------------------------------${NC}"
    echo -e "  ${YELLOW}9.${NC} >> Cai dat Adminer (Quan ly Database)"
    echo -e " 10. >> Xem pass Adminer"
    echo -e "${BLUE}---------------------------------------------------------------${NC}"
    echo -e " ${YELLOW}11.${NC} >> Kiem tra cap nhat (update) wpsila"
    echo -e "${BLUE}---------------------------------------------------------------${NC}"    
    echo -e " ${YELLOW}12.${NC} >> Khoa/Mo khoa wp-config.php (De sua file/cai plugin)"
    echo -e "${BLUE}---------------------------------------------------------------${NC}"
    echo -e " ${YELLOW}13.${NC} >> Xem Log thoi gian thuc (Debug loi 500/502)"
    echo -e "${BLUE}---------------------------------------------------------------${NC}"
    echo -e "  ${YELLOW}0.${NC} >> Exit (Thoat)"
    echo -e "${BLUE}===========================================================${NC}"
    echo -n "Nhap lua chon (0-13): "
}

# -------------------------------------------------------------------------------------------------------------------------------
# D. Vòng lặp chính
# -------------------------------------------------------------------------------------------------------------------------------
while true; do
    show_menu
    read -r choice
    echo "" # Xuống dòng cho đẹp
    
    case $choice in
        1) run_script "install_lcmp.sh" ;;
        
        2) 
            # Case đặc biệt chạy nhiều script nối tiếp
            echo -e "${GREEN}>> Dang chay toi uu MariaDB...${NC}"
            if [[ -f "$BASE_DIR/tune_mariadb.sh" ]]; then bash "$BASE_DIR/tune_mariadb.sh"; fi
            
            echo -e "${GREEN}>> Dang chay toi uu PHP INI...${NC}"
            if [[ -f "$BASE_DIR/tune_php.sh" ]]; then bash "$BASE_DIR/tune_php.sh"; fi
            
            echo -e "${GREEN}>> Dang chay toi uu PHP Pool...${NC}"
            if [[ -f "$BASE_DIR/tune_pool.sh" ]]; then bash "$BASE_DIR/tune_pool.sh"; fi

            echo -e "${GREEN}>> Dang kiem tra va tao Swap...${NC}"
            if [[ -f "$BASE_DIR/setup_swap.sh" ]]; then bash "$BASE_DIR/setup_swap.sh"; fi

            echo -e "${GREEN}>> Dang cai dat Fail2Ban Security Core...${NC}"
            if [[ -f "$BASE_DIR/setup_fail2ban_core.sh" ]]; then bash "$BASE_DIR/setup_fail2ban_core.sh"; fi		
            
            pause_screen 
            ;;
            
        3) run_script "install_wp.sh" ;;
        
        4) run_script "show_pass.sh" "wpp.txt" ;; # Truyền tham số wpp.txt
        
        5) run_script "setup_sftp.sh" ;;
        
        6) run_script "show_pass.sh" "sftpp.txt" ;;
        
        7) run_script "install_wp.sh" "subdomain" ;; # Tái sử dụng script install_wp
        
        8) run_script "remove_web.sh" ;;
        
        9) run_script "setup_adminer.sh" ;;
        
        10) run_script "show_pass.sh" "adminerp.txt" ;;
        
        11) run_script "check_for_update.sh" ;;
		
		12)
            echo -e "${GREEN}=== QUAN LY QUYEN GHI FILE WP-CONFIG.PHP ===${NC}"
            read -r -p "Nhap ten mien (VD: example.com, blog.example.com): " INPUT_DOMAIN
            
            # Chuan hoa ten mien (xoa khoang trang, chu thuong)
			TEMP_DOMAIN=$(echo "$INPUT_DOMAIN" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
			DOMAIN=$(echo "$TEMP_DOMAIN" | sed -E 's|^https?://||' | sed -E 's|/.*$||' | sed -E 's|:[0-9]+$||')
			
			if [[ -z "$DOMAIN" ]]; then
                 echo -e "${RED}Loi: Ten mien khong duoc de trong!${NC}"
                 pause_screen
                 continue # Quay lai menu chinh thay vi thoat script
			fi 
			
            CONFIG_FILE="/var/www/$DOMAIN/public_html/wp-config.php"

            if [[ -f "$CONFIG_FILE" ]]; then
                echo -e "Trang thai hien tai: $(stat -c '%a' "$CONFIG_FILE") (640=Khoa, 660=Mo)"
                echo "------------------------------------------------"
                echo "1. MO KHOA (Chmod 660)"
                echo "   => Cho phep plugin ghi file wp-config.php, cho phep sua qua sFTP."
                echo "2. KHOA LAI (Chmod 640) - KHUYEN DUNG"
                echo "   => Bao mat tuyet doi. Plugin va sFTP chi duoc doc (khong duoc ghi) wp-config.php."
                echo "------------------------------------------------"
                read -r -p "Chon thao tac (1/2): " ACTION

                if [[ "$ACTION" == "1" ]]; then
                    # Cap quyen 660: Owner(root) RW, Group(www-data) RW
                    chmod 660 "$CONFIG_FILE"
                    echo -e "${RED}>> DA MO KHOA (UNLOCKED)!${NC}"
                    echo "Bay gio ban co the sua file wp-config.php qua sFTP hoac cho phep plugin sua wp-config.php."
                    echo "NHO KHOA LAI wp-config.php SAU KHI XONG VIEC!"
                elif [[ "$ACTION" == "2" ]]; then
                    # Cap quyen 640: Owner(root) RW, Group(www-data) R
                    chmod 640 "$CONFIG_FILE"
                    echo -e "${GREEN}>> DA KHOA LAI (LOCKED)!${NC}"
                    echo "File wp-config.php da duoc bao ve an toan."
                else
                    echo -e "${YELLOW}Huy thao tac.${NC}"
                fi
            else
                echo -e "${RED}Loi: Khong tim thay file wp-config.php tai:${NC}"
                echo "$CONFIG_FILE"
                echo "Vui long kiem tra lai ten mien."
            fi
            pause_screen
            ;;
			
		13)
            echo -e "${GREEN}=== XEM LOG THOI GIAN THUC (LIVE LOGS) ===${NC}"
            echo -e "Cong cu nay giup ban xem loi Website hoac PHP ngay lap tuc."
            echo "------------------------------------------------"
            
            # 1. Nhap ten mien
            read -r -p "Nhap ten mien (VD: example.com): " INPUT_DOMAIN
            
            # 2. Chuan hoa ten mien (Input Sanitization - Code chuan)
            TEMP_DOMAIN=$(echo "$INPUT_DOMAIN" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
            DOMAIN=$(echo "$TEMP_DOMAIN" | sed -E 's|^https?://||' | sed -E 's|/.*$||' | sed -E 's|:[0-9]+$||')
            
            if [[ -z "$DOMAIN" ]]; then
                 echo -e "${RED}Loi: Ten mien khong duoc de trong!${NC}"
                 pause_screen
                 continue
            fi
            
            # 3. Xac dinh cac file log quan trong
            ACCESS_LOG="/var/www/$DOMAIN/logs/access.log"
            
            # Tu dong tim file log cua PHP-FPM (do phien ban co the khac nhau)
            # Tim file co dang php*-fpm.log trong /var/log/
            PHP_LOG=$(find /var/log -name "php*-fpm.log" | head -n 1)

            echo "------------------------------------------------"
            echo "Chon loai Log muon xem:"
            echo "1. Xem Access/Error Log cua Website ($DOMAIN)"
            echo "   -> Xem ai dang truy cap, loi 403, 404, 500 tu Web Server."
            echo "2. Xem PHP System Log (Global)"
            echo "   -> Xem loi he thong PHP, loi 502 Bad Gateway, PHP Crash."
            echo "------------------------------------------------"
            read -r -p "Nhap lua chon (1/2): " LOG_CHOICE

            TARGET_LOG=""

            if [[ "$LOG_CHOICE" == "1" ]]; then
                TARGET_LOG="$ACCESS_LOG"
            elif [[ "$LOG_CHOICE" == "2" ]]; then
                if [[ -z "$PHP_LOG" ]]; then
                    echo -e "${RED}Loi: Khong tim thay file log cua PHP-FPM!${NC}"
                    pause_screen
                    continue
                fi
                TARGET_LOG="$PHP_LOG"
            else
                echo -e "${YELLOW}Lua chon khong hop le.${NC}"
                pause_screen
                continue
            fi

            # 4. Thuc thi xem log
            if [[ -f "$TARGET_LOG" ]]; then
                echo -e "${GREEN}>> DANG MO LOG TAI: $TARGET_LOG${NC}"
                echo -e "${YELLOW}!!! NHAN TO HOP PHIM [Ctrl + C] DE THOAT KHOI MAN HINH LOG !!!${NC}"
                echo "..."
                sleep 2
                
                # Lenh tail -f se giu man hinh luon mo
                tail -f -n 50 "$TARGET_LOG"
                
                # Sau khi nguoi dung bam Ctrl+C, lenh tail dung lai, script chay tiep xuong duoi
                echo -e "\n${GREEN}>> Da thoat che do xem Log.${NC}"
            else
                echo -e "${RED}Loi: Khong tim thay file log!${NC}"
                echo "Duong dan: $TARGET_LOG"
                echo "Co the Website chua duoc cai dat hoac chua co truy cap nao."
            fi
            
            pause_screen
            ;;			
        
        0) echo -e "${GREEN}Tam biet!${NC}"; exit 0 ;;
        
        *) echo -e "${RED}Lua chon khong hop le! Vui long chon lai.${NC}"; sleep 1 ;;
    esac
done