#!/bin/bash

###############################################################################
# Enhanced WordPress Production to Local Sync Script
# This script replicates the full staging sync workflow:
# - Syncs plugins from production
# - Syncs database with backup
# - URL replacement (including Elementor)
# - Search engine blocking
# - Admin email updates
# - Cache management
# - Post-processing hooks
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}Error: .env file not found. Copy .env.example to .env and configure it.${NC}"
    exit 1
fi

# Configuration
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BACKUP_DIR:-./backups}"
TEMP_FILE="${BACKUP_DIR}/prod_db_${TIMESTAMP}.sql"
TEMP_FILE_GZ="${TEMP_FILE}.gz"
KEEP_BACKUPS="${KEEP_BACKUPS:-7}"
DB_TEMP_NAME="db_sync_tool.sql"
WORDPRESS_DIR="./wordpress"
THEME_SLUGS="${PROD_THEME_SLUGS:-${PROD_THEME_SLUG:-}}"

# Create backup directory if it doesn't exist
mkdir -p "${BACKUP_DIR}"

# Function to print colored messages
print_message() {
    echo -e "${GREEN}[$(date +%H:%M:%S)]${NC} $1"
}

print_error() {
    echo -e "${RED}[$(date +%H:%M:%S)] ERROR:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[$(date +%H:%M:%S)] WARNING:${NC} $1"
}

print_info() {
    echo -e "${BLUE}[$(date +%H:%M:%S)] INFO:${NC} $1"
}

# Check required variables
if [ -z "$PROD_SERVER" ] || [ -z "$PROD_DB_NAME" ] || [ -z "$PROD_DB_USER" ] || [ -z "$PROD_DB_PASSWORD" ]; then
    print_error "Production server configuration is incomplete in .env file"
    exit 1
fi

if [ -z "$PROD_PATH" ]; then
    print_error "PROD_PATH is not set in .env file"
    exit 1
fi

# Check if Docker containers are running
if ! docker compose ps | grep -q "Up"; then
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

