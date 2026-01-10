#!/bin/bash
#
# Shared utility functions
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/colors.sh"

# Get the repository root directory
get_repo_root() {
    echo "$(cd "$SCRIPT_DIR/../.." && pwd)"
}

# Load environment variables from .env file
load_env() {
    local repo_root=$(get_repo_root)
    if [ -f "$repo_root/.env" ]; then
        source "$repo_root/.env"
        return 0
    fi
    return 1
}

# Check if .env file exists
env_exists() {
    local repo_root=$(get_repo_root)
    [ -f "$repo_root/.env" ]
}

# Generate random port offset
generate_port_offset() {
    echo $(( (RANDOM % 999) + 1 ))
}

# Generate project name from directory
generate_project_name() {
    local dir_name=$(basename "$(get_repo_root)")
    echo "$dir_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | cut -c1-20 | sed 's/-$//'
}

# Check if Docker is running
check_docker() {
    if ! docker info &>/dev/null; then
        print_error "Docker is not running. Please start Docker and try again."
        return 1
    fi
    return 0
}

# Check if containers are running
containers_running() {
    docker compose ps 2>/dev/null | grep -q "Up"
}

# Wait for WordPress to be ready
wait_for_wordpress() {
    local max_attempts=${1:-30}
    local attempt=1

    print_info "Waiting for WordPress to be ready..."

    while [ $attempt -le $max_attempts ]; do
        if docker compose exec -T wordpress wp --allow-root core is-installed &>/dev/null; then
            print_success "WordPress is ready"
            return 0
        fi
        sleep 2
        ((attempt++))
    done

    print_error "WordPress did not become ready in time"
    return 1
}

# Wait for MySQL to be ready
wait_for_mysql() {
    local max_attempts=${1:-30}
    local attempt=1

    print_info "Waiting for MySQL to be ready..."

    while [ $attempt -le $max_attempts ]; do
        if docker compose exec -T mysql mysqladmin ping -h localhost &>/dev/null; then
            print_success "MySQL is ready"
            return 0
        fi
        sleep 2
        ((attempt++))
    done

    print_error "MySQL did not become ready in time"
    return 1
}

# Validate URL format
validate_url() {
    local url=$1
    if [[ $url =~ ^https?:// ]]; then
        return 0
    fi
    return 1
}

# Validate Git URL format
validate_git_url() {
    local url=$1
    if [[ $url =~ ^(git@|https://).+\.git$ ]] || [[ $url =~ ^(git@|https://).+ ]]; then
        return 0
    fi
    return 1
}

# Prompt for yes/no confirmation
confirm() {
    local prompt="${1:-Continue?}"
    local default="${2:-n}"

    if [ "$default" = "y" ]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi

    read -p "$(echo -e "${CYAN}?${NC} $prompt")" response
    response=${response:-$default}

    [[ "$response" =~ ^[Yy]$ ]]
}

# Prompt for input with default value
prompt_input() {
    local prompt=$1
    local default=$2
    local var_name=$3

    if [ -n "$default" ]; then
        read -p "$(echo -e "${CYAN}?${NC} $prompt [$default]: ")" value
        value=${value:-$default}
    else
        read -p "$(echo -e "${CYAN}?${NC} $prompt: ")" value
    fi

    echo "$value"
}

# Select from menu options
select_option() {
    local prompt=$1
    shift
    local options=("$@")

    echo -e "${CYAN}?${NC} $prompt"
    echo ""

    local i=1
    for opt in "${options[@]}"; do
        echo -e "  ${BOLD}$i)${NC} $opt"
        ((i++))
    done
    echo ""

    while true; do
        read -p "$(echo -e "${CYAN}→${NC} Enter choice [1-${#options[@]}]: ")" choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
            return $((choice - 1))
        fi
        print_error "Invalid choice. Please enter a number between 1 and ${#options[@]}"
    done
}
