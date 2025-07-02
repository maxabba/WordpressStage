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

echo -e "${YELLOW}9. Search and Replace URL (se configurato)...${NC}"
# Set container name and check database status (used in multiple steps)
CONTAINER_NAME="${PROJECT_NAME:-wp}_db"
TABLE_COUNT=$(docker exec $CONTAINER_NAME mysql -uroot -p${DB_ROOT_PASSWORD:-root} -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '${DB_NAME:-wordpress}';" 2>/dev/null | tail -n 1)

if [ ! -z "$SITE_URL_OLD" ] && [ ! -z "$SITE_URL_NEW" ]; then
    
    if [ "$TABLE_COUNT" -gt 10 ]; then
        echo "Database has $TABLE_COUNT tables, proceeding with URL replacement..."
        
        # Manual fix for critical WordPress URLs first (more reliable)
        echo "Applying manual URL fixes for WordPress options..."
        docker exec $CONTAINER_NAME mysql -uroot -p${DB_ROOT_PASSWORD:-root} -e "UPDATE ${DB_NAME:-wordpress}.wp_options SET option_value = '$SITE_URL_NEW' WHERE option_name IN ('siteurl', 'home');" 2>/dev/null && echo "✓ Core URLs updated"
        
        # Try WP-CLI search-replace (may fail but that's ok)
        echo "Attempting WP-CLI search-replace..."
        docker-compose run --rm wpcli search-replace "$SITE_URL_OLD" "$SITE_URL_NEW" --all-tables --skip-columns=guid 2>/dev/null || echo "WP-CLI search-replace had issues (continuing anyway)"
        
        # Also try without protocol to catch edge cases
        OLD_DOMAIN=$(echo "$SITE_URL_OLD" | sed 's|https\?://||')
        NEW_DOMAIN=$(echo "$SITE_URL_NEW" | sed 's|https\?://||')
        if [ "$OLD_DOMAIN" != "$NEW_DOMAIN" ]; then
            docker-compose run --rm wpcli search-replace "$OLD_DOMAIN" "$NEW_DOMAIN" --all-tables --skip-columns=guid 2>/dev/null || echo "Domain-only replacement had issues (continuing anyway)"
        fi
    else
        echo "⚠ Database appears empty ($TABLE_COUNT tables), skipping URL replacement"
    fi
else
    echo "Skip: SITE_URL_OLD o SITE_URL_NEW non configurati"
fi

echo -e "${YELLOW}10. Flush cache e rewrite rules...${NC}"
# Use previously set TABLE_COUNT variable

if [ "$TABLE_COUNT" -gt 10 ]; then
    echo "Attempting cache and rewrite flush..."
    docker-compose run --rm wpcli cache flush 2>/dev/null || echo "Cache flush had issues (continuing anyway)"
    docker-compose run --rm wpcli rewrite flush 2>/dev/null || echo "Rewrite flush had issues (continuing anyway)"
else
    echo "Skipping cache/rewrite flush (database appears empty: $TABLE_COUNT tables)"
fi

echo -e "${YELLOW}11. Gestione file di cache e problematici...${NC}"
# Check if cache is enabled in environment
if [ "${ENABLE_MEMCACHED:-true}" = "false" ]; then
    echo -e "${YELLOW}Cache disabled - removing all cache-related files...${NC}"
    
    # Remove object-cache.php completely when cache is disabled
    if [ -f "data/wordpress/wp-content/object-cache.php" ]; then
        echo "Removing object-cache.php (cache disabled)..."
        mv data/wordpress/wp-content/object-cache.php data/wordpress/wp-content/object-cache.php.disabled.$(date +%s)
        echo "✓ object-cache.php disabled"
    fi
    
    # Remove advanced-cache.php when cache is disabled
    if [ -f "data/wordpress/wp-content/advanced-cache.php" ]; then
        echo "Removing advanced-cache.php (cache disabled)..."
        mv data/wordpress/wp-content/advanced-cache.php data/wordpress/wp-content/advanced-cache.php.disabled.$(date +%s)
        echo "✓ advanced-cache.php disabled"
    fi
    
    # Clean cache directories
    echo "Cleaning cache directories..."
    cache_dirs=("cache" "wp-rocket-cache" "w3tc-cache" "supercache" "wp-cache")
    for cache_dir in "${cache_dirs[@]}"; do
        if [ -d "data/wordpress/wp-content/$cache_dir" ]; then
            rm -rf "data/wordpress/wp-content/$cache_dir"
            echo "✓ Removed $cache_dir directory"
        fi
    done
    
    echo -e "${GREEN}✓ All cache files and directories removed${NC}"
else
    echo -e "${BLUE}Cache enabled - checking for compatibility issues...${NC}"
    
    # Gestione file di cache problematici prima di disabilitare i plugin
    if [ -f "data/wordpress/wp-content/object-cache.php" ]; then
        echo "Trovato object-cache.php, verifica compatibilità..."
        # Backup e rimozione se problematico
        if grep -q "class.*Memcache\|new.*Memcache" data/wordpress/wp-content/object-cache.php 2>/dev/null; then
            echo "Object cache potenzialmente problematico, creazione backup..."
            mv data/wordpress/wp-content/object-cache.php data/wordpress/wp-content/object-cache.php.backup.$(date +%s)
            echo "✓ object-cache.php salvato in backup"
        fi
    fi

    # Rimozione file advanced-cache.php vuoti
    if [ -f "data/wordpress/wp-content/advanced-cache.php" ] && [ ! -s "data/wordpress/wp-content/advanced-cache.php" ]; then
        echo "Rimozione advanced-cache.php vuoto..."
        rm -f data/wordpress/wp-content/advanced-cache.php
        echo "✓ advanced-cache.php rimosso"
    fi
fi

print_step "12. Disabilitazione plugin problematici per sviluppo..."
debug_log "Running plugin disable script..."
if [ -f "./scripts/disable-dev-plugins.sh" ]; then
    ./scripts/disable-dev-plugins.sh
else
    print_warning "disable-dev-plugins.sh script not found, skipping plugin disabling"
fi

echo -e "${YELLOW}13. Verifica finale dell'installazione...${NC}"
# Use previously set variables and get user count
USER_COUNT=$(docker-compose run --rm wpcli user list --format=count 2>/dev/null || echo "0")

if [ "$TABLE_COUNT" -gt 10 ] && [ "$USER_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Database import successful: $TABLE_COUNT tables, $USER_COUNT users${NC}"
    SITE_URL=$(docker-compose run --rm wpcli option get home 2>/dev/null | tr -d '\r\n' || echo "Not set")
    echo -e "${GREEN}✓ Site URL configured: $SITE_URL${NC}"
else
    echo -e "${RED}⚠ Warning: Database import may have issues${NC}"
fi

echo -e "${GREEN}=== Import completato! ===${NC}"
echo -e "WordPress: ${GREEN}http://localhost:${WEB_PORT:-8080}${NC}"
echo -e "phpMyAdmin: ${GREEN}http://localhost:${PMA_PORT:-8082}${NC}"
echo -e ""
echo -e "Credenziali database:"
echo -e "  Host: db"
echo -e "  Database: ${DB_NAME:-wordpress}"
echo -e "  User: ${DB_USER:-wordpress}"
echo -e "  Password: ${DB_PASSWORD:-wordpress}"
echo -e ""
echo -e "${YELLOW}Note: Se vedi la schermata di installazione WordPress, pulisci la cache del browser o prova in modalità incognito${NC}"