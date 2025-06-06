#!/bin/bash

# WordPress Docker Stage Stop and Clean Script
# This script stops all containers and optionally cleans data

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ASCII Art Banner
echo -e "${RED}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║        WordPress Docker Stage Environment            ║"
echo "║             Stop and Clean Script                    ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Function to stop containers
stop_containers() {
    echo -e "${YELLOW}Stopping all containers...${NC}"
    docker-compose down
    echo -e "${GREEN}✓ Containers stopped${NC}"
}

# Function to remove volumes
remove_volumes() {
    echo -e "${YELLOW}Removing Docker volumes...${NC}"
    docker-compose down -v
    echo -e "${GREEN}✓ Volumes removed${NC}"
}

# Function to clean data directories
clean_data() {
    echo -e "${YELLOW}Cleaning data directories...${NC}"
    rm -rf data/wordpress/*
    rm -rf data/mysql/*
    rm -rf data/imports/*
    echo -e "${GREEN}✓ Data directories cleaned${NC}"
}

# Function to clean input data
clean_input() {
    echo -e "${YELLOW}Cleaning input data...${NC}"
    rm -rf input_data/*
    echo -e "${GREEN}✓ Input data cleaned${NC}"
}

# Function to remove .env
remove_env() {
    echo -e "${YELLOW}Removing .env file...${NC}"
    rm -f .env
    echo -e "${GREEN}✓ .env removed${NC}"
}

# Function to prune Docker
prune_docker() {
    echo -e "${YELLOW}Pruning Docker system...${NC}"
    docker system prune -f
    echo -e "${GREEN}✓ Docker system pruned${NC}"
}

# Main menu
main() {
    echo -e "${BLUE}What would you like to do?${NC}"
    echo ""
    echo "1) Stop containers only"
    echo "2) Stop containers and clean WordPress data"
    echo "3) Stop containers and clean everything (full reset)"
    echo "4) Full cleanup + Docker prune (reclaim disk space)"
    echo "5) Cancel"
    echo ""
    read -p "Enter your choice (1-5): " choice
    
    case $choice in
        1)
            echo -e "${BLUE}Stopping containers...${NC}"
            stop_containers
            ;;
        2)
            echo -e "${BLUE}Stopping containers and cleaning data...${NC}"
            stop_containers
            
            echo ""
            read -p "Are you sure you want to delete all WordPress data? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                clean_data
                remove_volumes
            else
                echo -e "${YELLOW}Data cleanup cancelled${NC}"
            fi
            ;;
        3)
            echo -e "${BLUE}Full cleanup...${NC}"
            echo -e "${RED}WARNING: This will delete all data including:${NC}"
            echo "  - WordPress files"
            echo "  - Database data"
            echo "  - Input files"
            echo "  - Environment configuration"
            echo ""
            read -p "Are you absolutely sure? Type 'yes' to confirm: " confirm
            
            if [ "$confirm" = "yes" ]; then
                stop_containers
                remove_volumes
                clean_data
                clean_input
                remove_env
                echo -e "${GREEN}✓ Full cleanup completed${NC}"
            else
                echo -e "${YELLOW}Cleanup cancelled${NC}"
            fi
            ;;
        4)
            echo -e "${BLUE}Full cleanup with Docker prune...${NC}"
            echo -e "${RED}WARNING: This will:${NC}"
            echo "  - Delete all WordPress data"
            echo "  - Remove all stopped containers"
            echo "  - Remove all dangling images"
            echo "  - Remove all unused networks"
            echo "  - Free up disk space"
            echo ""
            read -p "Are you absolutely sure? Type 'yes' to confirm: " confirm
            
            if [ "$confirm" = "yes" ]; then
                stop_containers
                remove_volumes
                clean_data
                clean_input
                remove_env
                prune_docker
                echo -e "${GREEN}✓ Full cleanup with Docker prune completed${NC}"
            else
                echo -e "${YELLOW}Cleanup cancelled${NC}"
            fi
            ;;
        5)
            echo -e "${YELLOW}Operation cancelled${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}Operation completed!${NC}"
    echo ""
    
    # Show next steps based on cleanup level
    if [ "$choice" -gt 1 ]; then
        echo -e "${BLUE}To start a new WordPress stage:${NC}"
        echo "  1. Place your .zip and .sql files in input_data/"
        echo "  2. Run: ./init.sh"
    else
        echo -e "${BLUE}To restart the environment:${NC}"
        echo "  Run: docker-compose up -d"
    fi
}

# Run main function
main