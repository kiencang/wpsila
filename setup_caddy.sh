NEW_DOMAIN="api.example.com"
NEW_PORT="9000"

# Dùng >> để nối thêm vào cuối file
cat >> /etc/caddy/Caddyfile <<EOF

$NEW_DOMAIN {
    reverse_proxy localhost:$NEW_PORT
}
EOF

echo "Đã thêm $NEW_DOMAIN vào Caddyfile."