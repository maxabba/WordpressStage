#!/bin/bash

# Script to fix URL issues after WordPress import
# This ensures all URLs point to the local development environment

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== WordPress URL Fix Tool ===${NC}"

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Set default values
LOCAL_URL="${SITE_URL_NEW:-http://localhost:8080}"
LOCAL_DOMAIN=$(echo "$LOCAL_URL" | sed 's|https\?://||')
DB_NAME="${DB_NAME:-wordpress}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-root}"
PROJECT_NAME="${PROJECT_NAME:-wp}"

echo -e "${BLUE}Target URL: $LOCAL_URL${NC}"
echo ""

# Step 1: Update database URLs
echo -e "${YELLOW}1. Updating database URLs...${NC}"

# Try with the correct container name (matches docker-compose.yml)
CONTAINER_NAME="${PROJECT_NAME}_db"
echo "Using container: $CONTAINER_NAME"

# Update wp_options table
echo "Updating wp_options table..."
docker exec $CONTAINER_NAME mysql -uroot -p${DB_ROOT_PASSWORD} -e "
UPDATE ${DB_NAME}.wp_options 
SET option_value = '$LOCAL_URL' 
WHERE option_name IN ('siteurl', 'home');
" 2>/dev/null && echo -e "${GREEN}✓ wp_options updated${NC}" || echo -e "${RED}✗ Failed to update wp_options${NC}"

# Find and replace all old URLs in the database
echo ""
echo "Searching for URLs to replace..."
# Get all unique domains in wp_posts
OLD_DOMAINS=$(docker exec $CONTAINER_NAME mysql -uroot -p${DB_ROOT_PASSWORD} -e "
SELECT DISTINCT 
    SUBSTRING_INDEX(SUBSTRING_INDEX(guid, '/', 3), '//', -1) as domain
FROM ${DB_NAME}.wp_posts 
WHERE guid LIKE 'http%' 
    AND guid NOT LIKE '%${LOCAL_DOMAIN}%'
LIMIT 10;
" 2>/dev/null | tail -n +2)

if [ ! -z "$OLD_DOMAINS" ]; then
    echo "Found domains to replace:"
    echo "$OLD_DOMAINS"
    
    # Use WP-CLI for search-replace
    for OLD_DOMAIN in $OLD_DOMAINS; do
        if [ ! -z "$OLD_DOMAIN" ] && [ "$OLD_DOMAIN" != "$LOCAL_DOMAIN" ]; then
            echo ""
            echo "Replacing $OLD_DOMAIN with $LOCAL_DOMAIN..."
            
            # Replace with protocol
            docker-compose run --rm wpcli search-replace "https://$OLD_DOMAIN" "$LOCAL_URL" --all-tables --skip-columns=guid 2>/dev/null || true
            docker-compose run --rm wpcli search-replace "http://$OLD_DOMAIN" "$LOCAL_URL" --all-tables --skip-columns=guid 2>/dev/null || true
            
            # Replace without protocol for embedded references
            docker-compose run --rm wpcli search-replace "//$OLD_DOMAIN" "//$LOCAL_DOMAIN" --all-tables --skip-columns=guid 2>/dev/null || true
        fi
    done
else
    echo "No old domains found in database"
fi

# Step 2: Clean .htaccess
echo ""
echo -e "${YELLOW}2. Cleaning .htaccess redirects...${NC}"

if [ -f "./data/wordpress/.htaccess" ]; then
    # Backup original
    cp ./data/wordpress/.htaccess ./data/wordpress/.htaccess.backup.$(date +%s)
    
    # Remove HTTPS redirect rules
    sed -i.bak '/#\s*BEGIN\s*Really Simple SSL/,/#\s*END\s*Really Simple SSL/d' ./data/wordpress/.htaccess
    sed -i.bak '/#\s*BEGIN\s*rlrssslReallySimpleSSL/,/#\s*END\s*rlrssslReallySimpleSSL/d' ./data/wordpress/.htaccess
    sed -i.bak '/RewriteCond.*HTTPS.*off/d' ./data/wordpress/.htaccess
    sed -i.bak '/RewriteRule.*https:\/\/%{HTTP_HOST}/d' ./data/wordpress/.htaccess
    sed -i.bak '/RewriteCond.*HTTP:X-Forwarded-Proto.*!https/d' ./data/wordpress/.htaccess
    sed -i.bak '/Header set Strict-Transport-Security/d' ./data/wordpress/.htaccess
    
    # Remove any specific domain redirects
    sed -i.bak '/RewriteCond.*HTTP_HOST.*necrologi/d' ./data/wordpress/.htaccess
    sed -i.bak '/RewriteRule.*necrologi/d' ./data/wordpress/.htaccess
    
    echo -e "${GREEN}✓ .htaccess cleaned${NC}"
else
    echo -e "${YELLOW}⚠ .htaccess not found${NC}"
fi

# Step 3: Clear caches
echo ""
echo -e "${YELLOW}3. Clearing caches...${NC}"

# Clear WordPress caches
docker-compose run --rm wpcli cache flush 2>/dev/null && echo -e "${GREEN}✓ Object cache flushed${NC}" || true
docker-compose run --rm wpcli transient delete --all 2>/dev/null && echo -e "${GREEN}✓ Transients cleared${NC}" || true
docker-compose run --rm wpcli rewrite flush 2>/dev/null && echo -e "${GREEN}✓ Rewrite rules flushed${NC}" || true

# Step 4: Disable SSL plugins
echo ""
echo -e "${YELLOW}4. Disabling SSL-related plugins...${NC}"

SSL_PLUGINS=(
    "really-simple-ssl"
    "ssl-insecure-content-fixer"
    "wp-force-ssl"
    "wordpress-https"
    "one-click-ssl"
)

for plugin in "${SSL_PLUGINS[@]}"; do
    if docker-compose run --rm wpcli plugin is-installed "$plugin" 2>/dev/null; then
        docker-compose run --rm wpcli plugin deactivate "$plugin" 2>/dev/null && echo -e "${GREEN}✓ Disabled: $plugin${NC}"
    fi
done

# Step 5: Final verification
echo ""
echo -e "${YELLOW}5. Verifying configuration...${NC}"

# Check current URLs
CURRENT_HOME=$(docker exec $CONTAINER_NAME mysql -uroot -p${DB_ROOT_PASSWORD} -e "SELECT option_value FROM ${DB_NAME}.wp_options WHERE option_name = 'home';" 2>/dev/null | tail -n 1)
CURRENT_SITEURL=$(docker exec $CONTAINER_NAME mysql -uroot -p${DB_ROOT_PASSWORD} -e "SELECT option_value FROM ${DB_NAME}.wp_options WHERE option_name = 'siteurl';" 2>/dev/null | tail -n 1)

echo "Database home URL: $CURRENT_HOME"
echo "Database site URL: $CURRENT_SITEURL"

# Check wp-config.php
echo ""
echo "wp-config.php URLs:"
grep -E "WP_HOME|WP_SITEURL" ./data/wordpress/wp-config.php 2>/dev/null || echo "No URL constants found"

echo ""
echo -e "${GREEN}=== URL Fix Complete ===${NC}"
echo ""
echo "Next steps:"
echo "1. Clear your browser cache and cookies"
echo "2. Try accessing the site in incognito/private mode"
echo "3. Visit: ${GREEN}$LOCAL_URL${NC}"
echo ""
echo "If you still see redirects, run:"
echo "  ${BLUE}docker-compose restart${NC}"