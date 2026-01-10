# WordPress Docker Development Environment

A complete Docker-based development environment for WordPress with PHP 8.3, including database sync, deployment scripts, and CI/CD via Bitbucket Pipelines.

## Features

- **PHP 8.3** with Apache
- **MySQL 8.0** database
- **PHPMyAdmin** for database management
- **WP-CLI** installed for command-line WordPress management
- **Bitbucket Pipelines** with automated testing and deployment
- Production database sync script
- Remote server deployment script
- Custom PHP configuration for large uploads
- Automated code quality checks and security scanning

## Prerequisites

- Docker and Docker Compose installed
- SSH access to production server (for sync and deployment)
- Bitbucket account and repository (for CI/CD)
- Git for version control

## Quick Start

### 1. Initial Setup

```bash
# Copy environment file and configure
cp .env.example .env

# Edit .env with your configuration
nano .env
```

### 2. Configure Environment Variables

Edit `.env` and set your values:

```bash
# Local WordPress Configuration
PROJECT_NAME=wordpress
WP_PORT=8080
WP_HOME=http://localhost:8080
WP_SITEURL=http://localhost:8080

# Database Configuration
DB_NAME=wordpress
DB_USER=wordpress
DB_PASSWORD=your_secure_password
DB_ROOT_PASSWORD=your_root_password

# Production Server (for deployment)
PROD_SERVER=user@your-production-server.com
PROD_PATH=/var/www/html
PROD_DB_NAME=wordpress_prod
PROD_DB_USER=wordpress_user
PROD_DB_PASSWORD=production_password
PROD_SSH_KEY=~/.ssh/id_rsa
```

### 3. Start the Environment

```bash
# Build and start containers
docker compose up -d

# View logs
docker compose logs -f

# Stop containers
docker compose down
```

### 4. Install WordPress

#### Option A: Fresh Installation

Visit `http://localhost:8080` and follow the WordPress installation wizard.

#### Option B: Import Existing Site

If you have an existing WordPress site:

1. Copy your WordPress files to the `wordpress` directory
2. Sync the production database (see below)

## WordPress Management

### Access Points

- **WordPress Site**: http://localhost:8080
- **PHPMyAdmin**: http://localhost:8081
- **MySQL Port**: 3306 (exposed on host)

### WP-CLI Commands

```bash
# Run WP-CLI commands
docker compose exec wordpress wp --allow-root [command]

# Examples:
docker compose exec wordpress wp --allow-root plugin list
docker compose exec wordpress wp --allow-root theme list
docker compose exec wordpress wp --allow-root user list
docker compose exec wordpress wp --allow-root cache flush
```

## Database Sync Scripts

You have two sync scripts to choose from:

### Enhanced Sync (Recommended): sync-prod-to-local.sh

The **complete staging sync workflow** that replicates your existing process:

```bash
./sync-prod-to-local.sh
```

**Features:**
- ✓ Syncs plugins from production
- ✓ Syncs database with backups
- ✓ URL replacement (handles all content)
- ✓ Blocks search engines
- ✓ Updates admin email
- ✓ Manages WP Rocket cache
- ✓ Post-processing hooks

See [SYNC_GUIDE.md](SYNC_GUIDE.md) for complete documentation.

### Simple Database Sync: sync-prod-db.sh

A lightweight script for **database-only** sync:

```bash
./sync-prod-db.sh
```

**What It Does:**
1. Exports database from production server via SSH
2. Creates a backup of your current local database
3. Imports production database to local Docker container
4. Updates site URLs to match local environment
5. Keeps last 7 backups (configurable via `KEEP_BACKUPS` in `.env`)

### Configuration

Ensure these variables are set in `.env`:

```bash
PROD_SERVER=user@production-server.com
PROD_DB_HOST=localhost
PROD_DB_NAME=wordpress_prod
PROD_DB_USER=wordpress_prod
PROD_DB_PASSWORD=changeme
PROD_SSH_KEY=~/.ssh/id_rsa
PROD_WP_HOME=https://yourproductionsite.com
LOCAL_ADMIN_EMAIL=dev.am@mtc.co.uk
```

