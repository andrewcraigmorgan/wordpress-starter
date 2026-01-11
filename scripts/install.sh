#!/bin/bash
#
# WordPress Docker Installer
# Interactive installer for setting up WordPress development environments
#
# Usage: ./scripts/install.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/utils.sh"

REPO_ROOT=$(get_repo_root)
cd "$REPO_ROOT"

# Display banner
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                   ║"
    echo "║   █░█░█ █▀█ █▀█ █▀▄ █▀█ █▀█ █▀▀ █▀ █▀   █▀ ▀█▀ ▄▀█ █▀█ ▀█▀ █▀▀   ║"
    echo "║   ▀▄▀▄▀ █▄█ █▀▄ █▄▀ █▀▀ █▀▄ ██▄ ▄█ ▄█   ▄█  █  █▀█ █▀▄  █  ██▄   ║"
    echo "║                                                                   ║"
    echo "║              Docker Development Environment Installer             ║"
    echo "║                                                                   ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

# Main menu
show_main_menu() {
    echo -e "${BOLD}What would you like to do?${NC}"
    echo ""
    echo -e "  ${BOLD}1)${NC} ${GREEN}Fresh Install${NC} - New WordPress with optional theme"
    echo -e "     ${DIM}Start from scratch with a vanilla WordPress installation${NC}"
    echo ""
    echo -e "  ${BOLD}2)${NC} ${BLUE}Clone Environment${NC} - Copy from existing site"
    echo -e "     ${DIM}Pull database and files from production/staging${NC}"
    echo ""
    echo -e "  ${BOLD}3)${NC} ${YELLOW}Start Existing${NC} - Start containers"
    echo -e "     ${DIM}Start an already configured environment${NC}"
    echo ""
    echo -e "  ${BOLD}4)${NC} ${MAGENTA}Reconfigure${NC} - Reset environment settings"
    echo -e "     ${DIM}Regenerate ports and project settings${NC}"
    echo ""
    echo -e "  ${BOLD}5)${NC} Exit"
    echo ""

    while true; do
        read -p "$(echo -e "${CYAN}→${NC} Enter choice [1-5]: ")" choice
        case $choice in
            1) run_fresh_install; break ;;
            2) run_clone_environment; break ;;
            3) run_start_existing; break ;;
            4) run_reconfigure; break ;;
            5) echo ""; print_info "Goodbye!"; exit 0 ;;
            *) print_error "Invalid choice. Please enter 1-5" ;;
        esac
    done
}

