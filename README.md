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

Trước khi thao tác, hãy tắt trình gõ tiếng Việt, hoặc để sang dạng tiếng Anh, để việc nhập dữ liệu đỡ nhầm lẫn.

Sau khi nhập lệnh trên vào VPS, nó sẽ tải các file cài đặt về.

Bạn sẽ thấy tiến trình như bên dưới:

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

Tiếp theo hãy gõ wpsila để vào menu điều khiển chính:

```
===========================================================
                   WPSILA WORDPRESS BLOG
===========================================================
  1. <Cai dat Caddy Web Server (mot lan la du)>
  2. <Toi uu he thong (mot lan la du)>
-----------------------------------------------------------
  3. >> Cai dat Website WordPress moi
  4. >> Xem pass WordPress vua tao
-----------------------------------------------------------
  5. >> Them tai khoan sFTP
  6. >> Xem pass sFTP
-----------------------------------------------------------
  7. >> Cai dat Subdomain WordPress
-----------------------------------------------------------
  8. >> Xoa (delete) Website WordPress
-----------------------------------------------------------
  9. >> Cai dat Adminer (Quan ly Database)
 10. >> Xem pass Adminer
-----------------------------------------------------------
 11. >> Kiem tra cap nhat (update) wpsila
-----------------------------------------------------------
  0. >> Exit (Thoat)
===========================================================
Nhap lua chon (0-11):
```

Ở đây bạn muốn chọn mục nào thì nhập số tương ứng cho mục đấy.

Tuy nhiên để bắt đầu sử dụng, bạn cần cài Caddy, PHP & MariaDB. Đây là nền tảng để bắt đầu sử dụng WordPress.

### **Bước 1:** Cài chương trình nền cho WordPress

Để cài, bạn nhấn số 1. Chương trình sẽ hỏi email của bạn, bạn cần nhập email đang sử dụng của bạn vào. Email dùng để lấy cấp phát https & dùng để đăng ký quản trị WordPress.

```
Da tim thay file cau hinh: /opt/kiencang-wpsila/wpsila.conf
Phien ban PHP se cai dat: 8.3
--------------------------------------------------------
Dang kiem tra moi truong VPS (Clean OS Check)...
[OK] Moi truong sach se.

Nhap Email quan tri (Bat buoc, day phai la email cua ban):
```

Sau khi bạn nhập email, chương trình sẽ bắt đầu cài đặt. Sẽ tốn khoảng 3-5 phút để hoàn tất quá trình này.

---

### **Bước 2:** Thực hiện các tối ưu cơ bản

Cài đặt xong bước 1, bạn nhấn Enter để quay lại các tùy chọn của menu.

Nhập số 2 để thiết lập cấu hình tối ưu cho PHP và database. Bước này rất nhanh, chỉ khoảng 10s là xong hết.

Lại nhấn Enter để quay lại menu.

Xong bước 1 & bước 2 là bạn xong nền tảng cho WordPress. Và bạn không cần lặp lại thao tác này nữa.

Bây giờ bạn sẽ chính thức cài đặt WordPress cho tên miền của bạn.

---

### **Bước 3:** Cài đặt trang WordPress đầu tiên

Trước khi bạn cài WordPress cho tên miền, bạn cần đảm bảo đã trỏ DNS của tên miền về IP của VPS. Cách nhanh chóng và đơn giản để làm việc này là sử dụng Cloudflare để trỏ, nhớ ở bước này cần tắt đám mây vàng đi để tên miền trỏ về IP thực của VPS.

Cả 2 bản ghi @ và www đều cần trỏ về IP của VPS. 

Nếu bạn dùng DNS của nhà cung cấp tên miền, thì tốc độ cập nhật thường sẽ chậm hơn Cloudflare, bạn cần dùng https://dnschecker.org/ để kiểm tra chắc chắn là nó đã cập nhật IP mới thì mới nên cài. Vì nếu chưa nhận IP mới, việc cấp phát https không thể diễn ra được. 

Nếu dùng Cloudflare để trỏ IP, việc này thường diễn ra rất nhanh, bạn thưởng chỉ cần đợi chưa tới 3 phút là tất cả sẽ được cập nhật.

OK, giờ chúng ta sẽ bắt đầu cài.

Bạn chọn số 3 để cài. Ở đây bạn cần nhập địa chỉ của trang, phải xác định rõ là địa chỉ có-www (ví dụ www.example.com) hay không-www (ví dụ example.com)

Chương trình sẽ mặc định chuyển hướng địa chỉ còn lại về địa chỉ chính thức. Ví dụ, nếu bạn chọn không-www làm địa chỉ chính, thì có-www sẽ được chuyển hướng về địa chỉ mặc định đó. Ngược lại cũng vậy.

Sau khi bạn nhập địa chỉ và Enter, quá trình cài đặt diễn ra rất nhanh, chỉ khoảng 30s là hoàn tất.

**Một số lưu ý:**

- Username mặc định để đăng nhập WordPress là admin
- Email mặc định là email bạn khai báo ở bước 1
- Pass chương trình sẽ tạo một chuỗi ngẫu nhiên và được lưu lại. Bạn có thể xem pass bằng cách quay lại menu điều khiển và nhập số 4
- Lưu ý là bạn cần lưu lại pass này ngay, và nên đăng nhập để đổi thành pass khác nếu bạn muốn.

Như vậy là bạn đã tạo trang WordPress thành công. Giờ nếu bạn muốn thêm một số tính năng thì hãy theo dõi tiếp các bước tiếp theo.

Nếu muốn thêm một website WordPress khác vào VPS, bạn lặp lại các thao tác ở bước 3. 

