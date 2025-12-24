# -----------------------------------------------------------
# MODULE: Kiểm tra tên miền nhập vào của người dùng
# File: domain_check.sh
# File này được nhúng vào script install_wp.sh
# -----------------------------------------------------------

# E1. Cấu hình
MAX_RETRIES=3
COUNT=0
DOMAIN=""

# Thiết lập prompt dựa trên loại cài đặt
if [[ "$INSTALL_TYPE" == "subdomain" ]]; then
    PROMPT_TEXT="Nhap SubDomain (vi du: hello.example.com): "
    TYPE_TEXT="SubDomain"
else
    PROMPT_TEXT="Nhap ten mien (vi du: example.com): "
    TYPE_TEXT="Ten mien"
fi

echo -e "${GREEN}>>> Vui long nhap ${TYPE_TEXT} cua ban.${NC}"

# E2. Vòng lặp nhập liệu
while [[ $COUNT -lt $MAX_RETRIES ]]; do
    COUNT=$((COUNT + 1))
    
    # Chỉ hiển thị cảnh báo từ lần 2 trở đi
    if [[ $COUNT -gt 1 ]]; then
        echo -e "${RED}Loi: Dinh dang khong hop le. Vui long thu lai (${COUNT}/${MAX_RETRIES}).${NC}"
    fi

    read -r -p "$PROMPT_TEXT" INPUT_DOMAIN < /dev/tty

    # 1. Chuẩn hóa: Lowercase -> Xóa khoảng trắng -> Xóa protocol/path
    # Sửa regex sed để bắt chính xác hơn các trường hợp có port hoặc user:pass
    TEMP_DOMAIN=$(echo "$INPUT_DOMAIN" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
    DOMAIN=$(echo "$TEMP_DOMAIN" | sed -E 's|^https?://||' | sed -E 's|/.*$||' | sed -E 's|:[0-9]+$||')

    # 2. Validation chuyên sâu (Regex chuẩn RFC 1035/1123)
    # Giải thích Regex:
    # ^[a-z0-9]        : Bắt đầu bằng chữ hoặc số
    # ([-a-z0-9]*...   : Phần giữa có thể chứa gạch ngang
    # \.               : Phải có dấu chấm
    # [a-z]{2,}$       : TLD phải từ 2 ký tự trở lên (vd: .vn, .com)
    if [[ -z "$DOMAIN" ]]; then
         echo -e "${RED}Loi: Khong duoc de trong!${NC}"
    elif [[ ! "$DOMAIN" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*\.[a-z]{2,}$ ]]; then
         echo -e "${RED}Loi: Ten mien '$DOMAIN' chua ky tu khong hop le hoac sai dinh dang.${NC}"
    else
        # Input hợp lệ
        if [[ "$INPUT_DOMAIN" != "$DOMAIN" ]]; then
             echo -e "${GREEN}Script da tu dong chuan hoa input '${INPUT_DOMAIN}' thanh '${DOMAIN}'${NC}"
        fi
        break
    fi

    if [[ $COUNT -eq $MAX_RETRIES ]]; then
        echo -e "${RED}Ban da nhap sai qua 3 lan. Dung script.${NC}"
        exit 1
    fi
done

# --- BƯỚC MỚI: KIỂM TRA TỒN TẠI & AN TOÀN ---
echo "Dang kiem tra an toan he thong..."

WEB_ROOT_DIR_CHECK="/var/www/$DOMAIN"
CADDY_CONF_CHECK="/etc/caddy/Caddyfile"

# Xử lý logic www/non-www
WEB_ROOT_DIR_CHECK_RED=""
if [[ "$INSTALL_TYPE" != "subdomain" ]]; then
    if [[ "$DOMAIN" == www.* ]]; then
        RED_DOMAIN="${DOMAIN#www.}"
    else
        RED_DOMAIN="www.$DOMAIN"
    fi
    WEB_ROOT_DIR_CHECK_RED="/var/www/$RED_DOMAIN"
fi

# 1. Kiểm tra Caddyfile (Deep Scan & Ignore Comments)
if [[ -f "$CADDY_CONF_CHECK" ]]; then
    # Grep logic cải tiến:
    # ^[^#]* : Bắt đầu dòng KHÔNG phải dấu # (bỏ qua comment)
    # [[:space:]] : Domain thường đứng sau khoảng trắng hoặc đầu dòng
    if grep -Eq "^[^#]*([[:space:]]|^)$DOMAIN([[:space:]]|:|\{|$)" "$CADDY_CONF_CHECK"; then
        echo -e "${RED}NGUY HIEM: Ten mien [$DOMAIN] da duoc cau hinh trong Caddyfile!${NC}"
        echo -e "Script phat hien domain nay dang hoat dong (khong tinh dong comment)."
        exit 1
    fi
fi

# 2. Kiểm tra thư mục Web
if [[ -d "$WEB_ROOT_DIR_CHECK" ]]; then
    echo -e "${RED}NGUY HIEM: Thu muc web [$WEB_ROOT_DIR_CHECK] da ton tai!${NC}"
    exit 1
fi

if [[ -n "$WEB_ROOT_DIR_CHECK_RED" && -d "$WEB_ROOT_DIR_CHECK_RED" ]]; then
    echo -e "${RED}NGUY HIEM: Thu muc web redirection [$WEB_ROOT_DIR_CHECK_RED] da ton tai!${NC}"
    exit 1
fi

echo -e "${GREEN}Kiem tra an toan hoan tat.${NC}"

# --- KẾT THÚC MODULE ---
echo -e "Thanh cong! ${TYPE_TEXT} duoc chap nhan: $DOMAIN"
echo -e "${GREEN}>>> Dang tien hanh cai dat cho: ${YELLOW}$DOMAIN${NC}"
sleep 2