Version của bash script: v1.0.0
---
Website: https://wpsila.com

Đây là công cụ **cài nhanh blog WordPress trên VPS** (chỉ blog & nói chung là website không bao gồm giỏ hàng).

- Yêu cầu hệ thống: **Ubuntu LTS 24.04** hoặc 22.04, cài mới trên VPS (tức là bạn chưa có bất cứ website nào hoặc cài bất cứ chương trình gì ngoài Ubuntu trên VPS đó).
- RAM tối thiểu 1GB.

Các đoạn mã đang trong giai đoạn thử nghiệm, chỉ cài nó trên website demo của bạn.

Cài đặt với quyền root: 

```bash
curl -sL https://vps.wpsila.com | sudo bash
```

Quá trình viết code có tham khảo gợi ý từ Gemini.

## Hướng dẫn sử dụng

Sau khi nhập lệnh trên vào VPS, nó sẽ tải các file cài đặt về.

Bạn sẽ thấy tiến trình nhu bên dưới

```
=== DANG CAI DAT WPSILA ===
[OK] He dieu hanh hop le: Ubuntu 24.04.3 LTS
Tat ca cac goi phu thuoc da co san.
Dang lam sach thu muc cai dat...
Dang tai cac module...
[CHECKSUM OK] check_for_update.sh
[CHECKSUM OK] install_caddyserver.sh
[CHECKSUM OK] install_mariadb.sh
[CHECKSUM OK] wpsila_menu.sh
[CHECKSUM OK] caddyfile.sh
[CHECKSUM OK] domain_check.sh
[CHECKSUM OK] install_php.sh
[CHECKSUM OK] setup_sftp.sh
[CHECKSUM OK] wpsila.conf
[CHECKSUM OK] show_pass.sh
[CHECKSUM OK] remove_web.sh
[CHECKSUM OK] setup_adminer.sh
[CHECKSUM OK] tune_pool.sh
[CHECKSUM OK] tune_mariadb.sh
[CHECKSUM OK] tune_php.sh
[CHECKSUM OK] database_user_wp.sh
[CHECKSUM OK] anti_apt_lock.sh
[CHECKSUM OK] install_wp.sh
[CHECKSUM OK] caddyfile_subdomain.sh
[CHECKSUM OK] install_lcmp.sh
[CHECKSUM OK] wordpress.sh
=== CAI DAT THANH CONG! ===
Phien ban: v1.0.0
Xin chuc mung ban! Hay go lenh: wpsila de bat dau su dung.
```

## Gợi ý các theme & plugin nên dùng cùng với wpsila

wpsila có thể dùng kèm với *bất kỳ theme & plugin nào*, tuy vậy chúng tôi gợi ý bạn nên dùng các theme & plugin dưới đây để đảm bảo website an toàn & có hiệu suất cao:

- Giao diện: GeneratePress (https://wordpress.org/themes/generatepress/)
- Plugin tăng tốc (cache): Cache Enabler (https://wordpress.org/plugins/cache-enabler/)
- Plugin tối ưu máy tìm kiếm: The SEO Framework (https://wordpress.org/plugins/autodescription/)
- Plugin backup: UpdraftPlus (https://wordpress.org/plugins/updraftplus/)

Ngoài ra các tính năng bảo mật miễn phí của Cloudflare (https://www.cloudflare.com/) cũng rất hợp với người dùng WordPress làm blog, nó dễ triển khai và có chất lượng cao.

**Chú ý**: Các công cụ trên chỉ là gợi ý, wpsila không có bất cứ ràng buộc nào là bạn phải dùng theme hay plugin cụ thể nào đó.

## Tuyên bố miễn trừ trách nhiệm (Disclaimer)

Script này được cung cấp miễn phí và mã nguồn mở. Mặc dù tôi đã cố gắng hết sức để kiểm tra kỹ lưỡng, nhưng việc sử dụng script này hoàn toàn thuộc về rủi ro của bạn (Use at your own risk).

Tác giả không chịu trách nhiệm cho bất kỳ thiệt hại nào liên quan đến:

- Mất mát dữ liệu.

- Lỗi cấu hình hệ thống.

- Các vấn đề bảo mật phát sinh.

Tuyên bố miễn trừ trách nhiệm đầy đủ được tôi công bố tại đây: https://wpsila.com/disclaimer
