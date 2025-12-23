Phần này chỉ dành cho dev, không liên quan đến người dùng cuối.

Mỗi khi ra phiên bản mới cần làm như sau:
- Cập nhật version mới cho check_for_update.sh trong main (ví dụ v0.3.1)
- Trên GitHub, tạo phiên bản mới tương ứng với version vừa nhập trong check_for_update.sh
- Sử dụng generate_checksum để tạo checksum cho các file của phiên bản mới (ví dụ dùng WSL trên Windows bash ./generate_checksum.sh)
- Nhớ thay đổi version tương ứng trong generate_checksum để nó tạo chính xác các file theo version
- Cập nhật các checksum này vào file install_wpsila.sh
- Đẩy file install_wpsila.sh lên vps.wpsila.com
- Cập nhật các thông báo vesion trên README của main và trên website chính wpsila.com

Lúc này vps.wpsila.com sẽ chứa phiên bản mới nhất. Tải có kiểm tra checksum để đảm bảo dữ liệu tải về đầy đủ.

---

File install_wpsila_no_check_sum.sh dùng để test kiểm tra mã trước khi ra phiên bản chính thức, nó không có các ràng buộc về:
- Checksum
- Chặn ghi đè
Do vậy tiện để tải về kiểm tra. Phiên bản chính thức thì không được phép dùng file này.
