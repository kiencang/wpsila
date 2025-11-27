# Biến định nghĩa domain và port backend
DOMAIN="example.com"
BACKEND_PORT="8080"

# Ghi đè nội dung vào /etc/caddy/Caddyfile
cat > /etc/caddy/Caddyfile <<EOF
$DOMAIN {
    # Cấu hình log
    log {
        output file /var/log/caddy/access.log
    }

    # Bật nén
    encode zstd gzip

    # Reverse Proxy
    reverse_proxy localhost:$BACKEND_PORT
}
EOF

echo "Đã tạo Caddyfile mới."