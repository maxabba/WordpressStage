#!/bin/bash

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Debug mode (set DEBUG=1 for verbose output)
DEBUG=${DEBUG:-0}

debug_log() {
    if [ "$DEBUG" = "1" ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

print_step() {
    echo -e "${YELLOW}$1${NC}"
    debug_log "Starting step: $1"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    debug_log "Success: $1"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    debug_log "Error: $1"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    debug_log "Warning: $1"
}

echo -e "${GREEN}=== WordPress Docker Import Tool ===${NC}"

# Controllo parametri
if [ "$#" -ne 2 ]; then
    echo -e "${RED}Uso: $0 <wordpress.zip> <database.sql>${NC}"
    echo "Esempio: $0 /path/to/site.zip /path/to/dump.sql"
    exit 1
fi

WORDPRESS_ZIP=$1
DATABASE_SQL=$2

# Verifica file esistono
if [ ! -f "$WORDPRESS_ZIP" ]; then
    echo -e "${RED}Errore: File WordPress ZIP non trovato: $WORDPRESS_ZIP${NC}"
    exit 1
fi

if [ ! -f "$DATABASE_SQL" ]; then
    echo -e "${RED}Errore: File SQL non trovato: $DATABASE_SQL${NC}"
    exit 1
fi

# Carica variabili ambiente
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo -e "${YELLOW}File .env non trovato, uso valori default${NC}"
fi

echo -e "${YELLOW}1. Pulizia directory esistenti...${NC}"
rm -rf data/wordpress/*
rm -rf data/mysql/*
rm -rf data/imports/*

echo -e "${YELLOW}2. Estrazione WordPress...${NC}"
unzip -o -q "$WORDPRESS_ZIP" -d data/wordpress/
# Se il zip contiene una directory root, spostiamo i file
if [ -d data/wordpress/*/wp-content ]; then
    mv data/wordpress/*/* data/wordpress/
    rm -rf data/wordpress/*/
fi

echo -e "${YELLOW}3. Preparazione database per import...${NC}"
# Create imports directory without copying SQL yet (to prevent auto-execution)
mkdir -p data/imports
# We'll copy the SQL file later after MySQL is fully started

echo -e "${YELLOW}4. Impostazione permessi...${NC}"
chmod -R 755 data/wordpress
chmod -R 777 data/wordpress/wp-content

echo -e "${YELLOW}5. Avvio containers...${NC}"
docker-compose up -d db
echo "Attendo che MySQL sia pronto..."
sleep 20

echo -e "${YELLOW}6. Import database...${NC}"
# Now copy the SQL file after MySQL is running
echo "Copying SQL file to imports directory..."
cp "$DATABASE_SQL" data/imports/

# Create database if it doesn't exist
echo "Creating WordPress database..."
docker-compose exec -T db mysql -uroot -p${DB_ROOT_PASSWORD:-root} -e "DROP DATABASE IF EXISTS ${DB_NAME:-wordpress}; CREATE DATABASE ${DB_NAME:-wordpress} DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;"

# Import SQL (continue even if there are errors like duplicate entries)
echo "Importing SQL file (ignoring duplicate entry errors)..."
docker-compose exec -T db mysql -uroot -p${DB_ROOT_PASSWORD:-root} ${DB_NAME:-wordpress} < data/imports/$(basename "$DATABASE_SQL") || echo "SQL import completed with some errors (expected for duplicate entries)"

echo -e "${YELLOW}7. Avvio WordPress e servizi...${NC}"
docker-compose up -d

print_step "8. Attendo che WordPress sia pronto..."
debug_log "Waiting for WordPress containers to initialize..."
sleep 10

print_step "8.1. Configurazione database in wp-config.php..."
# Fix wp-config.php database settings (more robust patterns)
if [ -f "data/wordpress/wp-config.php" ]; then
    debug_log "Found wp-config.php, updating database configuration..."
    # Fix database host
    sed -i.bak "s/define( *'DB_HOST', *'[^']*' *);/define( 'DB_HOST', 'db' );/" data/wordpress/wp-config.php
    # Fix database name  
    sed -i.bak "s/define( *'DB_NAME', *'[^']*' *);/define( 'DB_NAME', '${DB_NAME:-wordpress}' );/" data/wordpress/wp-config.php
    # Fix database user
    sed -i.bak "s/define( *'DB_USER', *'[^']*' *);/define( 'DB_USER', '${DB_USER:-wordpress}' );/" data/wordpress/wp-config.php
    # Fix database password
    sed -i.bak "s/define( *'DB_PASSWORD', *'[^']*' *);/define( 'DB_PASSWORD', '${DB_PASSWORD:-wordpress}' );/" data/wordpress/wp-config.php
    
    # Disable WP_CACHE (causes issues in dev)
    sed -i.bak "s/define( *'WP_CACHE', *true *);/define( 'WP_CACHE', false );/" data/wordpress/wp-config.php
    
    print_success "Database configuration updated"
else
    print_warning "wp-config.php not found"
fi

print_step "8.2. Aggiunta configurazioni URL forzate in wp-config.php..."
# Force WordPress URLs to use localhost
if [ -f "data/wordpress/wp-config.php" ]; then
    LOCAL_URL="${SITE_URL_NEW:-http://localhost:${WEB_PORT:-8080}}"
    
    # Check if WP_HOME is already defined
    if ! grep -q "define.*WP_HOME" data/wordpress/wp-config.php; then
        debug_log "Adding WP_HOME definition..."
        # Add after <?php tag
        sed -i.bak "/<\?php/a\\
define( 'WP_HOME', '$LOCAL_URL' );" data/wordpress/wp-config.php
        print_success "Added WP_HOME: $LOCAL_URL"
    else
        # Update existing WP_HOME
        sed -i.bak "s/define( *'WP_HOME', *'[^']*' *);/define( 'WP_HOME', '$LOCAL_URL' );/" data/wordpress/wp-config.php
        print_success "Updated WP_HOME: $LOCAL_URL"
    fi
    
    # Check if WP_SITEURL is already defined
    if ! grep -q "define.*WP_SITEURL" data/wordpress/wp-config.php; then
        debug_log "Adding WP_SITEURL definition..."
        sed -i.bak "/<\?php/a\\
define( 'WP_SITEURL', '$LOCAL_URL' );" data/wordpress/wp-config.php
        print_success "Added WP_SITEURL: $LOCAL_URL"
    else
        # Update existing WP_SITEURL
        sed -i.bak "s/define( *'WP_SITEURL', *'[^']*' *);/define( 'WP_SITEURL', '$LOCAL_URL' );/" data/wordpress/wp-config.php
        print_success "Updated WP_SITEURL: $LOCAL_URL"
    fi
    
    # Force disable SSL admin
    if ! grep -q "define.*FORCE_SSL_ADMIN" data/wordpress/wp-config.php; then
        debug_log "Adding FORCE_SSL_ADMIN = false..."
        sed -i.bak "/<\?php/a\\
define( 'FORCE_SSL_ADMIN', false );" data/wordpress/wp-config.php
        print_success "Disabled SSL admin"
    else
        sed -i.bak "s/define( *'FORCE_SSL_ADMIN', *[^)]*);/define( 'FORCE_SSL_ADMIN', false );/" data/wordpress/wp-config.php
        print_success "Updated FORCE_SSL_ADMIN to false"
    fi
fi

echo -e "${YELLOW}9. Search and Replace URL completo...${NC}"
# Set container name and check database status (used in multiple steps)
CONTAINER_NAME="${PROJECT_NAME:-wp}_db"
TABLE_COUNT=$(docker exec $CONTAINER_NAME mysql -uroot -p${DB_ROOT_PASSWORD:-root} -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '${DB_NAME:-wordpress}';" 2>/dev/null | tail -n 1)

if [ "$TABLE_COUNT" -gt 10 ]; then
    # Set local URL
    LOCAL_URL="${SITE_URL_NEW:-http://localhost:${WEB_PORT:-8080}}"
    LOCAL_DOMAIN=$(echo "$LOCAL_URL" | sed 's|https\?://||')
    
    echo "Target URL: $LOCAL_URL"
    echo "Database has $TABLE_COUNT tables, proceeding with URL replacement..."
    
    # Step 1: Manual fix for critical WordPress URLs first (most reliable)
    print_step "9.1. Aggiornamento URL principali nel database..."
    docker exec $CONTAINER_NAME mysql -uroot -p${DB_ROOT_PASSWORD:-root} -e "UPDATE ${DB_NAME:-wordpress}.wp_options SET option_value = '$LOCAL_URL' WHERE option_name IN ('siteurl', 'home');" 2>/dev/null && print_success "Core URLs updated"
    
    # Step 2: Find ALL old domains in the database
    print_step "9.2. Ricerca di tutti i domini da sostituire..."
    OLD_DOMAINS=$(docker exec $CONTAINER_NAME mysql -uroot -p${DB_ROOT_PASSWORD:-root} -e "
    SELECT DISTINCT 
        SUBSTRING_INDEX(SUBSTRING_INDEX(guid, '/', 3), '//', -1) as domain
    FROM ${DB_NAME:-wordpress}.wp_posts 
    WHERE guid LIKE 'http%' 
        AND guid NOT LIKE '%${LOCAL_DOMAIN}%'
    LIMIT 10;
    " 2>/dev/null | tail -n +2)
    
    # Add configured old domain if provided
    if [ ! -z "$SITE_URL_OLD" ]; then
        CONFIGURED_OLD_DOMAIN=$(echo "$SITE_URL_OLD" | sed 's|https\?://||')
        OLD_DOMAINS="$CONFIGURED_OLD_DOMAIN
$OLD_DOMAINS"
    fi
    
    # Remove duplicates and empty lines
    OLD_DOMAINS=$(echo "$OLD_DOMAINS" | sort -u | grep -v "^$")
    
    if [ ! -z "$OLD_DOMAINS" ]; then
        echo "Domini trovati da sostituire:"
        echo "$OLD_DOMAINS"
        
        # Step 3: Replace each old domain with comprehensive search-replace
        for OLD_DOMAIN in $OLD_DOMAINS; do
            if [ ! -z "$OLD_DOMAIN" ] && [ "$OLD_DOMAIN" != "$LOCAL_DOMAIN" ]; then
                print_step "9.3. Sostituzione di $OLD_DOMAIN con $LOCAL_DOMAIN..."
                
                # Replace with HTTPS protocol
                docker-compose run --rm wpcli search-replace "https://$OLD_DOMAIN" "$LOCAL_URL" --all-tables --skip-columns=guid 2>/dev/null || true
                
                # Replace with HTTP protocol
                docker-compose run --rm wpcli search-replace "http://$OLD_DOMAIN" "$LOCAL_URL" --all-tables --skip-columns=guid 2>/dev/null || true
                
                # Replace protocol-relative URLs
                docker-compose run --rm wpcli search-replace "//$OLD_DOMAIN" "//$LOCAL_DOMAIN" --all-tables --skip-columns=guid 2>/dev/null || true
                
                # Replace domain without protocol (for embedded references)
                docker-compose run --rm wpcli search-replace "$OLD_DOMAIN" "$LOCAL_DOMAIN" --all-tables --skip-columns=guid 2>/dev/null || true
                
                print_success "Completata sostituzione per $OLD_DOMAIN"
            fi
        done
    else
        print_warning "Nessun dominio vecchio trovato nel database"
    fi
    
    # Step 4: Additional replacements for common variations
    print_step "9.4. Sostituzione varianti URL comuni..."
    # Replace escaped URLs in JSON data
    if [ ! -z "$SITE_URL_OLD" ]; then
        ESCAPED_OLD=$(echo "$SITE_URL_OLD" | sed 's/\//\\\//g')
        ESCAPED_NEW=$(echo "$LOCAL_URL" | sed 's/\//\\\//g')
        docker-compose run --rm wpcli search-replace "$ESCAPED_OLD" "$ESCAPED_NEW" --all-tables --skip-columns=guid 2>/dev/null || true
    fi
    
    # Fix any remaining localhost variations
    docker-compose run --rm wpcli search-replace "http://localhost" "$LOCAL_URL" --all-tables --skip-columns=guid 2>/dev/null || true
    docker-compose run --rm wpcli search-replace "https://localhost" "$LOCAL_URL" --all-tables --skip-columns=guid 2>/dev/null || true
    
else
    print_warning "Database appears empty ($TABLE_COUNT tables), skipping URL replacement"
fi

print_step "10. Pulizia .htaccess da redirect SSL e domini..."
# Clean .htaccess from SSL redirects and domain-specific rules
if [ -f "./data/wordpress/.htaccess" ]; then
    # Backup original
    cp ./data/wordpress/.htaccess ./data/wordpress/.htaccess.backup.$(date +%s)
    print_success "Backup .htaccess creato"
    
    # Remove SSL redirect rules
    print_step "10.1. Rimozione regole SSL/HTTPS..."
    sed -i.bak '/#\s*BEGIN\s*Really Simple SSL/,/#\s*END\s*Really Simple SSL/d' ./data/wordpress/.htaccess
    sed -i.bak '/#\s*BEGIN\s*rlrssslReallySimpleSSL/,/#\s*END\s*rlrssslReallySimpleSSL/d' ./data/wordpress/.htaccess
    sed -i.bak '/RewriteCond.*HTTPS.*off/d' ./data/wordpress/.htaccess
    sed -i.bak '/RewriteRule.*https:\/\/%{HTTP_HOST}/d' ./data/wordpress/.htaccess
    sed -i.bak '/RewriteCond.*HTTP:X-Forwarded-Proto.*!https/d' ./data/wordpress/.htaccess
    sed -i.bak '/Header set Strict-Transport-Security/d' ./data/wordpress/.htaccess
    sed -i.bak '/RewriteCond.*SERVER_PORT.*!443/d' ./data/wordpress/.htaccess
    sed -i.bak '/RewriteRule.*\^(.*)$.*https:\/\//d' ./data/wordpress/.htaccess
    
    # Remove any specific domain redirects
    print_step "10.2. Rimozione redirect specifici del dominio..."
    if [ ! -z "$SITE_URL_OLD" ]; then
        OLD_DOMAIN_CLEAN=$(echo "$SITE_URL_OLD" | sed 's|https\?://||' | sed 's/\./\\./g')
        sed -i.bak "/RewriteCond.*HTTP_HOST.*$OLD_DOMAIN_CLEAN/d" ./data/wordpress/.htaccess
        sed -i.bak "/RewriteRule.*$OLD_DOMAIN_CLEAN/d" ./data/wordpress/.htaccess
    fi
    
    # Remove any hardcoded domain redirects from found domains
    if [ ! -z "$OLD_DOMAINS" ]; then
        for domain in $OLD_DOMAINS; do
            DOMAIN_CLEAN=$(echo "$domain" | sed 's/\./\\./g')
            sed -i.bak "/RewriteCond.*HTTP_HOST.*$DOMAIN_CLEAN/d" ./data/wordpress/.htaccess
            sed -i.bak "/RewriteRule.*$DOMAIN_CLEAN/d" ./data/wordpress/.htaccess
        done
    fi
    
    # Clean up empty lines
    sed -i.bak '/^$/N;/^\n$/d' ./data/wordpress/.htaccess
    
    print_success ".htaccess pulito da redirect SSL e domini"
else
    print_warning ".htaccess non trovato"
fi

echo -e "${YELLOW}11. Flush cache e rewrite rules...${NC}"
# Use previously set TABLE_COUNT variable

if [ "$TABLE_COUNT" -gt 10 ]; then
    echo "Attempting cache and rewrite flush..."
    docker-compose run --rm wpcli cache flush 2>/dev/null || echo "Cache flush had issues (continuing anyway)"
    docker-compose run --rm wpcli rewrite flush 2>/dev/null || echo "Rewrite flush had issues (continuing anyway)"
else
    echo "Skipping cache/rewrite flush (database appears empty: $TABLE_COUNT tables)"
fi

echo -e "${YELLOW}12. Gestione completa cache e file problematici...${NC}"

print_step "12.1. Pulizia file di cache..."
# Always remove problematic cache files during import
if [ -f "data/wordpress/wp-content/object-cache.php" ]; then
    echo "Removing object-cache.php for clean import..."
    mv data/wordpress/wp-content/object-cache.php data/wordpress/wp-content/object-cache.php.disabled.$(date +%s)
    print_success "object-cache.php disabled"
fi

if [ -f "data/wordpress/wp-content/advanced-cache.php" ]; then
    echo "Removing advanced-cache.php for clean import..."
    mv data/wordpress/wp-content/advanced-cache.php data/wordpress/wp-content/advanced-cache.php.disabled.$(date +%s)
    print_success "advanced-cache.php disabled"
fi

# Clean all cache directories
print_step "12.2. Pulizia directory di cache..."
cache_dirs=(
    "cache" 
    "wp-rocket-cache" 
    "w3tc-cache" 
    "w3tc-config"
    "supercache" 
    "wp-cache"
    "cache-enabler"
    "hyper-cache"
    "comet-cache"
    "breeze-cache"
)

for cache_dir in "${cache_dirs[@]}"; do
    if [ -d "data/wordpress/wp-content/$cache_dir" ]; then
        rm -rf "data/wordpress/wp-content/$cache_dir"
        print_success "Removed $cache_dir directory"
    fi
done

# Clean transients and cache from database
print_step "12.3. Pulizia transient e cache dal database..."
if [ "$TABLE_COUNT" -gt 10 ]; then
    # Delete all transients
    docker-compose run --rm wpcli transient delete --all 2>/dev/null && print_success "Transients eliminati" || true
    
    # Delete expired transients from database directly
    docker exec $CONTAINER_NAME mysql -uroot -p${DB_ROOT_PASSWORD:-root} -e "
    DELETE FROM ${DB_NAME:-wordpress}.wp_options 
    WHERE option_name LIKE '_transient_%' 
    OR option_name LIKE '_site_transient_%';
    " 2>/dev/null && print_success "Transient database puliti" || true
    
    # Clear any session data
    docker exec $CONTAINER_NAME mysql -uroot -p${DB_ROOT_PASSWORD:-root} -e "
    DELETE FROM ${DB_NAME:-wordpress}.wp_options 
    WHERE option_name LIKE '_wp_session_%';
    " 2>/dev/null && print_success "Session data puliti" || true
fi

# Additional cache flush
docker-compose run --rm wpcli cache flush 2>/dev/null || true

print_step "13. Disabilitazione plugin problematici per sviluppo..."
debug_log "Disabling problematic plugins..."

# Lista estesa di plugin SSL/sicurezza da disabilitare
SSL_PLUGINS=(
    "really-simple-ssl"
    "ssl-insecure-content-fixer"
    "wp-force-ssl"
    "wordpress-https"
    "one-click-ssl"
    "wp-encrypt"
    "ssl-zen"
    "wp-letsencrypt-ssl"
    "flexible-ssl-for-cloudflare"
)

# Altri plugin problematici in sviluppo locale
PROBLEMATIC_PLUGINS=(
    "wordfence"
    "all-in-one-wp-security-and-firewall"
    "sucuri-scanner"
    "ithemes-security"
    "bulletproof-security"
    "wp-cerber"
    "wp-simple-firewall"
    "updraftplus"
    "wp-rocket"
    "w3-total-cache"
    "wp-super-cache"
    "wp-fastest-cache"
    "litespeed-cache"
)

print_step "13.1. Disabilitazione plugin SSL..."
for plugin in "${SSL_PLUGINS[@]}"; do
    if docker-compose run --rm wpcli plugin is-installed "$plugin" 2>/dev/null; then
        docker-compose run --rm wpcli plugin deactivate "$plugin" 2>/dev/null && print_success "Disabilitato: $plugin" || print_warning "Impossibile disabilitare: $plugin"
    fi
done

print_step "13.2. Disabilitazione plugin di sicurezza e cache..."
for plugin in "${PROBLEMATIC_PLUGINS[@]}"; do
    if docker-compose run --rm wpcli plugin is-installed "$plugin" 2>/dev/null; then
        docker-compose run --rm wpcli plugin deactivate "$plugin" 2>/dev/null && print_success "Disabilitato: $plugin" || print_warning "Impossibile disabilitare: $plugin"
    fi
done

# Run additional disable script if exists
if [ -f "./scripts/disable-dev-plugins.sh" ]; then
    ./scripts/disable-dev-plugins.sh
fi

echo -e "${YELLOW}14. Verifica finale dell'installazione...${NC}"
# Use previously set variables and get user count
USER_COUNT=$(docker-compose run --rm wpcli user list --format=count 2>/dev/null || echo "0")

print_step "14.1. Verifica configurazione database..."
if [ "$TABLE_COUNT" -gt 10 ] && [ "$USER_COUNT" -gt 0 ]; then
    print_success "Database import successful: $TABLE_COUNT tables, $USER_COUNT users"
    
    # Verify URLs in database
    print_step "14.2. Verifica URL nel database..."
    CURRENT_HOME=$(docker exec $CONTAINER_NAME mysql -uroot -p${DB_ROOT_PASSWORD:-root} -e "SELECT option_value FROM ${DB_NAME:-wordpress}.wp_options WHERE option_name = 'home';" 2>/dev/null | tail -n 1)
    CURRENT_SITEURL=$(docker exec $CONTAINER_NAME mysql -uroot -p${DB_ROOT_PASSWORD:-root} -e "SELECT option_value FROM ${DB_NAME:-wordpress}.wp_options WHERE option_name = 'siteurl';" 2>/dev/null | tail -n 1)
    
    echo "Database home URL: $CURRENT_HOME"
    echo "Database site URL: $CURRENT_SITEURL"
    
    # Check if URLs are correctly set
    if [[ "$CURRENT_HOME" == *"localhost"* ]] && [[ "$CURRENT_SITEURL" == *"localhost"* ]]; then
        print_success "URL correttamente configurati per localhost"
    else
        print_warning "ATTENZIONE: Gli URL nel database potrebbero non essere corretti"
        print_warning "Esegui ./scripts/fix-urls.sh per correggere"
    fi
    
    # Check for remaining old URLs
    print_step "14.3. Controllo URL vecchi residui..."
    if [ ! -z "$SITE_URL_OLD" ]; then
        OLD_DOMAIN=$(echo "$SITE_URL_OLD" | sed 's|https\?://||')
        REMAINING_OLD=$(docker exec $CONTAINER_NAME mysql -uroot -p${DB_ROOT_PASSWORD:-root} -e "
        SELECT COUNT(*) FROM ${DB_NAME:-wordpress}.wp_posts 
        WHERE post_content LIKE '%$OLD_DOMAIN%' 
        OR guid LIKE '%$OLD_DOMAIN%';
        " 2>/dev/null | tail -n 1)
        
        if [ "$REMAINING_OLD" -gt 0 ]; then
            print_warning "Trovati $REMAINING_OLD riferimenti al vecchio dominio nei post"
        else
            print_success "Nessun riferimento al vecchio dominio trovato"
        fi
    fi
else
    print_error "Warning: Database import may have issues"
    print_error "Tables: $TABLE_COUNT, Users: $USER_COUNT"
fi

# Final check for active plugins that might cause issues
print_step "14.4. Controllo plugin attivi problematici..."
ACTIVE_PLUGINS=$(docker-compose run --rm wpcli plugin list --status=active --field=name 2>/dev/null || echo "")
FOUND_ISSUES=0

for plugin in really-simple-ssl ssl-insecure-content-fixer wp-force-ssl; do
    if echo "$ACTIVE_PLUGINS" | grep -q "$plugin"; then
        print_warning "Plugin SSL ancora attivo: $plugin"
        FOUND_ISSUES=1
    fi
done

if [ "$FOUND_ISSUES" -eq 0 ]; then
    print_success "Nessun plugin SSL problematico attivo"
fi

echo ""
echo -e "${GREEN}=== Import completato! ===${NC}"
echo ""
echo -e "Accesso al sito:"
echo -e "  WordPress: ${GREEN}http://localhost:${WEB_PORT:-8080}${NC}"
echo -e "  phpMyAdmin: ${GREEN}http://localhost:${PMA_PORT:-8082}${NC}"
echo ""
echo -e "Credenziali database:"
echo -e "  Host: db"
echo -e "  Database: ${DB_NAME:-wordpress}"
echo -e "  User: ${DB_USER:-wordpress}"
echo -e "  Password: ${DB_PASSWORD:-wordpress}"
echo ""
echo -e "${YELLOW}Suggerimenti per problemi di redirect:${NC}"
echo -e "1. Pulisci cache e cookie del browser"
echo -e "2. Prova in modalità incognito/privata"
echo -e "3. Se il problema persiste: ${BLUE}./scripts/fix-urls.sh${NC}"
echo -e "4. Riavvia i container: ${BLUE}docker-compose restart${NC}"
echo ""
echo -e "${GREEN}Buon lavoro!${NC}"