# Quick Start Guide

Get up and running in 5 minutes!

## Prerequisites

- [ ] Docker and Docker Compose installed
- [ ] SSH access to production server (see below)
- [ ] Bitbucket account (optional, for CI/CD)

## SSH Setup (One-Time, 2 minutes)

If you need to sync from production, set up SSH first:

```bash
# 1. Generate SSH key (if you don't have one)
ssh-keygen -t rsa -b 4096 -C "wordpress-docker"

# 2. Copy to production server
ssh-copy-id user@production-server.com

# 3. Test connection (should work without password)
ssh user@production-server.com
```

✓ If SSH connection works, you're ready!

See [README.md](README.md#ssh-setup-for-production-access) for detailed SSH setup instructions.

## 1. Configure Environment (2 minutes)

```bash
# Copy environment template
cp .env.example .env

# Edit with your settings
nano .env
```

**Minimum required settings:**
```bash
# Local settings
DB_PASSWORD=your_secure_password
DB_ROOT_PASSWORD=your_root_password

# Production (for database sync)
PROD_SERVER=user@production-server.com
PROD_DB_NAME=wordpress_prod
PROD_DB_USER=wordpress_user
PROD_DB_PASSWORD=prod_password
PROD_WP_HOME=https://yourproductionsite.com
```

## 2. Start Docker Environment (1 minute)

```bash
# Start all containers
docker compose up -d

# Verify running
docker compose ps
```

## 3. Set Up WordPress (2 minutes)

### Option A: Fresh Install

1. Visit http://localhost:8080
2. Follow WordPress installation wizard
3. Done!

### Option B: Import from Production

```bash
# Sync production database
./sync-prod-db.sh

# Copy production files (if needed)
# rsync or scp your WordPress files to ./wordpress/
```

## 4. Access Your Site

- **WordPress**: http://localhost:8080
- **PHPMyAdmin**: http://localhost:8081
  - Server: `mysql`
  - Username: `wordpress` (from .env)
  - Password: `wordpress` (from .env)

## Common Commands

### Docker

```bash
# Start
docker compose up -d

# Stop
docker compose down

# View logs
docker compose logs -f

# Restart
docker compose restart
```

### WordPress CLI

```bash
# List plugins
docker compose exec wordpress wp --allow-root plugin list

# Update WordPress
docker compose exec wordpress wp --allow-root core update

# Flush cache
docker compose exec wordpress wp --allow-root cache flush
```

### Database

```bash
# Sync from production
./sync-prod-db.sh

# Backup local database
docker compose exec mysql mysqldump -u root -p"${DB_ROOT_PASSWORD}" wordpress > backup.sql

# Access MySQL CLI
docker compose exec mysql mysql -u root -p
```

### Deployment

```bash
# Test deployment (dry run)
./deploy.sh --dry-run

# Deploy files only
./deploy.sh --files-only

# Full deployment
./deploy.sh
```

## Git & Bitbucket (Optional)

```bash
# Initialize Git
git init
git add .
git commit -m "Initial setup"

# Push to Bitbucket
git remote add origin git@bitbucket.org:workspace/repo.git
git push -u origin main
```

See [BITBUCKET_SETUP.md](BITBUCKET_SETUP.md) for full CI/CD setup.

## Development Workflow

```bash
# 1. Start environment
docker compose up -d

# 2. Sync production database (optional)
./sync-prod-db.sh

# 3. Make changes to WordPress files
# Edit files in ./wordpress/

# 4. Test locally
# Visit http://localhost:8080

# 5. Deploy when ready
./deploy.sh --dry-run  # Test first
./deploy.sh            # Actually deploy
```

## Troubleshooting

### Containers won't start

```bash
# Check if ports are in use
lsof -i :8080
lsof -i :3306

# Change ports in .env if needed
WP_PORT=8082
MYSQL_PORT=3307

# Restart
docker compose down && docker compose up -d
```

### Permission errors

```bash
# Fix WordPress permissions
docker compose exec wordpress chown -R www-data:www-data /var/www/html
```

### Database connection errors

```bash
# Check MySQL is running
docker compose ps

# Check credentials in .env
cat .env | grep DB_

# View MySQL logs
docker compose logs mysql
```

### Can't sync production database

```bash
# Test SSH connection
ssh user@production-server.com

# Verify database credentials
# Log into production and test:
mysql -u username -p database_name
```

## Next Steps

1. ✓ Environment running
2. ✓ WordPress installed
3. Read [README.md](README.md) for full documentation
4. Set up [Bitbucket Pipelines](BITBUCKET_SETUP.md) for CI/CD
5. Review [tests/README.md](tests/README.md) for testing guide
6. Customize your theme/plugin
7. Deploy to production

## Need Help?

- **Full Documentation**: [README.md](README.md)
- **Bitbucket Setup**: [BITBUCKET_SETUP.md](BITBUCKET_SETUP.md)
- **Testing Guide**: [tests/README.md](tests/README.md)
- **Docker Logs**: `docker compose logs -f`
