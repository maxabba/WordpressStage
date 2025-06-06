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
unzip -q "$WORDPRESS_ZIP" -d data/wordpress/
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
docker-compose exec -T db mysql -uroot -p${DB_ROOT_PASSWORD:-root} ${DB_NAME:-wordpress} < data/imports/$(basename "$DATABASE_SQL")

echo -e "${YELLOW}7. Avvio WordPress e servizi...${NC}"
docker-compose up -d

echo -e "${YELLOW}8. Attendo che WordPress sia pronto...${NC}"
sleep 10

echo -e "${YELLOW}9. Search and Replace URL (se configurato)...${NC}"
if [ ! -z "$SITE_URL_OLD" ] && [ ! -z "$SITE_URL_NEW" ]; then
    docker-compose run --rm wpcli search-replace "$SITE_URL_OLD" "$SITE_URL_NEW" --all-tables
else
    echo "Skip: SITE_URL_OLD o SITE_URL_NEW non configurati"
fi

echo -e "${YELLOW}10. Flush cache e rewrite rules...${NC}"
docker-compose run --rm wpcli cache flush
docker-compose run --rm wpcli rewrite flush

echo -e "${YELLOW}11. Disabilitazione plugin problematici per sviluppo...${NC}"
./scripts/disable-dev-plugins.sh

echo -e "${GREEN}=== Import completato! ===${NC}"
echo -e "WordPress: ${GREEN}http://localhost:${WEB_PORT:-8080}${NC}"
echo -e "phpMyAdmin: ${GREEN}http://localhost:${PMA_PORT:-8081}${NC}"
echo -e ""
echo -e "Credenziali database:"
echo -e "  Host: db"
echo -e "  Database: ${DB_NAME:-wordpress}"
echo -e "  User: ${DB_USER:-wordpress}"
echo -e "  Password: ${DB_PASSWORD:-wordpress}"