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
    DEFAULT_PMA_PORT="8081"
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