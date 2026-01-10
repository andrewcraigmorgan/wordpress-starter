# Enhanced Production to Local Sync Guide

This guide explains the enhanced sync script that replicates your previous staging sync workflow in the Docker environment.

## Overview

The **sync-prod-to-local.sh** script provides a complete production-to-local synchronization workflow including:

✓ Plugin synchronization from production
✓ Database export and import with backups
✓ URL replacement (handles all content including Elementor)
✓ Search engine blocking
✓ Admin email updates
✓ WP Rocket cache management
✓ Post-processing hooks

## Quick Start

```bash
# Ensure Docker is running
docker compose up -d

# Run the enhanced sync
./sync-prod-to-local.sh
```

## What It Does (Step by Step)

### Step 1: Plugin Synchronization
- Removes local `wp-content/plugins/` directory
- Copies all plugins from production via rsync
- Ensures your local environment matches production plugins exactly

### Step 2: Database Export
- Connects to production server via SSH
- Exports production database using WP-CLI or mysqldump
- Downloads the database dump locally

### Step 3: Local Database Backup
- Creates a timestamped backup of your current local database
- Compresses and stores in `./backups/` directory
- Keeps last 7 backups by default (configurable)

### Step 4: Database Import
- Drops and recreates local database
- Imports production database
- Maintains database integrity

