#!/bin/bash
#
# Start Docker containers
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/colors.sh"
source "$SCRIPT_DIR/../lib/utils.sh"

REPO_ROOT=$(get_repo_root)
cd "$REPO_ROOT"

if ! load_env; then
    print_error ".env file not found. Run the installer first: ./scripts/install.sh"
    exit 1
fi

print_info "Starting Docker containers..."
docker compose up -d

wait_for_mysql

echo ""
print_success "Environment started!"
echo ""
echo -e "  ${CYAN}WordPress:${NC}   http://localhost:${WP_PORT}"
echo -e "  ${CYAN}phpMyAdmin:${NC}  http://localhost:${PMA_PORT}"
echo ""
