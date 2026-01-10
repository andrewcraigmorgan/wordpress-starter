#!/bin/bash
#
# Export WordPress pages to seed templates
#
# Usage: ./scripts/vanilla/export-content.sh
#        ./scripts/vanilla/export-content.sh --page=home
#        ./scripts/vanilla/export-content.sh --all
#
# Options:
#   --page=SLUG   Export specific page by slug
#   --all         Export all pages
#   --list        List available pages
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
SEEDS_DIR="$REPO_ROOT/seeds"
PAGES_DIR="$SEEDS_DIR/pages"

# Ensure directories exist
mkdir -p "$PAGES_DIR"

# Options
EXPORT_PAGE=""
EXPORT_ALL=false
LIST_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --page=*) EXPORT_PAGE="${1#*=}"; shift ;;
        --all) EXPORT_ALL=true; shift ;;
        --list) LIST_ONLY=true; shift ;;
        *) shift ;;
    esac
done

if ! containers_running; then
    print_error "Docker containers are not running"
    exit 1
fi

# List pages
if [ "$LIST_ONLY" = true ]; then
    print_header "Available Pages"
    docker compose exec -T wordpress wp --allow-root post list \
        --post_type=page \
        --post_status=publish \
        --fields=ID,post_title,post_name \
        --format=table \
        2>/dev/null
    exit 0
fi

# Export single page
export_page() {
    local slug=$1
    local output_file="$PAGES_DIR/${slug}.html"

    # Get page ID by slug
    local page_id=$(docker compose exec -T wordpress wp --allow-root post list \
        --post_type=page \
        --name="$slug" \
        --field=ID \
        2>/dev/null | tr -d '\r')

    if [ -z "$page_id" ]; then
        print_error "Page not found: $slug"
        return 1
    fi

    # Export content
    docker compose exec -T wordpress wp --allow-root post get "$page_id" \
        --field=post_content \
        2>/dev/null > "$output_file"

    if [ -s "$output_file" ]; then
        print_success "Exported: $slug → $output_file"
    else
        print_warning "Page '$slug' has no content"
        rm -f "$output_file"
    fi
}

# Export all pages
export_all_pages() {
    local slugs=$(docker compose exec -T wordpress wp --allow-root post list \
        --post_type=page \
        --post_status=publish \
        --field=post_name \
        2>/dev/null | tr -d '\r')

    for slug in $slugs; do
        export_page "$slug"
    done
}

print_header "Export Page Content"

if [ "$EXPORT_ALL" = true ]; then
    print_info "Exporting all pages..."
    echo ""
    export_all_pages
elif [ -n "$EXPORT_PAGE" ]; then
    export_page "$EXPORT_PAGE"
else
    # Interactive mode
    print_info "Available pages:"
    echo ""
    docker compose exec -T wordpress wp --allow-root post list \
        --post_type=page \
        --post_status=publish \
        --fields=ID,post_title,post_name \
        --format=table \
        2>/dev/null
    echo ""

    read -p "$(echo -e "${CYAN}?${NC} Enter page slug to export (or 'all'): ")" page_input

    if [ "$page_input" = "all" ]; then
        export_all_pages
    elif [ -n "$page_input" ]; then
        export_page "$page_input"
    fi
fi

echo ""
print_info "Templates saved to: $PAGES_DIR"
print_info "Update seeds/pages.json to include new pages in seeding"
echo ""
