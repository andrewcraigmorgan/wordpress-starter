# WordPress Starter

A Docker-based WordPress development environment with an interactive installer supporting fresh installations and environment cloning.

## Features

- **Interactive Installer** - Guided setup for new projects
- **Fresh Install** - Vanilla WordPress with optional custom themes
- **Clone Environment** - Pull database and files from production/staging
- **Theme Management** - Install themes from Git repositories
- **Auto Port Assignment** - Random ports to avoid conflicts
- **PHP 8.3** with Apache
- **MySQL 8.0** database
- **phpMyAdmin** for database management
- **WP-CLI** for command-line WordPress management

## Quick Start

### Interactive Installer

```bash
./scripts/install.sh
```

This launches an interactive menu with options:

1. **Fresh Install** - New WordPress with optional theme
2. **Clone Environment** - Copy from production/staging
3. **Start Existing** - Start configured environment
4. **Reconfigure** - Reset ports and settings

### Manual Setup

```bash
# 1. Setup environment (generates random ports)
./scripts/vanilla/setup-env.sh

# 2. Start containers
docker compose up -d

# 3. Install WordPress
./scripts/vanilla/install-wp.sh

# 4. (Optional) Install theme from Git
THEME_REPO=git@github.com:user/theme.git ./scripts/vanilla/install-theme.sh
```

## Directory Structure

```
.
├── scripts/
│   ├── install.sh           # Main interactive installer
│   ├── lib/
│   │   ├── colors.sh        # Terminal colors
│   │   └── utils.sh         # Shared utilities
│   ├── vanilla/
│   │   ├── setup-env.sh     # Environment configuration
│   │   ├── install-wp.sh    # WordPress installation
│   │   └── install-theme.sh # Theme installation
│   ├── clone/
│   │   └── sync.sh          # Remote environment sync
│   └── common/
│       ├── start.sh         # Start containers
│       └── stop.sh          # Stop containers
├── wordpress/               # WordPress files (created on first run)
├── docker-compose.yml
├── Dockerfile
├── .env.example
└── .env                     # Your local configuration
```

## Installation Flows

### 1. Fresh Install

Perfect for new projects:

```bash
./scripts/install.sh
# Select: 1) Fresh Install
# Choose theme option:
#   - Vanilla (default theme)
#   - Custom Theme (from Git repo)
#   - Starter Theme
```

**With custom theme:**
```bash
# Theme from Git
THEME_REPO=git@github.com:user/theme.git ./scripts/vanilla/install-theme.sh

# Child theme with parent
THEME_REPO=git@github.com:user/child-theme.git \
PARENT_REPO=git@github.com:user/parent-theme.git \
./scripts/vanilla/install-theme.sh
```

### 2. Clone Environment

Pull an existing site locally:

```bash
./scripts/install.sh
# Select: 2) Clone Environment
# Enter remote server details when prompted
```

**Required `.env` variables for cloning:**
```bash
# Remote server configuration
PROD_SERVER=user@server.com
PROD_PATH=/var/www/html
PROD_SSH_KEY=~/.ssh/id_rsa          # Optional

# Remote database
PROD_DB_NAME=wordpress
PROD_DB_USER=db_user
PROD_DB_PASSWORD=db_password
PROD_WP_HOME=https://example.com

# Theme slugs to sync (space-separated)
PROD_THEME_SLUGS="theme-name child-theme-name"
```

**Manual sync:**
```bash
./scripts/clone/sync.sh
```

## Common Commands

```bash
# Start environment
./scripts/common/start.sh

# Stop environment
./scripts/common/stop.sh

# Access WordPress CLI
docker compose exec wordpress wp --allow-root [command]

# Access MySQL
docker compose exec mysql mysql -u root -p

# View logs
docker compose logs -f wordpress

# Rebuild containers
docker compose up -d --build
```

## Configuration

### Environment Variables

Key variables in `.env`:

| Variable | Description | Default |
|----------|-------------|---------|
| `PROJECT_NAME` | Docker project name | Directory name |
| `WP_PORT` | WordPress port | Random 8xxx |
| `PMA_PORT` | phpMyAdmin port | Random 9xxx |
| `WP_HOME` | Site URL | http://localhost:PORT |
| `DB_NAME` | Database name | wordpress |
| `DB_USER` | Database user | wordpress |
| `DB_PASSWORD` | Database password | wordpress |

### WordPress Defaults

Fresh installations use:
- **Username:** admin
- **Password:** admin
- **Email:** admin@example.com

Override with environment variables:
```bash
WP_USER=myuser WP_PASS=mypassword ./scripts/vanilla/install-wp.sh
```

## Theme Development

Themes go in `./wordpress/wp-content/themes/`. For themes with build tools:

```bash
cd wordpress/wp-content/themes/your-theme
npm install
npm run dev      # Development build
npm run watch    # Watch mode
npm run build    # Production build
```

## Troubleshooting

### Port Conflicts
```bash
# Regenerate ports
./scripts/vanilla/setup-env.sh --force
docker compose down
docker compose up -d
```

### Database Issues
```bash
# Reset database
docker compose exec wordpress wp --allow-root db reset --yes

# Reimport from backup
docker compose exec mysql mysql -u root -p wordpress < backup.sql
```

### Permission Issues
```bash
# Fix WordPress permissions
docker compose exec wordpress chown -R www-data:www-data /var/www/html
```

## License

MIT
