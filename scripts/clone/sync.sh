#!/bin/bash
#
# Sync WordPress from remote environment (production/staging)
#
# Usage: ./scripts/clone/sync.sh
#
# This script:
# - Syncs plugins from remote
# - Syncs database with backup
# - Performs URL replacement
# - Blocks search engines
# - Updates admin email
# - Manages caches
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/colors.sh"
source "$SCRIPT_DIR/../lib/utils.sh"

REPO_ROOT=$(get_repo_root)
cd "$REPO_ROOT"

# Load environment
if ! load_env; then
    print_error ".env file not found"
    exit 1
fi

# Configuration
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BACKUP_DIR:-./backups}"
TEMP_FILE="${BACKUP_DIR}/prod_db_${TIMESTAMP}.sql"
KEEP_BACKUPS="${KEEP_BACKUPS:-7}"
DB_TEMP_NAME="db_sync_tool.sql"
WORDPRESS_DIR="./wordpress"
THEME_SLUGS="${PROD_THEME_SLUGS:-}"

# Create backup directory
mkdir -p "${BACKUP_DIR}"

# Validate configuration
if [ -z "$PROD_SERVER" ] || [ -z "$PROD_DB_NAME" ] || [ -z "$PROD_DB_USER" ] || [ -z "$PROD_DB_PASSWORD" ]; then
    print_error "Remote server configuration incomplete in .env file"
    print_info "Required: PROD_SERVER, PROD_DB_NAME, PROD_DB_USER, PROD_DB_PASSWORD"
    exit 1
fi

if [ -z "$PROD_PATH" ]; then
    print_error "PROD_PATH is not set in .env file"
    exit 1
fi

# Check containers
if ! containers_running; then
    print_error "Docker containers are not running. Start them with: docker compose up -d"
    exit 1
fi

# SSH command setup
SSH_CMD="ssh"
SCP_CMD="scp"
if [ -n "$PROD_SSH_KEY" ]; then
    SSH_CMD="ssh -i $PROD_SSH_KEY"
    SCP_CMD="scp -i $PROD_SSH_KEY"
fi

# Banner
print_header "WordPress Environment Sync"
echo -e "  ${CYAN}Source:${NC}      $PROD_SERVER"
echo -e "  ${CYAN}Remote Path:${NC} $PROD_PATH"
echo ""

# Get URLs
SOURCE_SITE="${PROD_WP_HOME}"
DESTINATION_SITE=$(docker compose exec -T wordpress wp --allow-root option get siteurl 2>/dev/null | tr -d '\r' || echo "${WP_HOME}")
DESTINATION_SITE="${DESTINATION_SITE:-$WP_HOME}"

print_info "Source URL:      $SOURCE_SITE"
print_info "Destination URL: $DESTINATION_SITE"
echo ""

# ============================================================================
# Step 1: Sync Plugins
# ============================================================================
print_step "1/8" "Syncing plugins from remote..."

TEMP_PLUGINS_DIR="${BACKUP_DIR}/temp_plugins"
mkdir -p "${TEMP_PLUGINS_DIR}"

rsync -avz --delete \
    -e "${SSH_CMD}" \
    "${PROD_SERVER}:${PROD_PATH}/wp-content/plugins/" \
    "${TEMP_PLUGINS_DIR}/" \
    --exclude='.git' \
    --exclude='node_modules'

docker compose exec -T wordpress rm -rf /var/www/html/wp-content/plugins
docker compose cp "${TEMP_PLUGINS_DIR}" wordpress:/var/www/html/wp-content/plugins
docker compose exec -T wordpress chown -R www-data:www-data /var/www/html/wp-content/plugins

rm -rf "${TEMP_PLUGINS_DIR}"
print_success "Plugins synced"

# ============================================================================
# Step 2: Sync Themes (optional)
# ============================================================================
print_step "2/8" "Checking themes..."

if [ -n "$THEME_SLUGS" ]; then
    for theme_slug in $THEME_SLUGS; do
        if docker compose exec -T wordpress test -d "/var/www/html/wp-content/themes/${theme_slug}"; then
            print_info "Theme '$theme_slug' exists locally, skipping to preserve changes"
        else
            print_info "Syncing theme '$theme_slug' from remote..."

            TEMP_THEME_DIR="${BACKUP_DIR}/temp_theme_${theme_slug}"
            rm -rf "${TEMP_THEME_DIR}"
            mkdir -p "${TEMP_THEME_DIR}"

            rsync -avz --delete \
                -e "${SSH_CMD}" \
                "${PROD_SERVER}:${PROD_PATH}/wp-content/themes/${theme_slug}/" \
                "${TEMP_THEME_DIR}/" \
                --exclude='.git' \
                --exclude='node_modules'

            docker compose exec -T wordpress mkdir -p "/var/www/html/wp-content/themes/${theme_slug}"
            docker compose cp "${TEMP_THEME_DIR}/." "wordpress:/var/www/html/wp-content/themes/${theme_slug}"
            docker compose exec -T wordpress chown -R www-data:www-data "/var/www/html/wp-content/themes/${theme_slug}"

            rm -rf "${TEMP_THEME_DIR}"
            print_success "Theme '$theme_slug' synced"
        fi
    done
else
    print_info "No theme slugs specified (PROD_THEME_SLUGS)"
fi

# ============================================================================
# Step 3: Export Remote Database
# ============================================================================
print_step "3/8" "Exporting database from remote..."

