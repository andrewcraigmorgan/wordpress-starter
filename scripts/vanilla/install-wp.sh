#!/bin/bash
#
# Install WordPress using WP-CLI
#
# Usage: ./scripts/vanilla/install-wp.sh
#
# Environment variables:
#   WP_TITLE    - Site title (default: "WordPress Site")
#   WP_USER     - Admin username (default: "admin")
#   WP_PASS     - Admin password (default: "admin")
#   WP_EMAIL    - Admin email (default: "admin@example.com")
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/colors.sh"
source "$SCRIPT_DIR/../lib/utils.sh"

REPO_ROOT=$(get_repo_root)
cd "$REPO_ROOT"

# Load environment
if ! load_env; then
    print_error ".env file not found. Run setup-env.sh first."
    exit 1
fi

# Configuration with defaults
WP_TITLE="${WP_TITLE:-WordPress Site}"
WP_USER="${WP_USER:-admin}"
WP_PASS="${WP_PASS:-admin}"
WP_EMAIL="${WP_EMAIL:-admin@example.com}"
WP_URL="${WP_HOME:-http://localhost:${WP_PORT}}"

print_info "Installing WordPress..."

# Check if WordPress is already installed
if docker compose exec -T wordpress wp --allow-root core is-installed &>/dev/null; then
    print_warning "WordPress is already installed"

    if confirm "Reinstall WordPress? This will reset the database." "n"; then
        print_info "Resetting database..."
        docker compose exec -T wordpress wp --allow-root db reset --yes
    else
        print_info "Skipping installation"
        exit 0
    fi
fi

# Wait for database to be ready
wait_for_mysql 60

# Download WordPress core if not present
print_info "Checking WordPress core files..."
if ! docker compose exec -T wordpress wp --allow-root core version &>/dev/null; then
    print_info "Downloading WordPress..."
    docker compose exec -T wordpress wp --allow-root core download
fi

# Create wp-config.php if not present
if ! docker compose exec -T wordpress test -f /var/www/html/wp-config.php; then
    print_info "Creating wp-config.php..."
    docker compose exec -T wordpress wp --allow-root config create \
        --dbname="${DB_NAME:-wordpress}" \
        --dbuser="${DB_USER:-wordpress}" \
        --dbpass="${DB_PASSWORD:-wordpress}" \
        --dbhost="mysql" \
        --skip-check
fi

# Install WordPress
print_info "Running WordPress installation..."
docker compose exec -T wordpress wp --allow-root core install \
    --url="$WP_URL" \
    --title="$WP_TITLE" \
    --admin_user="$WP_USER" \
    --admin_password="$WP_PASS" \
    --admin_email="$WP_EMAIL" \
    --skip-email

# Update options
print_info "Configuring WordPress settings..."
docker compose exec -T wordpress wp --allow-root option update blog_public 0
docker compose exec -T wordpress wp --allow-root option update permalink_structure '/%postname%/'
docker compose exec -T wordpress wp --allow-root rewrite flush

# Remove default content
print_info "Cleaning up default content..."
docker compose exec -T wordpress wp --allow-root post delete 1 --force 2>/dev/null || true
docker compose exec -T wordpress wp --allow-root post delete 2 --force 2>/dev/null || true
docker compose exec -T wordpress wp --allow-root post delete 3 --force 2>/dev/null || true

# Delete default plugins
docker compose exec -T wordpress wp --allow-root plugin delete hello 2>/dev/null || true
docker compose exec -T wordpress wp --allow-root plugin delete akismet 2>/dev/null || true

print_success "WordPress installed successfully!"
echo ""
echo -e "  ${DIM}URL:      $WP_URL${NC}"
echo -e "  ${DIM}Username: $WP_USER${NC}"
echo -e "  ${DIM}Password: $WP_PASS${NC}"
echo ""
