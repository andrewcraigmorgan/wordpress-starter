#!/bin/bash

###############################################################################
# WordPress Deployment Script
# Deploys WordPress files and database to remote production server
# Note: For Bitbucket-based deployments, this is primarily used for manual
# deployments. Automated deployments should use the Bitbucket Pipeline.
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
WORDPRESS_DIR="./wordpress"

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

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --files-only      Deploy only files (no database)"
    echo "  --db-only         Deploy only database (no files)"
    echo "  --dry-run         Show what would be deployed without actually deploying"
    echo "  --skip-backup     Skip creating backup on remote server"
    echo "  -h, --help        Show this help message"
    echo ""
}

# Parse command line arguments
DEPLOY_FILES=true
DEPLOY_DB=true
DRY_RUN=false
SKIP_BACKUP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --files-only)
            DEPLOY_DB=false
            shift
            ;;
        --db-only)
            DEPLOY_FILES=false
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Check required variables
if [ -z "$PROD_SERVER" ] || [ -z "$PROD_PATH" ]; then
    print_error "Production server configuration is incomplete in .env file"
    print_info "Required: PROD_SERVER, PROD_PATH"
    exit 1
fi

# Check if WordPress directory exists
if [ ! -d "$WORDPRESS_DIR" ]; then
    print_error "WordPress directory not found: $WORDPRESS_DIR"
    exit 1
fi

# SSH command setup
SSH_CMD="ssh"
if [ -n "$PROD_SSH_KEY" ]; then
    SSH_CMD="ssh -i $PROD_SSH_KEY"
fi