$SSH_CMD "$PROD_SERVER" "cd ${PROD_PATH} && wp db export ~/${DB_TEMP_NAME} --allow-root 2>/dev/null || mysqldump -h ${PROD_DB_HOST:-localhost} -u ${PROD_DB_USER} -p'${PROD_DB_PASSWORD}' ${PROD_DB_NAME} > ~/${DB_TEMP_NAME}"

$SCP_CMD "${PROD_SERVER}:~/${DB_TEMP_NAME}" "${TEMP_FILE}"

if [ ! -s "${TEMP_FILE}" ]; then
    print_error "Failed to download database"
    exit 1
fi

$SSH_CMD "$PROD_SERVER" "rm ~/${DB_TEMP_NAME}"
print_success "Database exported ($(du -h "${TEMP_FILE}" | cut -f1))"

# ============================================================================
# Step 4: Backup Local Database
# ============================================================================
print_step "4/8" "Backing up local database..."

LOCAL_BACKUP="${BACKUP_DIR}/local_backup_${TIMESTAMP}.sql"
docker compose exec -T mysql mysqldump -u root -p"${DB_ROOT_PASSWORD}" "${DB_NAME}" > "${LOCAL_BACKUP}" 2>/dev/null || true

if [ -s "${LOCAL_BACKUP}" ]; then
    gzip "${LOCAL_BACKUP}"
    print_success "Local backup: ${LOCAL_BACKUP}.gz"
else
    print_info "No existing database to backup"
    rm -f "${LOCAL_BACKUP}"
fi

# ============================================================================
# Step 5: Import Database
# ============================================================================
print_step "5/8" "Importing database..."

docker compose exec -T mysql mysql -u root -p"${DB_ROOT_PASSWORD}" -e "DROP DATABASE IF EXISTS ${DB_NAME}; CREATE DATABASE ${DB_NAME};" 2>/dev/null
docker compose exec -T mysql mysql -u root -p"${DB_ROOT_PASSWORD}" "${DB_NAME}" < "${TEMP_FILE}"

print_success "Database imported"

# ============================================================================
# Step 6: URL Replacement
# ============================================================================
print_step "6/8" "Replacing URLs..."

docker compose exec -T wordpress wp --allow-root search-replace "${SOURCE_SITE}" "${DESTINATION_SITE}" --all-tables --skip-columns=guid 2>/dev/null
docker compose exec -T wordpress wp --allow-root option update siteurl "${DESTINATION_SITE}" 2>/dev/null
docker compose exec -T wordpress wp --allow-root option update home "${DESTINATION_SITE}" 2>/dev/null

print_success "URLs updated"

# ============================================================================
# Step 7: Local Configuration
# ============================================================================
print_step "7/8" "Applying local configuration..."

# Block search engines
docker compose exec -T wordpress wp --allow-root option update blog_public 0 2>/dev/null
print_info "Search engines blocked"

# Update admin email
LOCAL_ADMIN_EMAIL="${LOCAL_ADMIN_EMAIL:-dev@localhost}"
docker compose exec -T wordpress wp --allow-root option update admin_email "${LOCAL_ADMIN_EMAIL}" 2>/dev/null
docker compose exec -T wordpress wp --allow-root option update new_admin_email "${LOCAL_ADMIN_EMAIL}" 2>/dev/null || true
print_info "Admin email: ${LOCAL_ADMIN_EMAIL}"

# Deactivate caching plugins
docker compose exec -T wordpress wp --allow-root plugin deactivate wp-rocket 2>/dev/null || true
docker compose exec -T wordpress wp --allow-root plugin deactivate w3-total-cache 2>/dev/null || true
docker compose exec -T wordpress wp --allow-root plugin deactivate wp-super-cache 2>/dev/null || true

# ============================================================================
# Step 8: Flush Caches
# ============================================================================
print_step "8/8" "Flushing caches..."

docker compose exec -T wordpress wp --allow-root cache flush 2>/dev/null || true
docker compose exec -T wordpress wp --allow-root rewrite flush 2>/dev/null || true

print_success "Caches flushed"

# Post-processing hook
if [ -f "$REPO_ROOT/sync-post-process.sh" ]; then
    print_info "Running post-processing hook..."
    bash "$REPO_ROOT/sync-post-process.sh"
fi

# Cleanup old backups
print_info "Cleaning up old backups..."
cd "${BACKUP_DIR}"
ls -t prod_db_*.sql 2>/dev/null | tail -n +$((KEEP_BACKUPS + 1)) | xargs -r rm
ls -t local_backup_*.sql.gz 2>/dev/null | tail -n +$((KEEP_BACKUPS + 1)) | xargs -r rm
cd - > /dev/null

# Summary
echo ""
print_header "Sync Complete!"
echo -e "  ${GREEN}✓${NC} Plugins synced"
echo -e "  ${GREEN}✓${NC} Database imported"
echo -e "  ${GREEN}✓${NC} URLs replaced"
echo -e "  ${GREEN}✓${NC} Search engines blocked"
echo -e "  ${GREEN}✓${NC} Admin email updated"
echo ""
echo -e "  ${CYAN}Site:${NC}        $DESTINATION_SITE"
echo -e "  ${CYAN}Admin:${NC}       $DESTINATION_SITE/wp-admin"
echo -e "  ${CYAN}phpMyAdmin:${NC}  http://localhost:${PMA_PORT}"
echo ""
echo -e "  ${DIM}Database backup: ${TEMP_FILE}${NC}"
echo ""