### SSH Setup for Production Access

The sync scripts require SSH access to your production server. Set this up once:

#### 1. Generate SSH Key (if you don't have one)

```bash
# On your local machine (where Docker runs)
ssh-keygen -t rsa -b 4096 -C "wordpress-docker-sync"

# Press Enter to use default location (~/.ssh/id_rsa)
# Or specify custom: ~/.ssh/wordpress_production
# Optionally enter a passphrase (or press Enter for none)
```

#### 2. Copy Public Key to Production Server

```bash
# Option A: Use ssh-copy-id (easiest)
ssh-copy-id user@production-server.com

# Option B: Manual copy
cat ~/.ssh/id_rsa.pub
# Copy the output, then on production server:
# echo "ssh-rsa AAAA...your-key..." >> ~/.ssh/authorized_keys
```

#### 3. Test SSH Connection

```bash
# Should connect without password prompt
ssh user@production-server.com

# If using custom key location:
ssh -i ~/.ssh/custom_key user@production-server.com
```

#### 4. Update .env with SSH Key Path

```bash
# If using default key
PROD_SSH_KEY=~/.ssh/id_rsa

# If using custom key
PROD_SSH_KEY=~/.ssh/wordpress_production
```

**Security Notes:**
- Keep your private key secure (never commit to Git)
- Use `chmod 600 ~/.ssh/id_rsa` to set correct permissions
- Consider using SSH key passphrases for added security
- Use separate keys for different environments/projects

### Troubleshooting

- Ensure Docker containers are running: `docker compose ps`
- Verify SSH access: `ssh -i ~/.ssh/id_rsa user@production-server.com`
- Check SSH key permissions: `chmod 600 ~/.ssh/id_rsa`
- Check production database credentials by testing SSH connection
- View script output for specific error messages

## Deployment Script

The `deploy.sh` script deploys your local changes to the production server.

### Usage

```bash
# Full deployment (files + database)
./deploy.sh

# Files only
./deploy.sh --files-only

# Database only
./deploy.sh --db-only

# Dry run (see what would happen)
./deploy.sh --dry-run

# Skip backup
./deploy.sh --skip-backup

# Help
./deploy.sh --help
```

### What It Does

1. Creates backups of production files and database (unless `--skip-backup`)
2. Syncs files using rsync (excluding logs, cache, uploads, .env)
3. Exports and uploads local database to production
4. Sets proper file permissions
5. Clears caches

### Configuration

Required variables in `.env`:

```bash
PROD_SERVER=user@production-server.com
PROD_PATH=/var/www/html
PROD_DB_NAME=wordpress_prod
PROD_DB_USER=wordpress_prod
PROD_DB_PASSWORD=changeme
PROD_SSH_KEY=~/.ssh/id_rsa
```

### Best Practices

1. **Always test with `--dry-run` first**
2. Keep backups enabled (remove `--skip-backup` only if you have other backup solutions)
3. Test database deployments on staging first
4. Manually transfer uploads directory if needed (excluded by default)
5. Keep production backups in a permanent location

## File Structure

```
.
├── docker compose.yml      # Docker services configuration
├── Dockerfile              # Custom WordPress image with PHP 8.3
├── uploads.ini             # PHP upload limits configuration
├── .env                    # Environment variables (create from .env.example)
├── .env.example            # Environment variables template
├── .gitignore              # Git ignore rules
├── sync-prod-db.sh         # Production to local database sync script
├── deploy.sh               # Deployment script
├── README.md               # This file
├── wordpress/              # WordPress files (auto-created)
├── backups/                # Database backups (auto-created)
└── mysql-init/             # MySQL initialization scripts (optional)
```

## Common Tasks

### Backup Local Database

```bash
docker compose exec mysql mysqldump -u root -p"${DB_ROOT_PASSWORD}" wordpress > backup.sql
```

### Restore Local Database

