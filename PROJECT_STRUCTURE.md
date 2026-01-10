# Project Structure

Complete overview of the WordPress Docker development environment with CI/CD.

## Directory Structure

```
wordpress-docker/
├── .env                              # Environment configuration (DO NOT COMMIT)
├── .env.example                      # Environment template
├── .gitignore                        # Git ignore rules
├── docker compose.yml                # Docker services configuration
├── Dockerfile                        # Custom WordPress PHP 8.3 image
├── uploads.ini                       # PHP upload configuration
│
├── sync-prod-db.sh                   # Database sync script (production → local)
├── deploy.sh                         # Deployment script (local → production)
│
├── bitbucket-pipelines.yml           # CI/CD pipeline configuration
│
├── README.md                         # Full documentation
├── QUICK_START.md                    # Quick start guide
├── BITBUCKET_SETUP.md                # Bitbucket setup guide
├── PROJECT_STRUCTURE.md              # This file
│
├── wordpress/                        # WordPress installation directory
│   ├── wp-admin/                     # WordPress admin (auto-installed)
│   ├── wp-includes/                  # WordPress core (auto-installed)
│   ├── wp-content/                   # Your custom content
│   │   ├── themes/                   # Custom themes
│   │   ├── plugins/                  # Custom plugins
│   │   └── uploads/                  # Media uploads
│   └── wp-config.php                 # WordPress config (auto-generated)
│
├── backups/                          # Database backups
│   ├── prod_db_*.sql                 # Production database dumps
│   └── local_backup_*.sql.gz         # Local database backups
│
└── tests/                            # Automated tests
    ├── phpunit.xml                   # PHPUnit configuration
    ├── bootstrap.php                 # Test bootstrap
    ├── README.md                     # Testing documentation
    ├── unit/                         # Unit tests
    │   └── SampleTest.php
    └── integration/                  # Integration tests
        └── WordPressIntegrationTest.php
```

## Core Files

### Docker Configuration

| File | Purpose |
|------|---------|
| `docker compose.yml` | Defines WordPress, MySQL, and PHPMyAdmin services |
| `Dockerfile` | Custom WordPress image with PHP 8.3, WP-CLI, extensions |
| `uploads.ini` | PHP configuration for upload limits and timeouts |

### Environment Configuration

| File | Purpose | Commit? |
|------|---------|---------|
| `.env.example` | Template for environment variables | ✓ Yes |
| `.env` | Your actual configuration with credentials | ✗ NO |
| `.gitignore` | Excludes sensitive files from Git | ✓ Yes |

### Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `sync-prod-db.sh` | Download production DB to local | `./sync-prod-db.sh` |
| `deploy.sh` | Deploy changes to production | `./deploy.sh` or `./deploy.sh --dry-run` |

### CI/CD

| File | Purpose |
|------|---------|
| `bitbucket-pipelines.yml` | Automated testing and deployment pipeline |

Runs on every push:
- Code quality checks
- Security scanning
- WordPress coding standards
- PHPUnit tests
- Auto-deployment (main branch only)

### Documentation

| File | Purpose | Audience |
|------|---------|----------|
| `README.md` | Complete documentation | Everyone |
| `QUICK_START.md` | 5-minute setup guide | New users |
| `BITBUCKET_SETUP.md` | CI/CD setup instructions | DevOps |
| `PROJECT_STRUCTURE.md` | This file - project overview | Developers |
| `tests/README.md` | Testing guide | Developers |

## Docker Services

### WordPress (PHP 8.3)

- **Container**: `wordpress_wp`
- **Port**: 8080 (configurable)
- **Image**: Custom (built from Dockerfile)
- **Features**: PHP 8.3, Apache, WP-CLI, GD, MySQLi

### MySQL 8.0

- **Container**: `wordpress_db`
- **Port**: 3306 (configurable)
- **Image**: mysql:8.0
- **Volume**: `mysql_data` (persistent storage)

### PHPMyAdmin

- **Container**: `wordpress_pma`
- **Port**: 8081 (configurable)
- **Image**: phpmyadmin/phpmyadmin:latest
- **Purpose**: Database management UI

## Environment Variables

### Local Development

```bash
PROJECT_NAME=wordpress          # Container name prefix
WP_PORT=8080                   # WordPress port
WP_ENV=development             # Environment type
WP_DEBUG=true                  # Enable debug mode
WP_HOME=http://localhost:8080  # Site URL
```

### Database

```bash
DB_NAME=wordpress              # Database name
DB_USER=wordpress              # Database user
DB_PASSWORD=wordpress          # Database password
DB_ROOT_PASSWORD=rootpassword  # MySQL root password
DB_PREFIX=mtc_                 # Table prefix
```

### Production Server

