#!/bin/bash

###############################################################################
# WordPress Production to Local Database Sync Script
# This script downloads the production database and imports it to your local
# development environment for testing and development purposes.
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check required variables
if [ -z "$PROD_SERVER" ] || [ -z "$PROD_DB_NAME" ] || [ -z "$PROD_DB_USER" ] || [ -z "$PROD_DB_PASSWORD" ]; then
    print_error "Production database configuration is incomplete in .env file"
    exit 1
fi

# Confirmation prompt
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}WordPress Database Sync${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo "This will:"
echo "  1. Export database from production server: ${PROD_SERVER}"
echo "  2. Import it to local Docker container"
echo ""
echo -e "${RED}WARNING: This will OVERWRITE your local database!${NC}"
echo ""
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    print_message "Operation cancelled."
    exit 0
fi

# Step 1: Export database from production
print_message "Step 1/5: Exporting database from production server..."

SSH_CMD="ssh"
if [ -n "$PROD_SSH_KEY" ]; then
    SSH_CMD="ssh -i $PROD_SSH_KEY"
fi

# Export database on production server
$SSH_CMD "$PROD_SERVER" "mysqldump -h ${PROD_DB_HOST:-localhost} -u ${PROD_DB_USER} -p'${PROD_DB_PASSWORD}' ${PROD_DB_NAME} --single-transaction --quick --lock-tables=false | gzip" > "${TEMP_FILE_GZ}"

if [ ! -s "${TEMP_FILE_GZ}" ]; then
    print_error "Failed to export database from production"
    exit 1
fi

print_message "Database exported successfully ($(du -h "${TEMP_FILE_GZ}" | cut -f1))"

# Step 2: Decompress the file
print_message "Step 2/5: Decompressing database dump..."
gunzip "${TEMP_FILE_GZ}"

# Step 3: Backup current local database (optional)
print_message "Step 3/5: Creating backup of current local database..."
LOCAL_BACKUP="${BACKUP_DIR}/local_backup_${TIMESTAMP}.sql"

docker compose exec -T mysql mysqldump -u root -p"${DB_ROOT_PASSWORD}" "${DB_NAME}" > "${LOCAL_BACKUP}" 2>/dev/null || true

if [ -s "${LOCAL_BACKUP}" ]; then
    gzip "${LOCAL_BACKUP}"
    print_message "Local database backed up to ${LOCAL_BACKUP}.gz"
else
    print_warning "No existing local database found to backup"
    rm -f "${LOCAL_BACKUP}"
fi

# Step 4: Import to local database
print_message "Step 4/5: Importing production database to local Docker container..."

# Drop and recreate database
docker compose exec -T mysql mysql -u root -p"${DB_ROOT_PASSWORD}" -e "DROP DATABASE IF EXISTS ${DB_NAME}; CREATE DATABASE ${DB_NAME};" 2>/dev/null

# Import the database
docker compose exec -T mysql mysql -u root -p"${DB_ROOT_PASSWORD}" "${DB_NAME}" < "${TEMP_FILE}"

print_message "Database imported successfully"

# Step 5: Update site URL for local environment (using WP-CLI)
print_message "Step 5/5: Updating site URLs for local environment..."

if [ -n "$WP_HOME" ] && [ -n "$WP_SITEURL" ]; then
    docker compose exec -T wordpress wp --allow-root search-replace "${PROD_WP_HOME:-https://yourproductionsite.com}" "${WP_HOME}" --skip-columns=guid 2>/dev/null || print_warning "Could not update WP_HOME URL"
    docker compose exec -T wordpress wp --allow-root option update siteurl "${WP_SITEURL}" 2>/dev/null || print_warning "Could not update siteurl"
    docker compose exec -T wordpress wp --allow-root option update home "${WP_HOME}" 2>/dev/null || print_warning "Could not update home URL"
    print_message "Site URLs updated"
else
    print_warning "WP_HOME or WP_SITEURL not set in .env - skipping URL replacement"
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
echo -e "${GREEN}Database sync completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Production database has been imported to your local environment."
echo "Production dump saved to: ${TEMP_FILE}"
echo "Local backup saved to: ${LOCAL_BACKUP}.gz (if existed)"
echo ""
echo "Access your site at: ${WP_HOME}"
echo "PHPMyAdmin at: http://localhost:${PMA_PORT}"
echo ""