### Step 5: URL Replacement
- **Search-Replace**: Runs `wp search-replace --all-tables` (handles all content including Elementor)
- **Core Options**: Updates `siteurl` and `home` options
- Converts production URLs to local URLs (e.g., https://mylivesite.co.uk → http://localhost:8080)
- Skips `guid` column to preserve post GUIDs

### Step 6: Search Engine Blocking
- Sets `blog_public` option to `0`
- Prevents search engines from indexing your local site
- Equivalent to checking "Discourage search engines" in WordPress settings

### Step 7: Admin Email Update
- Updates `admin_email` to your local email (default: dev.am@mtc.co.uk)
- Updates `new_admin_email` as well
- Prevents client emails from being sent from local environment

### Step 8: WP Rocket Management
- Detects if WP Rocket is installed
- Installs WP Rocket CLI if needed
- Cleans and regenerates cache
- **Deactivates WP Rocket** on local (prevents caching issues during development)

### Step 9: Cache Flushing
- Flushes WordPress object cache
- Flushes rewrite rules
- Ensures clean state after sync

### Post-Processing Hooks
- Runs `sync-post-process.sh` if it exists (Bash hook)
- Runs `wordpress/sync.php` if it exists (PHP hook)
- Allows custom post-processing logic

## Configuration

### Required Variables in .env

```bash
# Production Server
PROD_SERVER=user@server.com
PROD_PATH=/home/user/public_html
PROD_DB_HOST=localhost
PROD_DB_NAME=database_name
PROD_DB_USER=database_user
PROD_DB_PASSWORD=database_password
PROD_SSH_KEY=~/.ssh/id_rsa
PROD_WP_HOME=https://yoursite.com

# Local Settings
WP_HOME=http://localhost:8080
LOCAL_ADMIN_EMAIL=dev.am@mtc.co.uk

# Backup Settings
BACKUP_DIR=./backups
KEEP_BACKUPS=7
```

### SSH Setup (Required First Time)

Before running sync scripts, ensure SSH access to production:

#### 1. Generate SSH Key Pair

```bash
# On your LOCAL machine (where Docker runs)
ssh-keygen -t rsa -b 4096 -C "wordpress-docker-sync"

# Accept default location (~/.ssh/id_rsa) or specify custom
# Optionally add passphrase for security
```

#### 2. Add Public Key to Production Server

```bash
# Easiest method - automatic
ssh-copy-id user@production-server.com

# Manual method
cat ~/.ssh/id_rsa.pub
# Copy output, then SSH to production and run:
# echo "ssh-rsa AAAA..." >> ~/.ssh/authorized_keys
```

#### 3. Test Connection

```bash
# This should connect WITHOUT password prompt
ssh user@production-server.com

# If successful, you're ready to sync!
```

#### 4. Configure .env

```bash
# Update PROD_SSH_KEY with your key path
PROD_SSH_KEY=~/.ssh/id_rsa

# Or if using custom location:
PROD_SSH_KEY=~/.ssh/wordpress_production
```

**Important:**
- Generate key on LOCAL machine, not production server
- Only the PUBLIC key (id_rsa.pub) goes on production server
- Private key stays on your local machine

## Comparison to Original Script

| Feature | Original Script | Docker Script | Status |
|---------|----------------|---------------|--------|
| Get live URL from Git config | ✓ | ✗ | Uses .env config instead |
| Plugin sync via rsync | ✓ | ✓ | ✓ Implemented |
| Database export | ✓ | ✓ | ✓ Implemented |
| Database backup | ✓ | ✓ | ✓ Implemented |
| Database import | ✓ | ✓ | ✓ Implemented |
| Elementor URL replace | ✓ | ✗ | Not needed - search-replace handles it |
| Search-replace URLs | ✓ | ✓ | ✓ Implemented (--all-tables) |
| Block search engines | ✓ | ✓ | ✓ Implemented |
| Update admin email | ✓ | ✓ | ✓ Implemented |
| WP Rocket management | ✓ | ✓ | ✓ Implemented |
| Cache flushing | ✓ | ✓ | ✓ Implemented |
| Run deploy.sh | ✓ | ✗ | Not needed (Docker handles this) |
| Run sync.php hook | ✓ | ✓ | ✓ Implemented |

## Differences from Original

### 1. No Git Config Lookup
**Original**: Retrieved live URL from Git remote config
**Docker**: Uses `PROD_WP_HOME` from `.env` file
**Why**: Simpler, more explicit configuration

### 2. No deploy.sh Execution
**Original**: Ran a separate `deploy.sh` script during sync
**Docker**: Not needed - Docker handles container configuration
**Why**: Docker environment is already properly configured

### 3. Docker-based WP-CLI
**Original**: Direct WP-CLI commands on host
**Docker**: Commands run inside WordPress container
**Format**: `docker compose exec -T wordpress wp --allow-root [command]`

### 4. Plugin Sync Uses rsync
**Original**: `rsync -ri` (interactive)
**Docker**: `rsync -avz --delete` (archive, compress, delete extra)
**Why**: More efficient for full directory sync

## Post-Processing Hooks

### Bash Hook: sync-post-process.sh

Create custom Bash commands that run after sync:

```bash
#!/bin/bash
# sync-post-process.sh

# Example: Deactivate additional plugins
docker compose exec -T wordpress wp --allow-root plugin deactivate wordfence

# Example: Clear transients
docker compose exec -T wordpress wp --allow-root transient delete --all

# Add your custom commands
```

### PHP Hook: wordpress/sync.php

Create custom PHP logic that runs after sync:

```php
<?php
// wordpress/sync.php
require_once __DIR__ . '/wp-load.php';

// Example: Update custom options
update_option('enable_notifications', false);

// Example: Modify user permissions
$user = get_user_by('email', 'dev.am@mtc.co.uk');
if ($user) {
    $user->set_role('administrator');
}

// Add your custom PHP logic
```

## Usage Examples

### Basic Sync

```bash
./sync-prod-to-local.sh
```

### Sync with Custom Admin Email

```bash
# Edit .env
LOCAL_ADMIN_EMAIL=myemail@company.com

# Run sync
./sync-prod-to-local.sh
```

### Sync Specific Plugins Only

If you want to sync only specific plugins, modify the script:

```bash
# In sync-prod-to-local.sh, replace the full plugin sync with:
rsync -avz -e "${SSH_CMD}" \
    "${PROD_SERVER}:${PROD_PATH}/wp-content/plugins/my-custom-plugin" \
    "${WORDPRESS_DIR}/wp-content/plugins/"
```

## Troubleshooting

### SSH Connection Fails

```bash
# Test SSH connection
ssh -i ~/.ssh/id_rsa user@server.com

# Check SSH key permissions
chmod 600 ~/.ssh/id_rsa

# Add to .env if using non-standard key
PROD_SSH_KEY=/path/to/your/key
```

### Plugin Sync Fails

```bash
# Ensure you have read permissions on production
ssh user@server.com "ls -la /home/user/public_html/wp-content/plugins"

# Check rsync is installed
which rsync
```

### Database Import Fails

```bash
# Check Docker MySQL is running
docker compose ps

# Check database credentials
docker compose exec mysql mysql -u root -p

# Review error messages in output
```

### URL Replacement Issues

If URLs aren't being replaced correctly:

```bash
# Manually run search-replace
docker compose exec wordpress wp --allow-root search-replace \
    "https://oldsite.com" "http://localhost:8080" --all-tables

# Check current site URLs
docker compose exec wordpress wp --allow-root option get siteurl
docker compose exec wordpress wp --allow-root option get home
```

### WP Rocket CLI Not Installing

This is non-critical - the script will continue if WP Rocket CLI installation fails.

```bash
# Manually install WP Rocket CLI
docker compose exec wordpress wp --allow-root package install wp-media/wp-rocket-cli:trunk

# Or skip WP Rocket management entirely by commenting out step 8 in the script
```

### Post-Processing Hook Not Running

```bash
# Ensure hooks are executable
chmod +x sync-post-process.sh

# Check if wordpress/sync.php exists
ls -la wordpress/sync.php

# Run hooks manually to test
bash sync-post-process.sh
docker compose exec wordpress php wordpress/sync.php
```

## Best Practices

1. **Always run sync with Docker running**
   ```bash
   docker compose up -d
   ./sync-prod-to-local.sh
   ```

2. **Review changes before syncing**
   - Check what plugins will be replaced
   - Ensure you have local backups if needed

3. **Keep backups**
   - Script keeps last 7 database backups automatically
   - Increase `KEEP_BACKUPS` in `.env` if needed

4. **Test locally before deploying**
   - Sync production to local
   - Make changes
   - Test thoroughly
   - Deploy via Bitbucket

5. **Use post-processing hooks**
   - Keep custom logic in hooks
   - Makes upgrades easier
   - Reusable across projects

## Advanced Configuration

### Exclude Plugins from Sync

Create a `.rsyncignore` file:

```bash
# Exclude specific plugins
--exclude 'plugin-name-1/'
--exclude 'plugin-name-2/'
```

Then modify sync script:

```bash
rsync -avz --delete --exclude-from='.rsyncignore' \
    -e "${SSH_CMD}" \
    "${PROD_SERVER}:${PROD_PATH}/wp-content/plugins" \
    "${WORDPRESS_DIR}/wp-content/"
```

### Keep Some Local Plugins

```bash
# Before plugin sync in script, backup local plugins:
mkdir -p /tmp/local-plugins-backup
cp -r wordpress/wp-content/plugins/my-dev-plugin /tmp/local-plugins-backup/

# After plugin sync, restore:
cp -r /tmp/local-plugins-backup/my-dev-plugin wordpress/wp-content/plugins/
```

### Sync Themes Too

Add theme syncing to the script:

```bash
# After plugin sync:
print_message "Syncing themes from production..."
rsync -avz --delete \
    -e "${SSH_CMD}" \
    "${PROD_SERVER}:${PROD_PATH}/wp-content/themes" \
    "${WORDPRESS_DIR}/wp-content/"
```

## Security Notes

1. **SSH Keys**: Use separate SSH keys for different environments
2. **Database Passwords**: Never commit `.env` file
3. **Admin Email**: Always update to prevent client notifications
4. **Search Engines**: Always blocked by default on local
5. **Backups**: Stored in `./backups/` which is excluded from Git

## Comparison to sync-prod-db.sh

You now have TWO sync scripts:

| Script | Use Case | Features |
|--------|----------|----------|
| **sync-prod-db.sh** | Database only | Simple DB sync with URL updates |
| **sync-prod-to-local.sh** | Complete sync | DB + Plugins + All features |

Use **sync-prod-to-local.sh** for full staging-like environment sync.
Use **sync-prod-db.sh** when you only need database updates.

## Support

For issues:
1. Check Docker is running: `docker compose ps`
2. Verify SSH access: `ssh user@production-server.com`
3. Review script output for specific errors
4. Check [README.md](README.md) for general Docker setup
5. Review logs: `docker compose logs -f`
