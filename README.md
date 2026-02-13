Version của bash script: v1.2.7
---
Website: https://wpsila.com

Đây là công cụ dòng lệnh (CLI) giúp **cài đặt nhanh blog WordPress trên VPS** (chỉ blog & nói chung là website không bao gồm giỏ hàng).

- Yêu cầu hệ thống: **Ubuntu LTS 24.04** hoặc 22.04, cài mới trên VPS (tức là bạn chưa có bất cứ website nào hoặc cài bất cứ chương trình gì ngoài Ubuntu trên VPS đó).
- RAM tối thiểu 1GB.

Luôn giữ **các bản backup website** để dự phòng trước và sau khi chuyển sang hệ thống của wpsila.

Cài đặt với quyền root: 

```bash
curl -sL https://vps.wpsila.com | sudo bash
```

Hướng dẫn sử dụng đầy đủ mời bạn xem chi tiết ở đây: https://wpsila.com/huong-dan/

## Gợi ý các theme & plugin nên dùng cùng với wpsila

wpsila có thể dùng kèm với *bất kỳ theme & plugin nào*, tuy vậy chúng tôi gợi ý bạn nên dùng các theme & plugin dưới đây để đảm bảo website an toàn & có hiệu suất cao:

- Giao diện: GeneratePress (https://wordpress.org/themes/generatepress/)
- Plugin tăng tốc (cache): Cache Enabler (https://wordpress.org/plugins/cache-enabler/)
- Plugin tối ưu máy tìm kiếm: The SEO Framework (https://wordpress.org/plugins/autodescription/)
- Plugin backup: UpdraftPlus (https://wordpress.org/plugins/updraftplus/)
- Plugin tạo mục lục cho bài dài: Easy Table of Contents (https://wordpress.org/plugins/easy-table-of-contents/)
- Plugin giúp hạn chế spam cho khu vực bình luận: WP Armour (https://wordpress.org/plugins/honeypot/)
- Plugin hỗ trợ tìm kiếm tốt hơn: WP Search with Algolia (https://wordpress.org/plugins/wp-search-with-algolia/)

Ngoài ra các tính năng bảo mật miễn phí của Cloudflare (https://www.cloudflare.com/) cũng rất hợp với người dùng WordPress làm blog, nó dễ triển khai và có chất lượng cao.

**Chú ý**: Các công cụ trên chỉ là gợi ý, wpsila không có bất cứ ràng buộc nào là bạn phải dùng theme hay plugin cụ thể nào đó.

## Gợi ý công cụ dùng kèm wpsila

wpsila nằm trong gói Sila Stack (https://wpsila.com/sila-stack/) hỗ trợ toàn diện cho blog WordPress. Để tối ưu thêm bạn có thể dùng thêm các công cụ dưới đây:

- rtf-cafe: https://rtd-cafe.wpsila.com/
- Plugin Simple Cafe Purge: https://simple-cafe-purge.wpsila.com/

## Tuyên bố miễn trừ trách nhiệm (Disclaimer)

Script này được cung cấp miễn phí và mã nguồn mở. Mặc dù tôi đã cố gắng hết sức để kiểm tra kỹ lưỡng, nhưng việc sử dụng script này hoàn toàn thuộc về rủi ro của bạn (Use at your own risk).

Tác giả không chịu trách nhiệm cho bất kỳ thiệt hại nào liên quan đến:

- Mất mát dữ liệu.

- Lỗi cấu hình hệ thống.

- Các vấn đề bảo mật phát sinh.

Tuyên bố miễn trừ trách nhiệm đầy đủ được tôi công bố tại đây: https://wpsila.com/disclaimer

---
*Cảm ơn bạn đã sử dụng giải pháp từ wpsila! Nếu thấy hữu ích, hãy giới thiệu cho bạn bè cùng sử dụng.*
