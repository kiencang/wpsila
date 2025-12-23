Mỗi khi ra phiên bản mới cần làm như sau:
- Cập nhật version mới cho check_for_update.sh trong main (ví dụ v0.3.1)
- Trên GitHub, tạo phiên bản mới tương ứng với version vừa nhập trong check_for_update.sh
- Sử dụng generate_checksum để tạo checksum cho các file của phiên bản mới (ví dụ dùng WSL trên Windows bash ./checksum.sh)
- Nhớ thay đổi version tương ứng trong generate_checksum để nó tạo chính xác các file theo version
- Cập nhật các checksum này vào file install_wpsila.sh
- Đẩy file install_wpsila.sh lên vps.wpsila.com

Lúc này vps.wpsila.com sẽ chứa phiên bản mới nhất. Tải có kiểm tra checksum để đảm bảo dữ liệu tải về đầy đủ.