# Fresh WordPress Installation
run_fresh_install() {
    print_header "Fresh WordPress Installation"

    # Setup environment if needed
    if ! env_exists; then
        print_info "Setting up environment configuration..."
        bash "$SCRIPT_DIR/vanilla/setup-env.sh"
    else
        print_success "Environment already configured"
        load_env
    fi

    # Theme selection
    echo ""
    echo -e "${BOLD}Theme Options:${NC}"
    echo ""
    echo -e "  ${BOLD}1)${NC} Vanilla - Default WordPress theme (Twenty Twenty-Five)"
    echo -e "  ${BOLD}2)${NC} Custom Theme - Install from Git repository"
    echo -e "  ${BOLD}3)${NC} Starter Theme (Plain) - Parent + plain child theme"
    echo -e "  ${BOLD}4)${NC} Starter Theme (SPA) - Parent + Vue/Vite child theme"
    echo ""

    while true; do
        read -p "$(echo -e "${CYAN}→${NC} Select theme option [1-4]: ")" theme_choice
        case $theme_choice in
            1) THEME_TYPE="vanilla"; break ;;
            2) THEME_TYPE="custom"; break ;;
            3) THEME_TYPE="starter-plain"; break ;;
            4) THEME_TYPE="starter-spa"; break ;;
            *) print_error "Invalid choice" ;;
        esac
    done

    # Get custom theme details if selected
    if [ "$THEME_TYPE" = "custom" ]; then
        echo ""
        THEME_REPO=$(prompt_input "Enter theme Git repository URL" "" "theme_repo")

        if ! validate_git_url "$THEME_REPO"; then
            print_error "Invalid Git URL format"
            exit 1
        fi

        read -p "$(echo -e "${CYAN}?${NC} Is this a child theme? [y/N]: ")" is_child
        if [[ "$is_child" =~ ^[Yy]$ ]]; then
            PARENT_REPO=$(prompt_input "Enter parent theme Git repository URL" "" "parent_repo")
        fi
    fi

    if [ "$THEME_TYPE" = "starter-plain" ]; then
        PARENT_REPO="https://github.com/andrewcraigmorgan/wordpress-starter-theme.git"
        THEME_REPO="https://github.com/andrewcraigmorgan/wordpress-starter-theme-child.git"
    fi

    if [ "$THEME_TYPE" = "starter-spa" ]; then
        PARENT_REPO="https://github.com/andrewcraigmorgan/wordpress-starter-theme.git"
        THEME_REPO="https://github.com/andrewcraigmorgan/wordpress-starter-theme-spa.git"
    fi

    # Start containers
    echo ""
    print_step "1/4" "Starting Docker containers..."
    docker compose up -d

    # Wait for services
    print_step "2/4" "Waiting for services..."
    wait_for_mysql
    sleep 5

    # Install WordPress
    print_step "3/4" "Installing WordPress..."
    bash "$SCRIPT_DIR/vanilla/install-wp.sh"

    # Install theme
    print_step "4/4" "Setting up theme..."
    if [ "$THEME_TYPE" = "custom" ] || [ "$THEME_TYPE" = "starter-plain" ] || [ "$THEME_TYPE" = "starter-spa" ]; then
        THEME_REPO="$THEME_REPO" PARENT_REPO="${PARENT_REPO:-}" bash "$SCRIPT_DIR/vanilla/install-theme.sh"

        # Remove default Twenty* themes (only when using custom themes)
        print_info "Removing default themes..."
        docker compose exec -T wordpress bash -c 'rm -rf /var/www/html/wp-content/themes/twenty*' 2>/dev/null || true
    else
        print_info "Using default WordPress theme"
    fi

    # Done
    load_env
    echo ""
    print_header "Installation Complete!"
    echo -e "  ${GREEN}WordPress:${NC}   http://localhost:${WP_PORT}"
    echo -e "  ${GREEN}Admin:${NC}       http://localhost:${WP_PORT}/wp-admin"
    echo -e "  ${GREEN}phpMyAdmin:${NC}  http://localhost:${PMA_PORT}"
    echo ""
    echo -e "  ${DIM}Username: admin${NC}"
    echo -e "  ${DIM}Password: admin${NC}"
    echo ""
}

