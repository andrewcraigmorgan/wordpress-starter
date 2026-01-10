#!/bin/bash
#
# Initialize .env with randomized ports to avoid collisions
#
# Usage: ./scripts/setup.sh
#        ./scripts/setup.sh --force  # Regenerate ports even if .env exists

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check for --force flag
FORCE=false
if [[ "$1" == "--force" || "$1" == "-f" ]]; then
    FORCE=true
fi

# Check if .env already exists
if [ -f "$REPO_ROOT/.env" ] && [ "$FORCE" = false ]; then
    echo -e "${YELLOW}.env already exists. Use --force to regenerate ports.${NC}"
    exit 0
fi

# Generate random port offset (1-999)
PORT_OFFSET=$(( (RANDOM % 999) + 1 ))

WP_PORT=$((8000 + PORT_OFFSET))
PMA_PORT=$((9000 + PORT_OFFSET))

# Generate project name from directory
DIR_NAME=$(basename "$REPO_ROOT")
PROJECT_NAME=$(echo "$DIR_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | cut -c1-20 | sed 's/-$//')

# Copy example and update values
cp "$REPO_ROOT/.env.example" "$REPO_ROOT/.env"

sed -i "s|^PROJECT_NAME=.*|PROJECT_NAME=${PROJECT_NAME}|" "$REPO_ROOT/.env"
sed -i "s|^WP_PORT=.*|WP_PORT=${WP_PORT}|" "$REPO_ROOT/.env"
sed -i "s|^PMA_PORT=.*|PMA_PORT=${PMA_PORT}|" "$REPO_ROOT/.env"
sed -i "s|^WP_HOME=.*|WP_HOME=http://localhost:${WP_PORT}|" "$REPO_ROOT/.env"
sed -i "s|^WP_SITEURL=.*|WP_SITEURL=http://localhost:${WP_PORT}|" "$REPO_ROOT/.env"

# Add COMPOSE_PROJECT_NAME
echo "" >> "$REPO_ROOT/.env"
echo "# Docker Compose project name (ensures isolated volumes/networks)" >> "$REPO_ROOT/.env"
echo "COMPOSE_PROJECT_NAME=${PROJECT_NAME}" >> "$REPO_ROOT/.env"

echo -e "${GREEN}✓ .env created with unique ports:${NC}"
echo "  WordPress:   http://localhost:$WP_PORT"
echo "  phpMyAdmin:  http://localhost:$PMA_PORT"
echo "  Project:     $PROJECT_NAME"
echo ""
echo "Run: docker compose up -d"