# Starting sync process
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Enhanced WordPress Production Sync${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
print_info "Syncing from: ${PROD_SERVER}"
echo ""

# Get source and destination URLs
print_message "Getting site URLs..."
SOURCE_SITE="${PROD_WP_HOME}"
DESTINATION_SITE=$(docker compose exec -T wordpress wp --allow-root option get siteurl 2>/dev/null | tr -d '\r' || echo "${WP_HOME}")

if [ -z "$DESTINATION_SITE" ]; then
    DESTINATION_SITE="${WP_HOME}"
fi

print_info "Source URL: ${SOURCE_SITE}"
print_info "Destination URL: ${DESTINATION_SITE}"

# Step 1: Sync plugins and theme from production
print_message "Step 1/9: Syncing plugins and theme from production..."

# Create temporary directory for rsync
TEMP_PLUGINS_DIR="${BACKUP_DIR}/temp_plugins"
mkdir -p "${TEMP_PLUGINS_DIR}"

print_info "Downloading plugins from production to temporary directory"
rsync -avz --delete \
    -e "${SSH_CMD}" \
    "${PROD_SERVER}:${PROD_PATH}/wp-content/plugins/" \
    "${TEMP_PLUGINS_DIR}/"

print_info "Removing existing plugins directory in container"
docker compose exec -T wordpress rm -rf /var/www/html/wp-content/plugins

print_info "Copying plugins into container with proper permissions"
docker compose cp "${TEMP_PLUGINS_DIR}" wordpress:/var/www/html/wp-content/plugins

print_info "Fixing file permissions in container"
docker compose exec -T wordpress chown -R www-data:www-data /var/www/html/wp-content/plugins

print_info "Cleaning up temporary directory"
rm -rf "${TEMP_PLUGINS_DIR}"

print_message "Plugins synced successfully"

if [ -n "$THEME_SLUGS" ]; then
    for theme_slug in $THEME_SLUGS; do
        print_message "Checking theme '${theme_slug}' status..."

        if docker compose exec -T wordpress test -d "/var/www/html/wp-content/themes/${theme_slug}"; then
            print_info "Theme directory already exists; skipping remote sync to avoid overwriting local changes"
        else
            print_message "Theme '${theme_slug}' not found locally; pulling from production..."

            TEMP_THEME_DIR="${BACKUP_DIR}/temp_theme_${theme_slug}"
            rm -rf "${TEMP_THEME_DIR}"
            mkdir -p "${TEMP_THEME_DIR}"

            print_info "Downloading theme from production to temporary directory"
            rsync -avz --delete \
                -e "${SSH_CMD}" \
                "${PROD_SERVER}:${PROD_PATH}/wp-content/themes/${theme_slug}/" \
                "${TEMP_THEME_DIR}/"

            print_info "Preparing theme directory in container"
            docker compose exec -T wordpress mkdir -p "/var/www/html/wp-content/themes/${theme_slug}"

            print_info "Copying theme into container with proper permissions"
            docker compose cp "${TEMP_THEME_DIR}/." "wordpress:/var/www/html/wp-content/themes/${theme_slug}"

            print_info "Fixing file permissions in container"
            docker compose exec -T wordpress chown -R www-data:www-data "/var/www/html/wp-content/themes/${theme_slug}"

            print_info "Cleaning up temporary directory"
            rm -rf "${TEMP_THEME_DIR}"

            print_message "Theme '${theme_slug}' synced successfully"
        fi
    done
else
    print_warning "PROD_THEME_SLUGS not set; skipping theme sync"
fi

# Step 2: Export database from production
print_message "Step 2/9: Exporting database from production server..."

print_info "Creating database backup on production server"
$SSH_CMD "$PROD_SERVER" "cd ${PROD_PATH} && wp db export ~/${DB_TEMP_NAME} --allow-root 2>/dev/null || mysqldump -h ${PROD_DB_HOST:-localhost} -u ${PROD_DB_USER} -p'${PROD_DB_PASSWORD}' ${PROD_DB_NAME} > ~/${DB_TEMP_NAME}"

print_info "Downloading database backup from production"
$SCP_CMD "${PROD_SERVER}:~/${DB_TEMP_NAME}" "${TEMP_FILE}"

if [ ! -s "${TEMP_FILE}" ]; then
    print_error "Failed to download database from production"
    exit 1
fi

print_info "Removing remote database backup"
$SSH_CMD "$PROD_SERVER" "rm ~/${DB_TEMP_NAME}"

print_message "Database exported successfully ($(du -h "${TEMP_FILE}" | cut -f1))"

# Step 3: Backup current local database
print_message "Step 3/9: Creating backup of current local database..."
LOCAL_BACKUP="${BACKUP_DIR}/local_backup_${TIMESTAMP}.sql"

docker compose exec -T mysql mysqldump -u root -p"${DB_ROOT_PASSWORD}" "${DB_NAME}" > "${LOCAL_BACKUP}" 2>/dev/null || true

if [ -s "${LOCAL_BACKUP}" ]; then
    gzip "${LOCAL_BACKUP}"
    print_message "Local database backed up to ${LOCAL_BACKUP}.gz"
else
    print_warning "No existing local database found to backup"
    rm -f "${LOCAL_BACKUP}"
fi

# Step 4: Import production database to local
print_message "Step 4/9: Importing production database to local Docker container..."

# Drop and recreate database
print_info "Resetting local database"
docker compose exec -T mysql mysql -u root -p"${DB_ROOT_PASSWORD}" -e "DROP DATABASE IF EXISTS ${DB_NAME}; CREATE DATABASE ${DB_NAME};" 2>/dev/null

# Import the database
print_info "Importing database"
docker compose exec -T mysql mysql -u root -p"${DB_ROOT_PASSWORD}" "${DB_NAME}" < "${TEMP_FILE}"

print_message "Database imported successfully"

# Step 5: URL replacement
print_message "Step 5/9: Replacing URLs..."

# Standard search-replace (handles Elementor and all other data)
print_info "Running search-replace on all tables"
docker compose exec -T wordpress wp --allow-root search-replace "${SOURCE_SITE}" "${DESTINATION_SITE}" --all-tables --skip-columns=guid 2>/dev/null

# Update core options
docker compose exec -T wordpress wp --allow-root option update siteurl "${DESTINATION_SITE}" 2>/dev/null
docker compose exec -T wordpress wp --allow-root option update home "${DESTINATION_SITE}" 2>/dev/null

print_message "URLs updated successfully"

# Step 6: Block search engines
print_message "Step 6/9: Blocking search engines..."

docker compose exec -T wordpress wp --allow-root option update blog_public 0 2>/dev/null
print_info "Set 'Discourage search engines from indexing this site'"

# Step 7: Update admin email
print_message "Step 7/9: Updating admin email..."

LOCAL_ADMIN_EMAIL="${LOCAL_ADMIN_EMAIL:-dev.am@mtc.co.uk}"
docker compose exec -T wordpress wp --allow-root option update new_admin_email "${LOCAL_ADMIN_EMAIL}" 2>/dev/null || true
docker compose exec -T wordpress wp --allow-root option update admin_email "${LOCAL_ADMIN_EMAIL}" 2>/dev/null
print_info "Admin email updated to ${LOCAL_ADMIN_EMAIL}"

# Step 8: WP Rocket cache management
print_message "Step 8/9: Managing WP Rocket cache..."

if docker compose exec -T wordpress wp --allow-root plugin is-installed wp-rocket 2>/dev/null; then
    print_info "WP Rocket detected"

    # Try to install WP Rocket CLI if not present
    docker compose exec -T wordpress wp --allow-root package list 2>/dev/null | grep -q "wp-rocket-cli" || \
        docker compose exec -T wordpress wp --allow-root package install wp-media/wp-rocket-cli:trunk 2>/dev/null || \
        print_warning "Could not install WP Rocket CLI"

    # Clean and regenerate cache
    docker compose exec -T wordpress wp --allow-root rocket clean --confirm 2>/dev/null || print_warning "Could not clean WP Rocket cache"
    docker compose exec -T wordpress wp --allow-root rocket regenerate 2>/dev/null || print_warning "Could not regenerate WP Rocket cache"

    # Deactivate on local
    docker compose exec -T wordpress wp --allow-root plugin deactivate wp-rocket 2>/dev/null
    print_info "WP Rocket cache regenerated and plugin deactivated"
else
    print_info "WP Rocket not installed, skipping"
fi

# Step 9: Flush caches
print_message "Step 9/9: Flushing all caches..."

docker compose exec -T wordpress wp --allow-root cache flush 2>/dev/null || print_warning "Could not flush cache"
docker compose exec -T wordpress wp --allow-root rewrite flush 2>/dev/null || print_warning "Could not flush rewrite rules"

print_message "Caches flushed"

# Post-processing hook
if [ -f "sync-post-process.sh" ]; then
    print_message "Running post-processing hook..."
    bash sync-post-process.sh
elif [ -f "sync.php" ]; then
    print_message "Running PHP post-processing script..."
    docker compose exec -T wordpress php sync.php || print_warning "PHP post-processing script failed"
fi

# Clean up old backups
print_message "Cleaning up old backups (keeping last ${KEEP_BACKUPS})..."
cd "${BACKUP_DIR}"
ls -t prod_db_*.sql 2>/dev/null | tail -n +$((KEEP_BACKUPS + 1)) | xargs -r rm
ls -t local_backup_*.sql.gz 2>/dev/null | tail -n +$((KEEP_BACKUPS + 1)) | xargs -r rm
cd - > /dev/null

print_message "Keeping production dump: ${TEMP_FILE}"

# Summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Enhanced sync completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Summary:"
echo "  ✓ Plugins synced from production"
echo "  ✓ Database imported and URLs replaced"
echo "  ✓ Search engines blocked"
echo "  ✓ Admin email updated to ${LOCAL_ADMIN_EMAIL}"
echo "  ✓ Caches flushed"
echo ""
echo "Production dump saved to: ${TEMP_FILE}"
if [ -f "${LOCAL_BACKUP}.gz" ]; then
    echo "Local backup saved to: ${LOCAL_BACKUP}.gz"
fi
echo ""
echo "Access your site at: ${DESTINATION_SITE}"
echo "PHPMyAdmin at: http://localhost:${PMA_PORT}"
echo ""
echo -e "${YELLOW}Note: Search engine indexing is BLOCKED (blog_public = 0)${NC}"
echo ""