# Clone from existing environment
run_clone_environment() {
    print_header "Clone Environment"

    # Check for existing environment config
    if ! env_exists; then
        print_info "Setting up environment configuration..."
        bash "$SCRIPT_DIR/vanilla/setup-env.sh"
    fi

    load_env

    # Environment selection
    echo -e "${BOLD}Select source environment:${NC}"
    echo ""
    echo -e "  ${BOLD}1)${NC} Production"
    echo -e "  ${BOLD}2)${NC} Staging"
    echo -e "  ${BOLD}3)${NC} Custom (enter details manually)"
    echo ""

    while true; do
        read -p "$(echo -e "${CYAN}→${NC} Select environment [1-3]: ")" env_choice
        case $env_choice in
            1) ENV_TYPE="production"; break ;;
            2) ENV_TYPE="staging"; break ;;
            3) ENV_TYPE="custom"; break ;;
            *) print_error "Invalid choice" ;;
        esac
    done

    # Check if we have existing config for this environment
    if [ "$ENV_TYPE" = "custom" ] || [ -z "$PROD_SERVER" ]; then
        echo ""
        print_info "Enter remote server details:"
        echo ""

        SSH_SERVER=$(prompt_input "SSH server (user@host)" "" "ssh_server")
        SSH_PATH=$(prompt_input "WordPress path on server" "/var/www/html" "ssh_path")
        SSH_KEY=$(prompt_input "SSH key path (optional)" "" "ssh_key")

        REMOTE_DB_NAME=$(prompt_input "Remote database name" "" "db_name")
        REMOTE_DB_USER=$(prompt_input "Remote database user" "" "db_user")
        read -sp "$(echo -e "${CYAN}?${NC} Remote database password: ")" REMOTE_DB_PASS
        echo ""
        REMOTE_WP_HOME=$(prompt_input "Remote site URL" "https://example.com" "wp_home")

        # Save to .env
        {
            echo ""
            echo "# Remote environment configuration"
            echo "PROD_SERVER=$SSH_SERVER"
            echo "PROD_PATH=$SSH_PATH"
            [ -n "$SSH_KEY" ] && echo "PROD_SSH_KEY=$SSH_KEY"
            echo "PROD_DB_NAME=$REMOTE_DB_NAME"
            echo "PROD_DB_USER=$REMOTE_DB_USER"
            echo "PROD_DB_PASSWORD=$REMOTE_DB_PASS"
            echo "PROD_WP_HOME=$REMOTE_WP_HOME"
        } >> "$REPO_ROOT/.env"

        print_success "Configuration saved to .env"
    fi

    # Theme handling
    echo ""
    echo -e "${BOLD}Theme handling:${NC}"
    echo ""
    echo -e "  ${BOLD}1)${NC} Clone theme from remote - Pull theme files from server"
    echo -e "  ${BOLD}2)${NC} Use local theme - Already have theme in ./wordpress/wp-content/themes"
    echo -e "  ${BOLD}3)${NC} Clone from Git - Install theme from Git repository"
    echo ""

    while true; do
        read -p "$(echo -e "${CYAN}→${NC} Select theme option [1-3]: ")" theme_opt
        case $theme_opt in
            1) CLONE_THEME="remote"; break ;;
            2) CLONE_THEME="local"; break ;;
            3) CLONE_THEME="git"; break ;;
            *) print_error "Invalid choice" ;;
        esac
    done

    if [ "$CLONE_THEME" = "remote" ]; then
        THEME_SLUGS=$(prompt_input "Theme slug(s) to sync (space-separated)" "" "theme_slugs")
        # Add to .env
        echo "PROD_THEME_SLUGS=\"$THEME_SLUGS\"" >> "$REPO_ROOT/.env"
    elif [ "$CLONE_THEME" = "git" ]; then
        THEME_REPO=$(prompt_input "Theme Git repository URL" "" "theme_repo")
    fi

    # Start containers
    echo ""
    print_step "1/3" "Starting Docker containers..."
    docker compose up -d

    # Wait for services
    print_step "2/3" "Waiting for services..."
    wait_for_mysql
    sleep 5

    # Run sync
    print_step "3/3" "Syncing from remote environment..."
    bash "$SCRIPT_DIR/clone/sync.sh"

    # Install Git theme if selected
    if [ "$CLONE_THEME" = "git" ] && [ -n "$THEME_REPO" ]; then
        print_info "Installing theme from Git..."
        THEME_REPO="$THEME_REPO" bash "$SCRIPT_DIR/vanilla/install-theme.sh"
    fi

    # Done
    load_env
    echo ""
    print_header "Clone Complete!"
    echo -e "  ${GREEN}WordPress:${NC}   http://localhost:${WP_PORT}"
    echo -e "  ${GREEN}Admin:${NC}       http://localhost:${WP_PORT}/wp-admin"
    echo -e "  ${GREEN}phpMyAdmin:${NC}  http://localhost:${PMA_PORT}"
    echo ""
}

# Start existing environment
run_start_existing() {
    print_header "Starting Environment"

    if ! env_exists; then
        print_error "No environment configured. Run 'Fresh Install' or 'Clone Environment' first."
        exit 1
    fi

    load_env

    print_info "Starting Docker containers..."
    docker compose up -d

    wait_for_mysql

    echo ""
    print_success "Environment started!"
    echo ""
    echo -e "  ${GREEN}WordPress:${NC}   http://localhost:${WP_PORT}"
    echo -e "  ${GREEN}phpMyAdmin:${NC}  http://localhost:${PMA_PORT}"
    echo ""
}

# Reconfigure environment
run_reconfigure() {
    print_header "Reconfigure Environment"

    if env_exists; then
        print_warning "This will regenerate your .env file with new ports."
        if ! confirm "Continue?" "n"; then
            print_info "Cancelled"
            exit 0
        fi

        # Backup existing .env
        cp "$REPO_ROOT/.env" "$REPO_ROOT/.env.backup"
        print_info "Backed up existing .env to .env.backup"
    fi

    bash "$SCRIPT_DIR/vanilla/setup-env.sh" --force

    print_success "Environment reconfigured!"
}

# Check Docker is available
if ! check_docker; then
    exit 1
fi

# Run installer
show_banner
show_main_menu