```bash
PROD_SERVER=user@server.com    # SSH connection
PROD_PATH=/var/www/html        # WordPress directory
PROD_DB_NAME=wordpress_prod    # Production DB name
PROD_DB_USER=wordpress_user    # Production DB user
PROD_DB_PASSWORD=changeme      # Production DB password
PROD_WP_HOME=https://site.com  # Production URL
```

### Bitbucket Variables

Set in Bitbucket UI (Repository Settings > Repository Variables):

```bash
SSH_PRIVATE_KEY=<private-key>  # SSH key for deployment (secured)
PROD_SERVER_HOST=server.com    # Production server hostname
PROD_SSH_USER=username         # SSH username
PROD_PATH=/var/www/html        # WordPress path
```

## Workflows

### Local Development Workflow

```
1. docker compose up -d
2. ./sync-prod-db.sh (optional)
3. Edit files in wordpress/
4. Test at http://localhost:8080
5. ./deploy.sh --dry-run
6. ./deploy.sh
```

### Bitbucket CI/CD Workflow

```
1. git checkout -b feature/new-feature
2. Make changes to wordpress/
3. Run tests locally
4. git commit && git push
5. Create pull request
6. Pipeline runs tests
7. Merge to main
8. Auto-deploy to production
```

## Data Flow

### Database Sync (Production → Local)

```
Production Server
    ├─> SSH connection
    ├─> mysqldump export
    └─> Compress with gzip
         │
         ↓
Local Machine
    ├─> Download .sql.gz
    ├─> Backup current local DB
    ├─> Import to Docker MySQL
    └─> Update URLs for local environment
```

### Deployment (Local → Production)

```
Local Machine
    ├─> Run tests
    ├─> Export local database
    ├─> Backup production
    └─> rsync files to production
         │
         ↓
Production Server
    ├─> Import database
    ├─> Set file permissions
    └─> Clear caches
```

### Bitbucket Pipeline Flow

```
Code Push
    ↓
Install Dependencies
    ↓
Parallel Execution:
    ├─> Code Quality (PHP Lint)
    ├─> Security Scan
    └─> WordPress Standards (PHPCS)
    ↓
PHPUnit Tests
    ↓
Deploy (main branch only)
    ├─> Backup production
    ├─> Sync files via rsync
    ├─> Set permissions
    └─> Clear caches
```

## Security Considerations

### Do NOT Commit

- `.env` file (contains credentials)
- `wordpress/wp-config.php` (database credentials)
- `backups/` directory (may contain sensitive data)
- SSH private keys
- Database dumps

### Do Commit

- `.env.example` (template without credentials)
- All scripts and documentation
- `bitbucket-pipelines.yml`
- `.gitignore`
- Docker configuration files

### Best Practices

1. Use strong passwords in `.env`
2. Rotate SSH keys regularly
3. Mark Bitbucket variables as "Secured"
4. Keep WordPress and plugins updated
5. Review file permissions after deployment
6. Use HTTPS in production
7. Regular backups (automated by scripts)

## Customization

### Add Custom Theme

```bash
# Track theme in Git
echo "!wordpress/wp-content/themes/my-theme/" >> .gitignore

# Or use as submodule
git submodule add <repo> wordpress/wp-content/themes/my-theme
```

### Add Custom Tests

```bash
# Unit tests
wordpress-docker/tests/unit/MyFeatureTest.php

# Integration tests
wordpress-docker/tests/integration/MyPluginTest.php
```

### Modify Pipeline

Edit `bitbucket-pipelines.yml` to:
- Add custom build steps
- Change deployment conditions
- Add notifications
- Configure staging environment

## Maintenance

### Regular Tasks

- Update WordPress core: `docker compose exec wordpress wp core update`
- Update plugins: `docker compose exec wordpress wp plugin update --all`
- Clean old backups: Automatic (keeps last 7)
- Review pipeline logs: After each deployment
- Test database sync: Weekly/monthly

### Troubleshooting Locations

- Docker logs: `docker compose logs -f`
- WordPress debug: Check `wp-content/debug.log`
- Pipeline logs: Bitbucket UI > Pipelines
- Database issues: PHPMyAdmin at http://localhost:8081
- Deployment issues: Check SSH connectivity and permissions

## Resources

- [Docker Documentation](https://docs.docker.com/)
- [WordPress CLI](https://wp-cli.org/)
- [Bitbucket Pipelines](https://support.atlassian.com/bitbucket-cloud/docs/get-started-with-bitbucket-pipelines/)
- [PHPUnit Documentation](https://phpunit.de/)
- [WordPress Coding Standards](https://developer.wordpress.org/coding-standards/)

## Support

For questions or issues:
1. Check logs: `docker compose logs -f`
2. Review documentation in this repository
3. Test individual components (Docker, SSH, database)
4. Check Bitbucket pipeline logs for CI/CD issues
