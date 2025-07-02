#!/bin/bash

# Script to enable/disable Xdebug for WordPress development
# Usage: ./scripts/xdebug-toggle.sh [on|off|status]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to get current Xdebug status
get_xdebug_status() {
    if [ -f "$ENV_FILE" ]; then
        XDEBUG_MODE=$(grep "^XDEBUG_MODE=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d '"')
        XDEBUG_CLI_MODE=$(grep "^XDEBUG_CLI_MODE=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d '"')
    fi
    
    XDEBUG_MODE=${XDEBUG_MODE:-off}
    XDEBUG_CLI_MODE=${XDEBUG_CLI_MODE:-off}
}

# Function to update .env file
update_env() {
    local mode=$1
    local cli_mode=$2
    
    # Create .env if it doesn't exist
    if [ ! -f "$ENV_FILE" ]; then
        print_warning ".env file not found, creating one..."
        touch "$ENV_FILE"
    fi
    
    # Update or add XDEBUG_MODE
    if grep -q "^XDEBUG_MODE=" "$ENV_FILE"; then
        sed -i '' "s/^XDEBUG_MODE=.*/XDEBUG_MODE=$mode/" "$ENV_FILE"
    else
        echo "XDEBUG_MODE=$mode" >> "$ENV_FILE"
    fi
    
    # Update or add XDEBUG_CLI_MODE
    if grep -q "^XDEBUG_CLI_MODE=" "$ENV_FILE"; then
        sed -i '' "s/^XDEBUG_CLI_MODE=.*/XDEBUG_CLI_MODE=$cli_mode/" "$ENV_FILE"
    else
        echo "XDEBUG_CLI_MODE=$cli_mode" >> "$ENV_FILE"
    fi
    
    # Update or add XDEBUG_PORT
    if ! grep -q "^XDEBUG_PORT=" "$ENV_FILE"; then
        echo "XDEBUG_PORT=9003" >> "$ENV_FILE"
    fi
    
    # Update or add XDEBUG_TRIGGER
    if ! grep -q "^XDEBUG_TRIGGER=" "$ENV_FILE"; then
        echo "XDEBUG_TRIGGER=1" >> "$ENV_FILE"
    fi
}

# Function to restart services
restart_services() {
    print_status "Restarting WordPress services to apply Xdebug changes..."
    cd "$PROJECT_DIR"
    
    if command -v docker-compose >/dev/null 2>&1; then
        docker-compose restart wordpress wpcli
    elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        docker compose restart wordpress wpcli
    else
        print_error "Neither docker-compose nor docker compose found!"
        exit 1
    fi
    
    print_success "Services restarted successfully"
}

# Function to show status
show_status() {
    get_xdebug_status
    
    echo ""
    echo "=== Xdebug Status ==="
    echo "Web/FPM Mode: $XDEBUG_MODE"
    echo "CLI Mode: $XDEBUG_CLI_MODE"
    echo "Port: ${XDEBUG_PORT:-9003}"
    echo ""
    
    if [ "$XDEBUG_MODE" = "off" ] && [ "$XDEBUG_CLI_MODE" = "off" ]; then
        echo -e "${RED}Xdebug is DISABLED${NC}"
    elif [ "$XDEBUG_MODE" != "off" ] && [ "$XDEBUG_CLI_MODE" != "off" ]; then
        echo -e "${GREEN}Xdebug is ENABLED for both Web and CLI${NC}"
    elif [ "$XDEBUG_MODE" != "off" ]; then
        echo -e "${YELLOW}Xdebug is ENABLED for Web only${NC}"
    elif [ "$XDEBUG_CLI_MODE" != "off" ]; then
        echo -e "${YELLOW}Xdebug is ENABLED for CLI only${NC}"
    fi
    echo ""
}

# Function to enable Xdebug
enable_xdebug() {
    print_status "Enabling Xdebug..."
    update_env "debug,develop" "debug,develop"
    restart_services
    print_success "Xdebug enabled for both Web and CLI"
    
    echo ""
    echo "=== IDE Configuration ==="
    echo "Port: 9003"
    echo "IDE Key: PHPSTORM (Web), WPCLI (CLI)"
    echo "Host: host.docker.internal"
    echo ""
    echo "For CLI debugging, set XDEBUG_SESSION=1 environment variable:"
    echo "  docker-compose run --rm -e XDEBUG_SESSION=1 wpcli [command]"
    echo ""
}

# Function to disable Xdebug
disable_xdebug() {
    print_status "Disabling Xdebug..."
    update_env "off" "off"
    restart_services
    print_success "Xdebug disabled"
}

# Main logic
case "${1:-status}" in
    "on"|"enable")
        enable_xdebug
        show_status
        ;;
    "off"|"disable")
        disable_xdebug
        show_status
        ;;
    "status"|"")
        show_status
        ;;
    "restart")
        restart_services
        show_status
        ;;
    *)
        echo "Usage: $0 [on|off|status|restart]"
        echo ""
        echo "Commands:"
        echo "  on/enable   - Enable Xdebug for both Web and CLI"
        echo "  off/disable - Disable Xdebug"
        echo "  status      - Show current Xdebug status"
        echo "  restart     - Restart services to apply changes"
        echo ""
        show_status
        exit 1
        ;;
esac