```bash
docker compose exec -T mysql mysql -u root -p"${DB_ROOT_PASSWORD}" wordpress < backup.sql
```

### Reset Everything

```bash
# Stop and remove all containers, volumes, and images
docker compose down -v
rm -rf wordpress/

# Start fresh
docker compose up -d
```

### View Container Logs

```bash
# All containers
docker compose logs -f

# Specific container
docker compose logs -f wordpress
docker compose logs -f mysql
```

### Access MySQL Directly

```bash
docker compose exec mysql mysql -u root -p"${DB_ROOT_PASSWORD}"
```

### Update WordPress Core

```bash
docker compose exec wordpress wp --allow-root core update
```

### Install Plugin

```bash
docker compose exec wordpress wp --allow-root plugin install [plugin-name] --activate
```

## PHP Configuration

Custom PHP settings are defined in `uploads.ini`:

- Upload max filesize: 256M
- Post max size: 256M
- Max execution time: 300s
- Memory limit: 512M

To modify, edit `uploads.ini` and restart containers:

```bash
docker compose restart wordpress
```

## Security Notes

1. **Never commit `.env` file** - it contains sensitive credentials
2. **Use strong passwords** for database and WordPress admin
3. **Keep SSH keys secure** - use appropriate file permissions (600)
4. **Regular backups** - both database and files
5. **Update regularly** - keep WordPress, plugins, and themes updated

## Troubleshooting

### Port Already in Use

If ports 8080 or 8081 are already in use, change them in `.env`:

```bash
WP_PORT=8082
PMA_PORT=8083
```

Then restart: `docker compose down && docker compose up -d`

### Permission Issues

```bash
# Fix WordPress file permissions
docker compose exec wordpress chown -R www-data:www-data /var/www/html
```

### Database Connection Issues

1. Check MySQL is running: `docker compose ps`
2. Verify credentials in `.env`
3. Check logs: `docker compose logs mysql`

### Sync Script Fails

1. Test SSH connection: `ssh user@production-server.com`
2. Verify database credentials on production server
3. Ensure sufficient disk space in `./backups` directory
4. Check production server has `mysqldump` installed

### Deployment Script Fails

1. Run with `--dry-run` to see what would happen
2. Verify SSH access and credentials
3. Check rsync is installed locally
4. Verify target directory exists and has proper permissions

## Bitbucket Pipelines CI/CD

This setup includes automated testing and deployment via Bitbucket Pipelines.

### Pipeline Features

The pipeline automatically runs on every push and includes:

1. **Install Dependencies** - Installs PHP extensions and Composer packages
2. **Code Quality Checks** - PHP linting on all theme/plugin files
3. **Security Scan** - Checks for known vulnerabilities
4. **WordPress Coding Standards** - PHPCS with WordPress rules
5. **PHPUnit Tests** - Runs all unit and integration tests
6. **Deploy to Production** - Automatic deployment on `main` branch

### Setup Bitbucket Pipelines

1. **Enable Pipelines** in your Bitbucket repository settings

2. **Configure Repository Variables** (Settings > Repository variables):
   ```
   SSH_PRIVATE_KEY=<your-private-key>
   PROD_SERVER_HOST=production-server.com
   PROD_SSH_USER=username
   PROD_PATH=/var/www/html
   ```

3. **Add SSH Host to Known Hosts**:
   - Go to Settings > SSH keys
   - Add your production server's host key

### Pipeline Workflows

**Default (all branches except main):**
- Install dependencies
- Code quality checks (parallel)
- Security scan (parallel)
- WordPress standards (parallel)
- PHPUnit tests

**Main branch:**
- All of the above, plus
- **Automatic deployment to production**

**Pull Requests:**
- Full test suite runs
- No deployment

**Manual deployment:**
```bash
# Trigger custom deploy-only pipeline from Bitbucket UI
```

### Running Tests Locally

Before pushing to Bitbucket, test locally:

