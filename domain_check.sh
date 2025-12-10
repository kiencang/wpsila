# -----------------------------------------------------------
# MODULE: Kiểm tra tên miền nhập vào của người dùng
# File này được nhúng vào script install_wp.sh
# -----------------------------------------------------------

if [ "$INSTALL_TYPE" != "subdomain" ]; then
	echo -e "${GREEN}>>> Vui long nhap ten mien cua ban (vi du: example.com):${NC}"
fi

if [ "$INSTALL_TYPE" == "subdomain" ]; then
	echo -e "${GREEN}>>> Vui long nhap SubDomain cua ban (vi du: hello.example.com):${NC}"
fi

# E1. Cấu hình số lần thử tối đa
MAX_RETRIES=3
COUNT=0
DOMAIN=""

# E2. Bắt đầu vòng lặp nhập liệu
while [[ $COUNT -lt $MAX_RETRIES ]]; do
    COUNT=$((COUNT + 1)) 
    
    if [[ $COUNT -eq 1 ]]; then
        read -p "Nhap Domain: " INPUT_DOMAIN < /dev/tty
    else
        echo -e "${RED}Ban vua nhap sai! Hay chu y nhap lai dung nhe.${NC}"
        read -p "Nhap Domain: " INPUT_DOMAIN < /dev/tty
    fi
    
    # Xử lý chuỗi
    TEMP_DOMAIN=$(echo "$INPUT_DOMAIN" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    DOMAIN=$(echo "$TEMP_DOMAIN" | sed -e 's|^https\?://||' -e 's|/.*$||')
    
    # Validation cơ bản
    if [[ -z "$DOMAIN" ]]; then
        echo -e "${RED}Loi: Ten mien khong duoc de trong!${NC}"
    elif [[ "$DOMAIN" != *"."* ]]; then
        echo -e "${RED}Loi: Ten mien '$DOMAIN' khong hop le (thieu dau cham).${NC}"
    else
        if [[ "$INPUT_DOMAIN" != "$DOMAIN" ]]; then
             echo -e "${GREEN}Script da tu dong chuan hoa input '${INPUT_DOMAIN}' thanh '${DOMAIN}'${NC}"
        fi
        break
    fi

    if [[ $COUNT -eq $MAX_RETRIES ]]; then
        echo -e "${RED}Ban da nhap sai qua 3 lan. Dung script.${NC}"
        exit 1
    else
        echo "Vui long thu lai..."
        echo "-------------------------"
    fi
done

# --- BƯỚC MỚI: KIỂM TRA TỒN TẠI (QUAN TRỌNG) ---
echo "Dang kiem tra an toan he thong..."

# Không phải subdomain mới cần xác định chuyển hướng
if [ "$INSTALL_TYPE" != "subdomain" ]; then
	# Xác định luôn dạng chuyển hướng của tên miền để tiện kiểm tra thư mục web gốc
	if [[ "$DOMAIN" == www.* ]]; then
		RED_DOMAIN="${DOMAIN#www.}"
	else
		RED_DOMAIN="www.$DOMAIN"
	fi
fi

# Định nghĩa đường dẫn
# Thư mục tên miền người dùng nhập vào
WEB_ROOT_DIR_CHECK="/var/www/$DOMAIN"

if [ "$INSTALL_TYPE" != "subdomain" ]; then
	# Dự phòng thư mục tên miền chuyển hướng
	# Chỉ phải check khi kiểu cài đặt không phải là dạng subdomain
	WEB_ROOT_DIR_CHECK_RED="/var/www/$RED_DOMAIN"
fi

# Đường dẫn tới file Caddyfile của Webserver, phải ghi đè vào đường dẫn này
CADDY_CONF_CHECK="/etc/caddy/Caddyfile" 

# 1. Kiểm tra trong Caddyfile (Deep Scan Check)
if [ -f "$CADDY_CONF_CHECK" ]; then
    # Regex Explained:
    # (^|[[:space:]/])      : Bắt đầu dòng, khoảng trắng hoặc dấu /
    # $DOMAIN               : Tên miền
    # ([[:space:],:]|\{|$)  : Kết thúc bằng khoảng trắng, dấu phẩy (,), dấu hai chấm (:) hoặc dấu {
    
    if grep -Eq "(^|[[:space:]/])$DOMAIN([[:space:],:]|\{|$)" "$CADDY_CONF_CHECK"; then
        echo -e "${RED}NGUY HIEM: Ten mien [$DOMAIN] da duoc cau hinh trong Caddyfile!${NC}"
        echo -e "Script phat hien ten mien nay da ton tai (co the kem theo port hoac trong danh sach)."
        echo -e "Vui long kiem tra file $CADDY_CONF_CHECK va xoa cau hinh cu truoc khi chay lai."
        exit 1
    fi
fi

# 2. Kiểm tra thư mục Web
if [ -d "$WEB_ROOT_DIR_CHECK" ]; then
    echo -e "${RED}NGUY HIEM: Thu muc web [$WEB_ROOT_DIR_CHECK] da ton tai!${NC}"
    echo -e "Viec tiep tuc co the ghi de du lieu cu."
    echo -e "Vui long xoa thu muc thu cong hoac chon ten mien khac."
    exit 1
fi

# Không phải dạng subdomain mới cần kiểm tra
if [ "$INSTALL_TYPE" != "subdomain" ]; then

	if [ -d "$WEB_ROOT_DIR_CHECK_RED" ]; then
		echo -e "${RED}NGUY HIEM: Thu muc web [$WEB_ROOT_DIR_CHECK_RED] da ton tai!${NC}"
		echo -e "Viec tiep tuc co the gay nham lan."
		echo -e "Vui long xoa thu muc thu cong hoac chon ten mien khac."
		exit 1
	fi
	
fi

echo -e "${GREEN}Kiem tra an toan hoan tat.${NC}"
# -----------------------------------------------

# --- Script tiếp tục chạy từ đây khi dữ liệu đã đúng ---
if [ "$INSTALL_TYPE" != "subdomain" ]; then
	echo -e "Thanh cong! Ten mien duoc chap nhan: $DOMAIN"
	echo -e "${GREEN}>>> Dang tien hanh cai dat cho domain: ${YELLOW}$DOMAIN${NC}"
fi

# Thông báo cho trường hợp là subdomain
if [ "$INSTALL_TYPE" == "subdomain" ]; then
	echo -e "Thanh cong! SubDomain duoc chap nhan: $DOMAIN"
	echo -e "${GREEN}>>> Dang tien hanh cai dat cho subdomain: ${YELLOW}$DOMAIN${NC}"
fi

sleep 2