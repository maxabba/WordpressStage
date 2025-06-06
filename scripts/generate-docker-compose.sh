#!/bin/bash

# Generate Docker Compose Script
# Creates appropriate docker-compose configuration based on cache settings

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

echo -e "${YELLOW}Generating docker-compose configuration...${NC}"

# Base docker-compose content
cat > docker-compose.yml << 'EOF'
services:
  # Database MySQL
  db:
    image: mysql:${MYSQL_VERSION:-8.0}
    platform: linux/amd64  # Compatibilità M1
    container_name: ${PROJECT_NAME:-wp}_mysql
    restart: unless-stopped
    environment:
      MYSQL_DATABASE: ${DB_NAME:-wordpress}
      MYSQL_USER: ${DB_USER:-wordpress}
      MYSQL_PASSWORD: ${DB_PASSWORD:-wordpress}
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD:-root}
    volumes:
      - ./data/mysql:/var/lib/mysql
      - ./data/imports:/docker-entrypoint-initdb.d
    networks:
      - wordpress-network
    command: '--default-authentication-plugin=mysql_native_password'

EOF

# Add Memcached service if enabled
if [ "${ENABLE_MEMCACHED:-true}" = "true" ]; then
    cat >> docker-compose.yml << 'EOF'
  # Memcached for WordPress caching
  memcached:
    image: memcached:${MEMCACHED_VERSION:-alpine}
    platform: linux/amd64  # Compatibilità M1
    container_name: ${PROJECT_NAME:-wp}_memcached
    restart: unless-stopped
    command: memcached -m 64 -p 11211 -u memcache -l 0.0.0.0
    networks:
      - wordpress-network

EOF
    
    MEMCACHED_DEPENDS="      - memcached"
    MEMCACHED_ENV="      MEMCACHED_HOST: memcached:11211"
else
    MEMCACHED_DEPENDS=""
    MEMCACHED_ENV=""
    echo -e "${BLUE}ℹ️  Memcached service disabled${NC}"
fi

# Add WordPress service
cat >> docker-compose.yml << EOF
  # WordPress con PHP-FPM$([ "${ENABLE_MEMCACHED:-true}" = "true" ] && echo " e supporto cache" || echo "")
  wordpress:
    image: wordpress:php\${PHP_VERSION:-8.1}-fpm
    platform: linux/amd64  # Compatibilità M1
    container_name: \${PROJECT_NAME:-wp}_wordpress
    restart: unless-stopped
    depends_on:
      - db$MEMCACHED_DEPENDS
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_NAME: \${DB_NAME:-wordpress}
      WORDPRESS_DB_USER: \${DB_USER:-wordpress}
      WORDPRESS_DB_PASSWORD: \${DB_PASSWORD:-wordpress}
      WORDPRESS_DEBUG: \${WP_DEBUG:-true}
      WORDPRESS_TABLE_PREFIX: \${WP_TABLE_PREFIX:-wp_}$MEMCACHED_ENV
    volumes:
      - ./data/wordpress:/var/www/html
      - ./configs/php/custom.ini:/usr/local/etc/php/conf.d/custom.ini:ro
      - ./scripts:/scripts:ro
    networks:
      - wordpress-network

EOF

# Add remaining services
cat >> docker-compose.yml << 'EOF'
  # Nginx Web Server
  nginx:
    image: nginx:${NGINX_VERSION:-alpine}
    platform: linux/amd64  # Compatibilità M1
    container_name: ${PROJECT_NAME:-wp}_nginx
    restart: unless-stopped
    depends_on:
      - wordpress
    ports:
      - "${WEB_PORT:-8080}:80"
    volumes:
      - ./data/wordpress:/var/www/html:ro
      - ./configs/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    networks:
      - wordpress-network

  # phpMyAdmin
  phpmyadmin:
    image: phpmyadmin:${PHPMYADMIN_VERSION:-latest}
    platform: linux/amd64  # Compatibilità M1
    container_name: ${PROJECT_NAME:-wp}_phpmyadmin
    restart: unless-stopped
    depends_on:
      - db
    environment:
      PMA_HOST: db
      PMA_USER: root
      PMA_PASSWORD: ${DB_ROOT_PASSWORD:-root}
      UPLOAD_LIMIT: 300M
    ports:
      - "${PMA_PORT:-8082}:80"
    networks:
      - wordpress-network

  # WP-CLI per operazioni di manutenzione
  wpcli:
    image: wordpress:cli
    platform: linux/amd64  # Compatibilità M1
    container_name: ${PROJECT_NAME:-wp}_wpcli
    depends_on:
      - db
      - wordpress
    volumes:
      - ./data/wordpress:/var/www/html
      - ./scripts:/scripts
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_NAME: ${DB_NAME:-wordpress}
      WORDPRESS_DB_USER: ${DB_USER:-wordpress}
      WORDPRESS_DB_PASSWORD: ${DB_PASSWORD:-wordpress}
    networks:
      - wordpress-network
    entrypoint: ["wp", "--allow-root"]
    command: ["--info"]

networks:
  wordpress-network:
    driver: bridge

volumes:
  db_data:
  wordpress_data:
EOF

echo -e "${GREEN}✓ docker-compose.yml generated successfully${NC}"

if [ "${ENABLE_MEMCACHED:-true}" = "true" ]; then
    echo -e "${GREEN}✓ Memcached service included${NC}"
else
    echo -e "${YELLOW}⚠️  Memcached service excluded (cache disabled)${NC}"
fi