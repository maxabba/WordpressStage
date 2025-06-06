#!/bin/bash

# WordPress Docker Stage Initialization Script
# This script automatically sets up a WordPress development environment from ZIP and SQL files

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ASCII Art Banner
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║        WordPress Docker Stage Environment            ║"
echo "║              Initialization Script                   ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Function to display usage
usage() {
    echo -e "${YELLOW}Usage:${NC}"
    echo "  1. Place your WordPress .zip file in the input_data/ folder"
    echo "  2. Place your database .sql file in the input_data/ folder"
    echo "  3. Run: ./init.sh"
    echo ""
    echo "The script will automatically detect and use these files."
    exit 1
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Error: Docker is not installed${NC}"
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}Error: Docker Compose is not installed${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Prerequisites met${NC}"
}

# Function to create necessary directories
create_directories() {
    echo -e "${YELLOW}Creating necessary directories...${NC}"
    mkdir -p input_data
    mkdir -p data/wordpress
    mkdir -p data/mysql
    mkdir -p data/imports
    chmod -R 755 data/
    echo -e "${GREEN}✓ Directories created${NC}"
}

# Function to find files in input_data
find_input_files() {
    echo -e "${YELLOW}Looking for input files...${NC}"
    
    # Find ZIP file
    ZIP_FILE=$(find input_data -name "*.zip" -type f | head -1)
    if [ -z "$ZIP_FILE" ]; then
        echo -e "${RED}Error: No .zip file found in input_data/${NC}"
        usage
    fi
    
    # Find SQL file
    SQL_FILE=$(find input_data -name "*.sql" -type f | head -1)
    if [ -z "$SQL_FILE" ]; then
        echo -e "${RED}Error: No .sql file found in input_data/${NC}"
        usage
    fi
    
    echo -e "${GREEN}✓ Found WordPress archive: $(basename "$ZIP_FILE")${NC}"
    echo -e "${GREEN}✓ Found database dump: $(basename "$SQL_FILE")${NC}"
}

# Function to configure environment
configure_environment() {
    echo -e "${YELLOW}Configuring environment...${NC}"
    
    # Check if .env exists
    if [ -f .env ]; then
        echo -e "${BLUE}Found existing .env file${NC}"
        read -p "Do you want to reconfigure? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi
    
    # Default values
    DEFAULT_PROJECT_NAME="wp"
    DEFAULT_WEB_PORT="8080"
    DEFAULT_PMA_PORT="8082"
    DEFAULT_PHP_VERSION="8.1"
    DEFAULT_MYSQL_VERSION="8.0"
    
    echo -e "${BLUE}Environment Configuration${NC}"
    echo "Press Enter to use default values shown in brackets"
    echo ""
    
    # Project name
    read -p "Project name [$DEFAULT_PROJECT_NAME]: " PROJECT_NAME
    PROJECT_NAME=${PROJECT_NAME:-$DEFAULT_PROJECT_NAME}
    
    # Web port
    read -p "WordPress port [$DEFAULT_WEB_PORT]: " WEB_PORT
    WEB_PORT=${WEB_PORT:-$DEFAULT_WEB_PORT}
    
    # phpMyAdmin port
    read -p "phpMyAdmin port [$DEFAULT_PMA_PORT]: " PMA_PORT
    PMA_PORT=${PMA_PORT:-$DEFAULT_PMA_PORT}
    
    # PHP version
    read -p "PHP version [$DEFAULT_PHP_VERSION]: " PHP_VERSION
    PHP_VERSION=${PHP_VERSION:-$DEFAULT_PHP_VERSION}
    
    # MySQL version
    read -p "MySQL version [$DEFAULT_MYSQL_VERSION]: " MYSQL_VERSION
    MYSQL_VERSION=${MYSQL_VERSION:-$DEFAULT_MYSQL_VERSION}
    
    # Memcached support
    echo ""
    echo -e "${BLUE}Cache Configuration${NC}"
    echo "Memcached can improve WordPress performance but may cause issues with some sites."
    echo "Choose cache configuration:"
    echo "  1) Enable Memcached (recommended for most sites)"
    echo "  2) Disable all caching (safer for problematic sites)"
    read -p "Select option [1-2, default: 1]: " CACHE_OPTION
    CACHE_OPTION=${CACHE_OPTION:-1}
    
    if [ "$CACHE_OPTION" = "2" ]; then
        ENABLE_MEMCACHED="false"
        echo -e "${YELLOW}ℹ️  Memcached will be disabled${NC}"
    else
        ENABLE_MEMCACHED="true"
        echo -e "${GREEN}✓ Memcached will be enabled${NC}"
    fi
    
    # Ask about old domain for search-replace
    echo ""
    echo -e "${BLUE}URL Migration (optional)${NC}"
    echo "If your WordPress was running on a different domain, enter it here for automatic URL replacement."
    echo "Leave empty to skip URL replacement."
    read -p "Old domain (e.g., https://example.com): " OLD_DOMAIN
    
    # Create .env file
    cat > .env << EOF
# Project Configuration
PROJECT_NAME=$PROJECT_NAME

# Ports
WEB_PORT=$WEB_PORT
PMA_PORT=$PMA_PORT

# Versions
PHP_VERSION=$PHP_VERSION
MYSQL_VERSION=$MYSQL_VERSION
WORDPRESS_VERSION=latest
MEMCACHED_VERSION=alpine

# Cache Configuration
ENABLE_MEMCACHED=$ENABLE_MEMCACHED

# Database Configuration
DB_NAME=wordpress
DB_USER=wordpress
DB_PASSWORD=wordpress
DB_ROOT_PASSWORD=root

# Development Settings
WP_DEBUG=true
WP_DEBUG_LOG=true
WP_DEBUG_DISPLAY=false

# URL Migration (optional)
SITE_URL_OLD=$OLD_DOMAIN
SITE_URL_NEW=http://localhost:$WEB_PORT
EOF

    echo -e "${GREEN}✓ Environment configured${NC}"
}

