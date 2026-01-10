#!/bin/bash
#
# Setup environment configuration with randomized ports
#
# Usage: ./scripts/vanilla/setup-env.sh
#        ./scripts/vanilla/setup-env.sh --force  # Regenerate even if .env exists
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/colors.sh"
source "$SCRIPT_DIR/../lib/utils.sh"

REPO_ROOT=$(get_repo_root)

# Check for --force flag
FORCE=false
if [[ "$1" == "--force" || "$1" == "-f" ]]; then
    FORCE=true
fi

# Check if .env already exists
if [ -f "$REPO_ROOT/.env" ] && [ "$FORCE" = false ]; then
    print_warning ".env already exists. Use --force to regenerate ports."
    exit 0
fi

# Generate random port offset (1-999)
PORT_OFFSET=$(generate_port_offset)

WP_PORT=$((8000 + PORT_OFFSET))
PMA_PORT=$((9000 + PORT_OFFSET))

# Generate project name from directory
PROJECT_NAME=$(generate_project_name)

# Copy example and update values
cp "$REPO_ROOT/.env.example" "$REPO_ROOT/.env"

# Update port values
sed -i "s|^PROJECT_NAME=.*|PROJECT_NAME=${PROJECT_NAME}|" "$REPO_ROOT/.env"
sed -i "s|^WP_PORT=.*|WP_PORT=${WP_PORT}|" "$REPO_ROOT/.env"
sed -i "s|^PMA_PORT=.*|PMA_PORT=${PMA_PORT}|" "$REPO_ROOT/.env"
sed -i "s|^WP_HOME=.*|WP_HOME=http://localhost:${WP_PORT}|" "$REPO_ROOT/.env"
sed -i "s|^WP_SITEURL=.*|WP_SITEURL=http://localhost:${WP_PORT}|" "$REPO_ROOT/.env"

# Add COMPOSE_PROJECT_NAME if not present
if ! grep -q "COMPOSE_PROJECT_NAME" "$REPO_ROOT/.env"; then
    echo "" >> "$REPO_ROOT/.env"
    echo "# Docker Compose project name (ensures isolated volumes/networks)" >> "$REPO_ROOT/.env"
    echo "COMPOSE_PROJECT_NAME=${PROJECT_NAME}" >> "$REPO_ROOT/.env"
fi

print_success "Environment configured:"
echo ""
echo -e "  ${CYAN}WordPress:${NC}   http://localhost:$WP_PORT"
echo -e "  ${CYAN}phpMyAdmin:${NC}  http://localhost:$PMA_PORT"
echo -e "  ${CYAN}Project:${NC}     $PROJECT_NAME"
echo ""