```bash
# Run PHPUnit tests
docker compose exec wordpress vendor/bin/phpunit --configuration tests/phpunit.xml

# Run PHP lint
find wordpress/wp-content/themes -name "*.php" -exec php -l {} \;

# Install and run PHPCS
docker compose exec wordpress composer require --dev squizlabs/php_codesniffer wp-coding-standards/wpcs
docker compose exec wordpress vendor/bin/phpcs --standard=WordPress wordpress/wp-content/themes/your-theme/
```

See [tests/README.md](tests/README.md) for detailed testing documentation.

### Deployment via Pipeline

When you push to the `main` branch:

1. All tests run automatically
2. If tests pass, code is deployed to production
3. Production backup is created automatically
4. Files are synced via rsync
5. File permissions are set
6. WordPress cache is flushed

Monitor deployment progress in Bitbucket Pipelines UI.

## Development Workflow

### With Bitbucket (Recommended)

1. **Start local environment**: `docker compose up -d`
2. **Sync production database**: `./sync-prod-db.sh`
3. **Create feature branch**: `git checkout -b feature/my-feature`
4. **Make changes** to WordPress files in `./wordpress/`
5. **Test locally** at http://localhost:8080
6. **Run tests**: `docker compose exec wordpress vendor/bin/phpunit --configuration tests/phpunit.xml`
7. **Commit and push**: `git add . && git commit -m "Add feature" && git push origin feature/my-feature`
8. **Create Pull Request** in Bitbucket (tests run automatically)
9. **Merge to main** (triggers deployment to production)

### Without Bitbucket (Manual)

1. **Start environment**: `docker compose up -d`
2. **Sync production database**: `./sync-prod-db.sh`
3. **Make changes** to WordPress files in `./wordpress/`
4. **Test locally** at http://localhost:8080
5. **Test deployment**: `./deploy.sh --dry-run`
6. **Deploy to production**: `./deploy.sh`

## Git Integration

Initialize a Git repository and push to Bitbucket:

```bash
# Initialize Git
git init
git add .
git commit -m "Initial WordPress Docker setup"

# Add Bitbucket remote
git remote add origin git@bitbucket.org:your-workspace/your-repo.git
git push -u origin main
```

The `.gitignore` file excludes:
- WordPress files (`wordpress/` directory)
- Database backups
- Environment files (`.env`)
- Logs

### Tracking Custom Themes/Plugins

To track your custom theme or plugin in Git:

```bash
# Option 1: Track specific theme/plugin only
echo "wordpress/*" > .gitignore
echo "!wordpress/wp-content/" >> .gitignore
echo "wordpress/wp-content/*" >> .gitignore
echo "!wordpress/wp-content/themes/your-theme/" >> .gitignore

# Option 2: Use Git submodule for theme
git submodule add git@bitbucket.org:your-workspace/your-theme.git wordpress/wp-content/themes/your-theme
```

## Production Checklist

### Initial Setup

- [ ] Copy `.env.example` to `.env` and configure all variables
- [ ] Set up Bitbucket repository and enable Pipelines
- [ ] Configure Bitbucket repository variables (SSH keys, server details)
- [ ] Test SSH access to production server
- [ ] Run `docker compose up -d` to verify local environment works
- [ ] Test database sync script: `./sync-prod-db.sh`

### Before Each Deployment

**Via Bitbucket Pipeline (Recommended):**
- [ ] All tests passing locally
- [ ] Create pull request for review
- [ ] Pipeline tests passing on PR
- [ ] Merge to main branch (triggers auto-deployment)
- [ ] Monitor deployment in Bitbucket Pipelines UI

**Manual Deployment:**
- [ ] Test deployment with `./deploy.sh --dry-run`
- [ ] Backup production database and files
- [ ] All tests passing: `docker compose exec wordpress vendor/bin/phpunit`
- [ ] Review excluded files in deployment script
- [ ] Run deployment: `./deploy.sh`

## Support

For issues with:
- **Docker**: Check Docker documentation
- **WordPress**: Visit WordPress.org support forums
- **This setup**: Review logs and error messages

## License

This setup is provided as-is for development purposes.