# Function to stop any running containers
stop_existing_containers() {
    echo -e "${YELLOW}Stopping any existing containers...${NC}"
    docker-compose down 2>/dev/null || true
    echo -e "${GREEN}✓ Containers stopped${NC}"
}

# Function to clean previous data
clean_previous_data() {
    echo -e "${YELLOW}Cleaning previous data...${NC}"
    read -p "Do you want to clean existing WordPress data? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf data/wordpress/*
        rm -rf data/mysql/*
        rm -rf data/imports/*
        echo -e "${GREEN}✓ Previous data cleaned${NC}"
    else
        echo -e "${BLUE}Keeping existing data${NC}"
    fi
}

# Function to handle cache disable logic
handle_cache_disable() {
    local wp_content="data/wordpress/wp-content"
    
    if [ ! -d "$wp_content" ]; then
        echo -e "${BLUE}ℹ️  WordPress content directory not yet created - cache cleanup will happen during import${NC}"
        return
    fi
    
    echo -e "${YELLOW}🔍 Scanning for problematic cache files...${NC}"
    
    # Check for object-cache.php
    if [ -f "$wp_content/object-cache.php" ]; then
        echo -e "${YELLOW}Found object-cache.php - creating backup and removing...${NC}"
        local backup_file="$wp_content/object-cache.php.disabled.$(date +%s)"
        mv "$wp_content/object-cache.php" "$backup_file"
        echo -e "${GREEN}✓ Backed up to: $(basename "$backup_file")${NC}"
    fi
    
    # Check for advanced-cache.php
    if [ -f "$wp_content/advanced-cache.php" ]; then
        if [ ! -s "$wp_content/advanced-cache.php" ]; then
            echo -e "${YELLOW}Found empty advanced-cache.php - removing...${NC}"
            rm -f "$wp_content/advanced-cache.php"
            echo -e "${GREEN}✓ Removed empty advanced-cache.php${NC}"
        else
            echo -e "${YELLOW}Found advanced-cache.php with content - creating backup and removing...${NC}"
            local backup_file="$wp_content/advanced-cache.php.disabled.$(date +%s)"
            mv "$wp_content/advanced-cache.php" "$backup_file"
            echo -e "${GREEN}✓ Backed up to: $(basename "$backup_file")${NC}"
        fi
    fi
    
    # Clean cache directories
    echo -e "${YELLOW}🧹 Cleaning cache directories...${NC}"
    local cache_dirs=("cache" "wp-rocket-cache" "w3tc-cache" "supercache" "wp-cache")
    local cleaned=0
    
    for cache_dir in "${cache_dirs[@]}"; do
        local full_path="$wp_content/$cache_dir"
        if [ -d "$full_path" ]; then
            echo "Cleaning $cache_dir..."
            rm -rf "$full_path"
            cleaned=$((cleaned + 1))
        fi
    done
    
    if [ $cleaned -gt 0 ]; then
        echo -e "${GREEN}✓ Cleaned $cleaned cache directories${NC}"
    else
        echo -e "${BLUE}ℹ️  No cache directories found${NC}"
    fi
    
    # Scan for cache plugins
    echo -e "${YELLOW}🔍 Scanning for cache-related plugins...${NC}"
    local plugins_dir="$wp_content/plugins"
    local cache_plugins=()
    
    if [ -d "$plugins_dir" ]; then
        # Common cache plugin patterns
        local cache_plugin_patterns=(
            "wp-rocket"
            "w3-total-cache"
            "wp-super-cache"
            "wp-fastest-cache"
            "litespeed-cache"
            "cache-enabler"
            "wp-optimize"
            "autoptimize"
            "smush"
            "object-cache-pro"
            "memcached"
            "redis-cache"
        )
        
        for pattern in "${cache_plugin_patterns[@]}"; do
            for plugin_dir in "$plugins_dir"/*"$pattern"*; do
                if [ -d "$plugin_dir" ]; then
                    cache_plugins+=("$(basename "$plugin_dir")")
                fi
            done
        done
        
        if [ ${#cache_plugins[@]} -gt 0 ]; then
            echo -e "${YELLOW}Found cache-related plugins:${NC}"
            for plugin in "${cache_plugins[@]}"; do
                echo "  - $plugin"
            done
            echo ""
            echo -e "${YELLOW}These plugins will be automatically disabled during import to prevent conflicts.${NC}"
        else
            echo -e "${GREEN}✓ No problematic cache plugins found${NC}"
        fi
    fi
    
    echo -e "${GREEN}✓ Cache disable preparation completed${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}Starting WordPress Docker Stage initialization...${NC}"
    echo ""
    
    # Check prerequisites
    check_prerequisites
    
    # Create directories
    create_directories
    
    # Find input files
    find_input_files
    
    # Configure environment
    configure_environment
    
    # Stop existing containers
    stop_existing_containers
    
    # Clean previous data
    clean_previous_data
    
    # Make scripts executable
    echo -e "${YELLOW}Setting up scripts...${NC}"
    chmod +x scripts/*.sh
    echo -e "${GREEN}✓ Scripts ready${NC}"
    
    # Generate appropriate docker-compose configuration
    echo -e "${YELLOW}Generating Docker configuration...${NC}"
    ./scripts/generate-docker-compose.sh
    echo -e "${GREEN}✓ Docker configuration ready${NC}"
    
    # Handle cache disable logic if needed
    if [ "$ENABLE_MEMCACHED" = "false" ]; then
        echo ""
        echo -e "${YELLOW}Cache disabled - scanning for cache-related files and plugins...${NC}"
        handle_cache_disable
    fi
    
    # Run import
    echo ""
    echo -e "${BLUE}Starting WordPress import...${NC}"
    ./scripts/import.sh "$ZIP_FILE" "$SQL_FILE"
    
    # Final message
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ WordPress Docker Stage is ready!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "Access your WordPress site at: ${BLUE}http://localhost:$WEB_PORT${NC}"
    echo -e "Access phpMyAdmin at: ${BLUE}http://localhost:$PMA_PORT${NC}"
    echo ""
    echo -e "Database credentials:"
    echo -e "  Host: ${YELLOW}db${NC}"
    echo -e "  Database: ${YELLOW}wordpress${NC}"
    echo -e "  Username: ${YELLOW}wordpress${NC}"
    echo -e "  Password: ${YELLOW}wordpress${NC}"
    echo ""
    echo -e "To stop the environment, run: ${YELLOW}./stop-and-clean.sh${NC}"
    echo ""
}

# Run main function
main