**Lưu ý**: chỉ pass mới nhất mới xem lại được nên bạn cần chủ động lưu lại pass mỗi khi tạo trang mới.

---

### **Thêm tài khoản sFTP**

Tài khoản sFTP dùng để vào thư mục chính của website để tải lên hoặc xóa file. Bạn có thể tạo tài khoản này bằng cách nhấn số 5 ở menu điều khiển.

Chương trình sẽ hỏi bạn muốn tạo tài khoản sFTP cho địa chỉ website nào, bạn cần nhập đúng địa chỉ website muốn tạo vào.

Sau đó bạn nhập tên user cho tài khoản sFTP. Chương trình sẽ tự động tạo pass cho user này.

Để xem lại pass cho user sFPT, bạn nhập số 6 ở menu điều khiển chính. Lưu ý bạn phải chủ động lưu lại pass này, vì chương trình sẽ chỉ lưu pass gần nhất mà thôi (tức là nếu bạn tài khoản sFTP khác thì thông tin pass của tài khoản sFTP trước sẽ không thấy nữa, vì thế bạn cần chủ động lưu lại pass sau khi tạo).

---

### **Thêm trang web dạng subdomain**

Nếu bạn muốn thêm một trang WordPress dạng subdomain như hoctap.ten-mien-cua-ban.com thì bạn cần chọn mục số 7, lý do là vì địa chỉ dạng subdomain thì không cần chuyển hướng như kiểu có-www về không-www, do vậy bạn không nên dùng mục số 3 để cài.

Trước hết bạn cũng cần trỏ DNS của subdomain về IP của VPS. Sau đó nhập chính xác địa chỉ cần cài đặt vào rồi Enter.

Quá trình cài đặt sau đó cũng tương tự bước 3. Bạn cần lưu lại pass để đăng nhập khi cần (sau khi đăng nhập bạn nên đổi sang pass dễ nhớ mà bạn muốn).

---

### **Thêm tài khoản quản trị database**

Quản trị database (cơ sở dữ liệu) rất ít khi phải dùng so với việc tạo tài khoản sFTP. Do vậy nếu bạn cần thì mới nên cài.

Quản lý database cần một địa chỉ để bạn có thể truy cập, do vậy trước khi cài bạn cần phải trỏ DNS cho địa chỉ này, ví dụ db.ten-mien-cua-ban.com

Sau khi trỏ DNS xong (đợi khoảng 3 phút để nó cập nhật), bạn làm như sau:

- Nhập số 9 ở menu cài đặt chính.
- Nhập địa chỉ cho chương trình.
- Quá trình cài đặt sẽ rất nhanh, chưa đến 1 phút sẽ xong toàn bộ.

Pass sẽ được tạo tự động, và để an toàn, với phần quản trị database có 2 lớp pass được tạo ra:

- Lớp pass đầu tiên áp dụng khi bạn truy cập lần đầu, hoặc lâu lâu mới vào.
- Lớp pass thứ hai sẽ hỏi bất kỳ lần nào bạn yêu cầu vào quản trị.

Để xem các pass này, bạn hãy nhập số 10 ở menu quản trị chính. Hãy chủ động lưu lại các pass này để dùng khi cần.

---

### **Xóa một trang WordPress**

Để xóa một trang, bạn vào mục số 8 từ menu quản trị. Xin lưu ý rằng việc xóa này nó sẽ xóa toàn bộ dữ liệu của website tương ứng mà bạn muốn xóa, do vậy bạn cần phải **backup trước toàn bộ dữ liệu**.

Ở bước tiếp theo bạn nhập địa chỉ website muốn xóa, nếu địa chỉ bạn muốn xóa có tồn tại nó sẽ thông báo một số thông tin, và hỏi lần cuối xem bạn có chắc chắn muốn xóa không, ví dụ:

```
Nhap ten mien muon xoa (VD: example.com): dev.freehost.page
--- Dang quet thong tin website: dev.freehost.page ---
Da tim thay wp-config.php.
Phat hien Database: wp_0f695d1f53f578d1
Phat hien DB User:  u_60ab841a060d68

Ban co chac muon XOA VINH VIEN du lieu cua website? (y/n):
```

Nếu bạn nhập y, quá trình xóa sẽ được tiến hành. Nếu đổi ý, không muốn xóa, hãy nhập n.

Khi bạn đồng ý xóa, chương trình sẽ cố gắng tìm mọi dấu vết liên quan đến website và xóa nó khỏi hệ thống, ví dụ:

```
Dang xoa Database va User...
Da xoa Database & User thanh cong.
Dang xoa thu muc web: /var/www/dev.freehost.page ...
Da xoa thu muc /var/www/dev.freehost.page thanh cong.
Dang xoa chung chi cu cua dev.freehost.page...
Xoa thanh cong chung chi cu cua dev.freehost.page...
Khong tim thay chung chi cu cua www.dev.freehost.page (Co the chua duoc tao bao gio).
Dang xoa file cau hinh Caddy: /etc/caddy/sites-enabled/dev.freehost.page.caddy
Da xoa cau hinh Caddy va Reload thanh cong.
```

**Lưu ý lần cuối**: Vì đã xóa thì không vãn hồi được nữa, nên bạn bắt buộc phải backup dữ liệu trước khi xóa.

---

### **Kiểm tra cập nhật**

Để kiểm tra cập nhật cho wpsila, bạn nhấn số 11 ở menu chính, chương trình sẽ xem có phiên bản cài đặt mới nhất không. Nếu phiên bản cài đặt mới nhất phù hợp, nó sẽ cho phép tải về nếu bạn muốn.

Nếu phiên bản cài đặt mới nhất không phù hợp, chương trình sẽ thông báo, và bạn sẽ tiếp tục dùng phiên bản hiện tại.

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
