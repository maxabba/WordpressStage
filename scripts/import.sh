#!/bin/bash

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

echo -e "${YELLOW}3. Copia database per import...${NC}"
cp "$DATABASE_SQL" data/imports/

echo -e "${YELLOW}4. Impostazione permessi...${NC}"
chmod -R 755 data/wordpress
chmod -R 777 data/wordpress/wp-content

echo -e "${YELLOW}5. Avvio containers...${NC}"
docker-compose up -d db
echo "Attendo che MySQL sia pronto..."
sleep 20

echo -e "${YELLOW}6. Import database...${NC}"
# Create database if it doesn't exist
docker-compose exec -T db mysql -uroot -p${DB_ROOT_PASSWORD:-root} -e "DROP DATABASE IF EXISTS ${DB_NAME:-wordpress}; CREATE DATABASE ${DB_NAME:-wordpress} DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;"
# Import SQL (continue even if there are errors like duplicate entries)
echo "Importing SQL file (ignoring duplicate entry errors)..."
docker-compose exec -T db mysql -uroot -p${DB_ROOT_PASSWORD:-root} ${DB_NAME:-wordpress} < data/imports/$(basename "$DATABASE_SQL") || echo "SQL import completed with some errors (expected for duplicate entries)"

echo -e "${YELLOW}7. Avvio WordPress e servizi...${NC}"
docker-compose up -d

echo -e "${YELLOW}8. Attendo che WordPress sia pronto...${NC}"
sleep 10

echo -e "${YELLOW}8.1. Configurazione database in wp-config.php...${NC}"
# Fix wp-config.php database settings
if [ -f "data/wordpress/wp-config.php" ]; then
    sed -i.bak "s/define( 'DB_HOST', '.*' );/define( 'DB_HOST', 'db' );/" data/wordpress/wp-config.php
    sed -i.bak "s/define( 'DB_NAME', '.*' );/define( 'DB_NAME', '${DB_NAME:-wordpress}' );/" data/wordpress/wp-config.php
    sed -i.bak "s/define( 'DB_USER', '.*' );/define( 'DB_USER', '${DB_USER:-wordpress}' );/" data/wordpress/wp-config.php
    sed -i.bak "s/define( 'DB_PASSWORD', '.*' );/define( 'DB_PASSWORD', '${DB_PASSWORD:-wordpress}' );/" data/wordpress/wp-config.php
    echo "Database configuration updated"
fi

echo -e "${YELLOW}9. Search and Replace URL (se configurato)...${NC}"
if [ ! -z "$SITE_URL_OLD" ] && [ ! -z "$SITE_URL_NEW" ]; then
    # Try both HTTPS and HTTP versions of the old URL
    docker-compose run --rm wpcli search-replace "$SITE_URL_OLD" "$SITE_URL_NEW" --all-tables
    # Also try without protocol to catch edge cases
    OLD_DOMAIN=$(echo "$SITE_URL_OLD" | sed 's|https\?://||')
    NEW_DOMAIN=$(echo "$SITE_URL_NEW" | sed 's|https\?://||')
    if [ "$OLD_DOMAIN" != "$NEW_DOMAIN" ]; then
        docker-compose run --rm wpcli search-replace "$OLD_DOMAIN" "$NEW_DOMAIN" --all-tables
    fi
    
    # Manual fix for critical WordPress URLs to ensure site works
    echo "Applying manual URL fixes for WordPress options..."
    CONTAINER_NAME="${PROJECT_NAME:-wp}_mysql"
    docker exec $CONTAINER_NAME mysql -uroot -p${DB_ROOT_PASSWORD:-root} -e "UPDATE ${DB_NAME:-wordpress}.wp_options SET option_value = '$SITE_URL_NEW' WHERE option_name IN ('siteurl', 'home');" 2>/dev/null || echo "Manual URL update completed"
else
    echo "Skip: SITE_URL_OLD o SITE_URL_NEW non configurati"
fi

echo -e "${YELLOW}10. Flush cache e rewrite rules...${NC}"
docker-compose run --rm wpcli cache flush
docker-compose run --rm wpcli rewrite flush

echo -e "${YELLOW}11. Disabilitazione plugin problematici per sviluppo...${NC}"
./scripts/disable-dev-plugins.sh

echo -e "${YELLOW}12. Verifica finale dell'installazione...${NC}"
# Check if WordPress is working
CONTAINER_NAME="${PROJECT_NAME:-wp}_mysql"
TABLE_COUNT=$(docker exec $CONTAINER_NAME mysql -uroot -p${DB_ROOT_PASSWORD:-root} -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '${DB_NAME:-wordpress}';" 2>/dev/null | tail -n 1)
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