# Display deployment plan
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}WordPress Deployment Script${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo "Target server: ${PROD_SERVER}"
echo "Target path: ${PROD_PATH}"
echo "Deploy files: $([ "$DEPLOY_FILES" = true ] && echo 'YES' || echo 'NO')"
echo "Deploy database: $([ "$DEPLOY_DB" = true ] && echo 'YES' || echo 'NO')"
echo "Dry run: $([ "$DRY_RUN" = true ] && echo 'YES' || echo 'NO')"
echo "Skip backup: $([ "$SKIP_BACKUP" = true ] && echo 'YES' || echo 'NO')"
echo ""

if [ "$DRY_RUN" = false ]; then
    echo -e "${RED}WARNING: This will deploy changes to production!${NC}"
    echo ""
    read -p "Continue? (yes/no): " CONFIRM

    if [ "$CONFIRM" != "yes" ]; then
        print_message "Deployment cancelled."
        exit 0
    fi
fi

# Create backups directory
mkdir -p "${BACKUP_DIR}"

# Step 1: Backup production (if not skipped)
if [ "$SKIP_BACKUP" = false ] && [ "$DRY_RUN" = false ]; then
    print_message "Step 1: Creating backup of production..."

    # Backup files
    if [ "$DEPLOY_FILES" = true ]; then
        print_info "Backing up production files..."
        $SSH_CMD "$PROD_SERVER" "cd ${PROD_PATH} && tar -czf /tmp/wp_backup_${TIMESTAMP}.tar.gz --exclude='*.log' --exclude='wp-content/cache/*' ."
        print_message "Production files backed up on server"
    fi

    # Backup database
    if [ "$DEPLOY_DB" = true ]; then
        print_info "Backing up production database..."
        if [ -n "$PROD_DB_NAME" ] && [ -n "$PROD_DB_USER" ] && [ -n "$PROD_DB_PASSWORD" ]; then
            $SSH_CMD "$PROD_SERVER" "mysqldump -h ${PROD_DB_HOST:-localhost} -u ${PROD_DB_USER} -p'${PROD_DB_PASSWORD}' ${PROD_DB_NAME} --single-transaction | gzip > /tmp/wp_db_backup_${TIMESTAMP}.sql.gz"
            print_message "Production database backed up on server"
        else
            print_warning "Database credentials not configured, skipping database backup"
        fi
    fi
else
    print_warning "Skipping backup step"
fi

# Step 2: Deploy files
if [ "$DEPLOY_FILES" = true ]; then
    print_message "Step 2: Deploying files to production..."

    RSYNC_OPTS="-avz --delete"
    if [ "$DRY_RUN" = true ]; then
        RSYNC_OPTS="${RSYNC_OPTS} --dry-run"
    fi

    # Add SSH key if specified
    if [ -n "$PROD_SSH_KEY" ]; then
        RSYNC_OPTS="${RSYNC_OPTS} -e 'ssh -i ${PROD_SSH_KEY}'"
    fi

    # Exclude patterns
    RSYNC_OPTS="${RSYNC_OPTS} --exclude='.git' --exclude='*.log' --exclude='wp-config.php' --exclude='.env'"
    RSYNC_OPTS="${RSYNC_OPTS} --exclude='wp-content/cache/*' --exclude='wp-content/uploads/*'"

    print_info "Syncing files..."
    eval rsync $RSYNC_OPTS "${WORDPRESS_DIR}/" "${PROD_SERVER}:${PROD_PATH}/"

    if [ "$DRY_RUN" = false ]; then
        # Set proper permissions
        print_info "Setting file permissions..."
        $SSH_CMD "$PROD_SERVER" "cd ${PROD_PATH} && find . -type f -exec chmod 644 {} \; && find . -type d -exec chmod 755 {} \;"
        print_message "Files deployed successfully"
    else
        print_info "Dry run completed - no files were actually transferred"
    fi
else
    print_warning "Skipping file deployment"
fi

# Step 3: Deploy database
if [ "$DEPLOY_DB" = true ]; then
    print_message "Step 3: Deploying database to production..."

    if [ -z "$PROD_DB_NAME" ] || [ -z "$PROD_DB_USER" ] || [ -z "$PROD_DB_PASSWORD" ]; then
        print_error "Database credentials not configured in .env"
        exit 1
    fi

    # Export local database
    LOCAL_DB_DUMP="${BACKUP_DIR}/local_db_${TIMESTAMP}.sql"
    print_info "Exporting local database..."
    docker compose exec -T mysql mysqldump -u root -p"${DB_ROOT_PASSWORD}" "${DB_NAME}" > "${LOCAL_DB_DUMP}"
    gzip "${LOCAL_DB_DUMP}"
    LOCAL_DB_DUMP="${LOCAL_DB_DUMP}.gz"

    if [ "$DRY_RUN" = false ]; then
        # Upload database dump
        print_info "Uploading database dump to production..."
        if [ -n "$PROD_SSH_KEY" ]; then
            scp -i "$PROD_SSH_KEY" "${LOCAL_DB_DUMP}" "${PROD_SERVER}:/tmp/deploy_db_${TIMESTAMP}.sql.gz"
        else
            scp "${LOCAL_DB_DUMP}" "${PROD_SERVER}:/tmp/deploy_db_${TIMESTAMP}.sql.gz"
        fi

        # Import database on production
        print_info "Importing database on production server..."
        $SSH_CMD "$PROD_SERVER" "gunzip -c /tmp/deploy_db_${TIMESTAMP}.sql.gz | mysql -h ${PROD_DB_HOST:-localhost} -u ${PROD_DB_USER} -p'${PROD_DB_PASSWORD}' ${PROD_DB_NAME}"

        # Clean up remote temp file
        $SSH_CMD "$PROD_SERVER" "rm /tmp/deploy_db_${TIMESTAMP}.sql.gz"

        print_message "Database deployed successfully"
    else
        print_info "Dry run - database would be exported and uploaded"
    fi

    print_info "Local database dump saved: ${LOCAL_DB_DUMP}"
else
    print_warning "Skipping database deployment"
fi

# Step 4: Clear caches (if not dry run)
if [ "$DRY_RUN" = false ]; then
    print_message "Step 4: Clearing caches on production..."

    # Try to flush WordPress cache using WP-CLI if available
    $SSH_CMD "$PROD_SERVER" "cd ${PROD_PATH} && wp cache flush 2>/dev/null || true"

    # Clear opcache by touching a PHP file
    $SSH_CMD "$PROD_SERVER" "cd ${PROD_PATH} && touch index.php"

    print_message "Caches cleared"
fi

# Summary
echo ""
echo -e "${GREEN}========================================${NC}"
if [ "$DRY_RUN" = true ]; then
    echo -e "${BLUE}Deployment dry run completed!${NC}"
else
    echo -e "${GREEN}Deployment completed successfully!${NC}"
fi
echo -e "${GREEN}========================================${NC}"
echo ""

if [ "$DRY_RUN" = false ]; then
    if [ "$SKIP_BACKUP" = false ]; then
        echo "Production backups created on server:"
        echo "  - Files: /tmp/wp_backup_${TIMESTAMP}.tar.gz"
        echo "  - Database: /tmp/wp_db_backup_${TIMESTAMP}.sql.gz"
        echo ""
        echo -e "${YELLOW}Note: Remember to move these backups to a permanent location!${NC}"
        echo ""
    fi

    if [ "$DEPLOY_DB" = true ]; then
        echo "Local database dump: ${LOCAL_DB_DUMP}"
        echo ""
    fi

    echo "Deployment completed at: $(date)"
else
    echo "This was a dry run - no changes were made to production"
fi
echo ""
