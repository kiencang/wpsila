###start_wpsila_kiencang_{{DOMAIN}}###
# 1. Chuyen huong RED_DOMAIN ve DOMAIN 
{{RED_DOMAIN}} {
    redir https://{{DOMAIN}}{uri} permanent
}

# 2. Cau hinh chinh
{{DOMAIN}} {
    root * /var/www/{{DOMAIN}}/public_html
    encode zstd gzip
	
    # Tang gioi han upload, can chinh them /etc/php/{{PHP_VER}}/fpm/php.ini cho dong bo
    request_body {
        max_size 50MB
    }	

    # Log: Tu dong xoay vong
    log {
        output file /var/www/{{DOMAIN}}/logs/access.log {
            roll_size 10mb
            roll_keep 10
        }
    }

    # --- SECURITY HEADERS ---\
    header {
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        X-XSS-Protection "0"
        Referrer-Policy "strict-origin-when-cross-origin"
        Permissions-Policy "camera=(), microphone=(), geolocation=(), browsing-topics=()"
        # Strict-Transport-Security "max-age=31536000; includeSubDomains"
        -Server
        -X-Powered-By
    }

    # --- CACHE CODE (CSS/JS) ---\
    @code_assets {
        file
        path *.css *.js
    }
    header @code_assets Cache-Control "public, max-age=604800"

    # --- CACHE MEDIA (ANH/FONT) ---\
    @media_assets {
        file
        path *.ico *.gif *.jpg *.jpeg *.png *.svg *.woff *.woff2 *.webp *.avif
    }
    header @media_assets Cache-Control "public, max-age=31536000, immutable"

    # --- CHAN FILE NHAY CAM (SECURITY BLOCK) ---\
    @forbidden {
        # 1. Block PHP Uploads 
        path /wp-content/uploads/*.php

        # 2. Block System Files & Directories
        path /wp-config.php
        path /.htaccess
		path /.git
        path /.git/*     
        path *.env   
        path /readme.html
        path /license.txt
		
		# 3. Block xmlrpc 
		path /xmlrpc.php
        
        # 4. Block Backups & Logs
        path *.sql *.bak *.log *.old
    }
    # Tra ve 404
    respond @forbidden 404
	
	# PHP FastCGI, version duoc thay the tu dong
    php_fastcgi unix//run/php/php{{PHP_VER}}-fpm.sock

    file_server
}
    # Danh dau marker de nhan dien sau nay
    #wpsila_kiencang
###end_wpsila_kiencang_{{DOMAIN}}###