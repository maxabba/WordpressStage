#!/bin/bash

# Script to disable problematic plugins in development environment
# These plugins often cause issues like forced HTTPS, caching, security blocks, etc.

echo "Disabling problematic plugins for development environment..."

# Load environment variables to check cache settings
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Base list of plugins to always disable
PLUGINS_TO_DISABLE=(
    # Security plugins
    "wp-defender"
    "really-simple-ssl"
    "wordfence"
    "all-in-one-wp-security-and-firewall"
    "sucuri-scanner"
    "ithemes-security"
    "bulletproof-security"
)

# Cache plugins - disable based on cache setting
CACHE_PLUGINS=(
    "wp-rocket"
    "w3-total-cache"
    "wp-super-cache"
    "wp-fastest-cache"
    "litespeed-cache"
    "autoptimize"
    "cache-enabler"
    "hummingbird-performance"
    "wp-optimize"
    "object-cache-pro"
    "redis-cache"
    "memcached"
)

# Add cache plugins to disable list if cache is disabled
if [ "${ENABLE_MEMCACHED:-true}" = "false" ]; then
    echo "Cache disabled - all cache plugins will be deactivated"
    PLUGINS_TO_DISABLE+=("${CACHE_PLUGINS[@]}")
else
    echo "Cache enabled - only problematic cache plugins will be deactivated"
    # Only disable the most problematic cache plugins when cache is enabled
    PLUGINS_TO_DISABLE+=(
        "wp-rocket"      # Often conflicts with object cache
        "w3-total-cache" # Can cause conflicts
        "wp-super-cache" # File-based caching conflicts
    )
fi

# Continue with other plugins
PLUGINS_TO_DISABLE+=(
    # Optimization plugins that can interfere
    "wp-smush-pro"
    "wp-smushit"
    "ewww-image-optimizer"
    "imagify"
    "shortpixel-image-optimiser"
    
    # Update/License managers
    "wpmudev-updates"
    "envato-market"
    
    # CDN plugins
    "cloudflare"
    "wp-cloudflare-page-cache"
    
    # Maintenance mode plugins
    "maintenance"
    "coming-soon"
    "under-construction-page"
    
    # Other problematic plugins
    "wp-mail-smtp" # Can cause email issues in dev
    "updraftplus" # Backup plugin not needed in dev
)

# Wait for WordPress to be ready
echo "Waiting for WordPress to be ready..."
until docker-compose run --rm wpcli core is-installed 2>/dev/null; do
    sleep 2
done

echo "WordPress is ready. Disabling plugins..."

# Disable each plugin
for plugin in "${PLUGINS_TO_DISABLE[@]}"; do
    if docker-compose run --rm wpcli plugin is-active "$plugin" 2>/dev/null; then
        echo "Disabling: $plugin"
        docker-compose run --rm wpcli plugin deactivate "$plugin"
    fi
done

# Also disable any SSL/HTTPS redirects in .htaccess
if [ -f "./data/wordpress/.htaccess" ]; then
    echo "Removing HTTPS redirects from .htaccess..."
    # Remove common HTTPS redirect patterns
    sed -i.bak '/#\s*BEGIN\s*Really Simple SSL/,/#\s*END\s*Really Simple SSL/d' ./data/wordpress/.htaccess
    sed -i.bak '/#\s*BEGIN\s*rlrssslReallySimpleSSL/,/#\s*END\s*rlrssslReallySimpleSSL/d' ./data/wordpress/.htaccess
    sed -i.bak '/RewriteCond.*HTTPS.*off/d' ./data/wordpress/.htaccess
    sed -i.bak '/RewriteRule.*https:\/\/%{HTTP_HOST}/d' ./data/wordpress/.htaccess
fi

# Clear any cache if wp-cli cache commands are available
echo "Clearing caches..."
docker-compose run --rm wpcli cache flush 2>/dev/null || true
docker-compose run --rm wpcli rewrite flush 2>/dev/null || true

echo "Development plugin cleanup complete!"