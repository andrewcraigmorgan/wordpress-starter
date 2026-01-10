#!/bin/bash
#
# Install WordPress with dev defaults
#
# Usage: ./scripts/install-wp.sh
#        ./scripts/install-wp.sh --title "My Site"

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

cd "$REPO_ROOT"

# Load .env (handle values with spaces)
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

# Defaults
SITE_TITLE="${1:-Dev Site}"
ADMIN_USER="admin"
ADMIN_PASS="admin"
ADMIN_EMAIL="${LOCAL_ADMIN_EMAIL:-admin@localhost.local}"
SITE_URL="${WP_HOME:-http://localhost:8080}"

echo -e "${YELLOW}Waiting for MySQL to be ready...${NC}"
until docker compose exec -T mysql mysqladmin ping -h localhost --silent 2>/dev/null; do
    sleep 1
done
echo -e "${GREEN}✓ MySQL is ready${NC}"

# Check if already installed
if docker compose exec -T wordpress wp core is-installed --path=/var/www/html --allow-root 2>/dev/null; then
    echo -e "${YELLOW}WordPress is already installed.${NC}"
    exit 0
fi

echo -e "${YELLOW}Installing WordPress...${NC}"

docker compose exec -T wordpress wp core install \
    --path=/var/www/html \
    --url="$SITE_URL" \
    --title="$SITE_TITLE" \
    --admin_user="$ADMIN_USER" \
    --admin_password="$ADMIN_PASS" \
    --admin_email="$ADMIN_EMAIL" \
    --skip-email \
    --allow-root

echo ""
echo -e "${GREEN}✓ WordPress installed successfully!${NC}"
echo ""
echo "  URL:       $SITE_URL"
echo "  Admin:     $SITE_URL/wp-admin"
echo "  Username:  $ADMIN_USER"
echo "  Password:  $ADMIN_PASS"
