#!/bin/bash

# Fix Cache Issues Script
# Fixes common cache-related problems in imported WordPress sites

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 WordPress Cache Issues Fix${NC}"
echo "This script fixes common cache-related problems in imported WordPress sites."
echo ""

WP_CONTENT="data/wordpress/wp-content"

if [ ! -d "$WP_CONTENT" ]; then
    echo -e "${RED}❌ WordPress content directory not found: $WP_CONTENT${NC}"
    echo "Make sure you have run ./init.sh first and WordPress is installed."
    exit 1
fi

echo -e "${YELLOW}🔍 Scanning for cache issues...${NC}"

# Function to backup and fix object-cache.php
fix_object_cache() {
    local object_cache="$WP_CONTENT/object-cache.php"
    
    if [ -f "$object_cache" ]; then
        echo -e "${YELLOW}📁 Found object-cache.php${NC}"
        
        # Check for Memcache/Memcached issues
        if grep -q "class.*Memcache\|new.*Memcache\|Memcache::" "$object_cache" 2>/dev/null; then
            echo -e "${YELLOW}⚠️  Detected Memcache dependency in object-cache.php${NC}"
            
            # Create backup
            local backup_file="$object_cache.backup.$(date +%s)"
            cp "$object_cache" "$backup_file"
            echo -e "${GREEN}💾 Created backup: $(basename "$backup_file")${NC}"
            
            # Check if our Docker setup has Memcached
            if docker-compose ps | grep -q memcached; then
                echo -e "${GREEN}✅ Memcached service is available in Docker${NC}"
                echo "The startup script will handle object-cache.php compatibility."
            else
                echo -e "${YELLOW}⚠️  Memcached service not found in Docker setup${NC}"
                echo "Removing problematic object-cache.php..."
                rm -f "$object_cache"
                echo -e "${GREEN}✅ Removed problematic object-cache.php${NC}"
            fi
        else
            echo -e "${GREEN}✅ object-cache.php appears compatible${NC}"
        fi
    else
        echo -e "${BLUE}ℹ️  No object-cache.php found${NC}"
    fi
}

# Function to fix advanced-cache.php
fix_advanced_cache() {
    local advanced_cache="$WP_CONTENT/advanced-cache.php"
    
    if [ -f "$advanced_cache" ]; then
        echo -e "${YELLOW}📁 Found advanced-cache.php${NC}"
        
        if [ ! -s "$advanced_cache" ]; then
            echo -e "${YELLOW}⚠️  advanced-cache.php is empty${NC}"
            rm -f "$advanced_cache"
            echo -e "${GREEN}✅ Removed empty advanced-cache.php${NC}"
        else
            echo -e "${BLUE}ℹ️  advanced-cache.php has content, leaving as-is${NC}"
        fi
    else
        echo -e "${BLUE}ℹ️  No advanced-cache.php found${NC}"
    fi
}

# Function to clean cache directories
clean_cache_directories() {
    echo -e "${YELLOW}🧹 Cleaning cache directories...${NC}"
    
    local cache_dirs=("cache" "wp-rocket-cache" "w3tc-cache" "supercache" "wp-cache")
    local cleaned=0
    
    for cache_dir in "${cache_dirs[@]}"; do
        local full_path="$WP_CONTENT/$cache_dir"
        if [ -d "$full_path" ]; then
            echo "Cleaning $cache_dir..."
            find "$full_path" -name "*.php" -type f -delete 2>/dev/null || true
            find "$full_path" -name "*.cache" -type f -delete 2>/dev/null || true
            find "$full_path" -name "*.tmp" -type f -delete 2>/dev/null || true
            cleaned=$((cleaned + 1))
        fi
    done
    
    if [ $cleaned -gt 0 ]; then
        echo -e "${GREEN}✅ Cleaned $cleaned cache directories${NC}"
    else
        echo -e "${BLUE}ℹ️  No cache directories found to clean${NC}"
    fi
}

# Function to check wp-config.php cache settings
check_wp_config_cache() {
    local wp_config="data/wordpress/wp-config.php"
    
    if [ -f "$wp_config" ]; then
        echo -e "${YELLOW}⚙️  Checking wp-config.php cache settings...${NC}"
        
        if grep -q "define.*WP_CACHE.*true" "$wp_config"; then
            echo -e "${YELLOW}⚠️  WP_CACHE is enabled in wp-config.php${NC}"
            echo "This may cause issues in development. Consider setting it to false."
            
            read -p "Do you want to disable WP_CACHE? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sed -i.bak "s/define( *'WP_CACHE', *true *);/define('WP_CACHE', false);/" "$wp_config"
                echo -e "${GREEN}✅ Disabled WP_CACHE in wp-config.php${NC}"
            fi
        else
            echo -e "${GREEN}✅ WP_CACHE settings look good${NC}"
        fi
        
        # Check for other problematic cache constants
        if grep -q "COOKIE_DOMAIN\|WP_CACHE_KEY_SALT" "$wp_config"; then
            echo -e "${BLUE}ℹ️  Found cache-related constants in wp-config.php${NC}"
        fi
    else
        echo -e "${RED}❌ wp-config.php not found${NC}"
    fi
}

# Function to restart WordPress container
restart_wordpress() {
    echo -e "${YELLOW}🔄 Restarting WordPress container to apply changes...${NC}"
    
    if docker-compose ps | grep -q wordpress; then
        docker-compose restart wordpress
        echo -e "${GREEN}✅ WordPress container restarted${NC}"
    else
        echo -e "${YELLOW}⚠️  WordPress container not running${NC}"
    fi
}

# Main execution
echo "Starting cache issue diagnosis and fix..."
echo ""

fix_object_cache
echo ""

fix_advanced_cache
echo ""

clean_cache_directories
echo ""

check_wp_config_cache
echo ""

echo -e "${BLUE}🔧 Cache issue fix completed!${NC}"
echo ""

read -p "Do you want to restart the WordPress container to apply changes? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    restart_wordpress
    echo ""
    echo -e "${GREEN}🎉 All done! Your WordPress site should now be working properly.${NC}"
    echo -e "Access your site at: ${BLUE}http://localhost:${WEB_PORT:-8080}${NC}"
else
    echo -e "${YELLOW}⚠️  Remember to restart containers with: docker-compose restart${NC}"
fi