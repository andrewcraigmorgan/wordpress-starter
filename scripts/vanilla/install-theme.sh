#!/bin/bash
#
# Install theme from Git repository
#
# Usage: ./scripts/vanilla/install-theme.sh
#
# Environment variables:
#   THEME_REPO   - Git repository URL for the theme (required)
#   PARENT_REPO  - Git repository URL for parent theme (optional, for child themes)
#   THEME_BRANCH - Branch to checkout (default: main)
#   ACTIVATE     - Whether to activate the theme (default: true)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/colors.sh"
source "$SCRIPT_DIR/../lib/utils.sh"

REPO_ROOT=$(get_repo_root)
cd "$REPO_ROOT"

# Load environment
load_env

# Configuration
THEMES_DIR="$REPO_ROOT/wordpress/wp-content/themes"
THEME_BRANCH="${THEME_BRANCH:-main}"
ACTIVATE="${ACTIVATE:-true}"

# Ensure themes directory exists
mkdir -p "$THEMES_DIR"

# Check if theme repo is provided
if [ -z "$THEME_REPO" ]; then
    print_error "THEME_REPO environment variable is required"
    echo ""
    echo "Usage: THEME_REPO=git@github.com:user/theme.git ./scripts/vanilla/install-theme.sh"
    exit 1
fi

# Extract theme name from repo URL
extract_theme_name() {
    local repo=$1
    basename "$repo" .git
}

# Clone or update a theme
clone_theme() {
    local repo=$1
    local name=$2
    local dest="$THEMES_DIR/$name"

    if [ -d "$dest" ]; then
        print_info "Theme '$name' already exists, updating..."
        cd "$dest"
        git fetch origin
        git checkout "$THEME_BRANCH" 2>/dev/null || git checkout -b "$THEME_BRANCH" "origin/$THEME_BRANCH"
        git pull origin "$THEME_BRANCH"
        cd "$REPO_ROOT"
    else
        print_info "Cloning theme '$name'..."
        git clone --branch "$THEME_BRANCH" "$repo" "$dest" 2>/dev/null || \
        git clone "$repo" "$dest"
    fi

    print_success "Theme '$name' installed to $dest"
}

# Install npm dependencies if package.json exists
install_dependencies() {
    local theme_dir=$1
    local name=$2

    if [ -f "$theme_dir/package.json" ]; then
        print_info "Installing npm dependencies for '$name'..."
        cd "$theme_dir"

        if [ -f ".nvmrc" ]; then
            print_info "Found .nvmrc, using specified Node version"
            # Source nvm if available
            [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
            nvm use 2>/dev/null || print_warning "nvm not available, using system Node"
        fi

        npm install

        # Run build if available
        if grep -q '"build"' package.json; then
            print_info "Running build script..."
            npm run build 2>/dev/null || npm run production 2>/dev/null || true
        elif grep -q '"production"' package.json; then
            print_info "Running production build..."
            npm run production
        fi

        cd "$REPO_ROOT"
        print_success "Dependencies installed for '$name'"
    fi
}

# Install parent theme first if specified
if [ -n "$PARENT_REPO" ]; then
    PARENT_NAME=$(extract_theme_name "$PARENT_REPO")
    print_header "Installing Parent Theme: $PARENT_NAME"

    clone_theme "$PARENT_REPO" "$PARENT_NAME"
    install_dependencies "$THEMES_DIR/$PARENT_NAME" "$PARENT_NAME"
fi

# Install main theme
THEME_NAME=$(extract_theme_name "$THEME_REPO")
print_header "Installing Theme: $THEME_NAME"

clone_theme "$THEME_REPO" "$THEME_NAME"
install_dependencies "$THEMES_DIR/$THEME_NAME" "$THEME_NAME"

# Fix permissions in container
print_info "Fixing file permissions..."
docker compose exec -T wordpress chown -R www-data:www-data /var/www/html/wp-content/themes/ 2>/dev/null || true

# Activate theme
if [ "$ACTIVATE" = "true" ]; then
    print_info "Activating theme '$THEME_NAME'..."

    # Wait for WordPress to be ready
    wait_for_wordpress 30

    docker compose exec -T wordpress wp --allow-root theme activate "$THEME_NAME"
    print_success "Theme '$THEME_NAME' activated"
fi

echo ""
print_success "Theme installation complete!"
echo ""
echo -e "  ${CYAN}Theme:${NC}    $THEME_NAME"
echo -e "  ${CYAN}Location:${NC} $THEMES_DIR/$THEME_NAME"
if [ -n "$PARENT_REPO" ]; then
    echo -e "  ${CYAN}Parent:${NC}   $PARENT_NAME"
fi
echo ""
