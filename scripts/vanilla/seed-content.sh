#!/bin/bash
#
# Seed WordPress with predefined content (pages, settings)
#
# Usage: ./scripts/vanilla/seed-content.sh
#        ./scripts/vanilla/seed-content.sh --pages-only
#        ./scripts/vanilla/seed-content.sh --skip-existing
#
# Options:
#   --pages-only    Only create pages, skip settings
#   --skip-existing Skip pages that already exist
#   --force         Overwrite existing pages
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
PAGES_CONFIG="$SEEDS_DIR/pages.json"

# Options
PAGES_ONLY=false
SKIP_EXISTING=false
FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --pages-only) PAGES_ONLY=true; shift ;;
        --skip-existing) SKIP_EXISTING=true; shift ;;
        --force) FORCE=true; shift ;;
        *) shift ;;
    esac
done

# Check requirements
if [ ! -f "$PAGES_CONFIG" ]; then
    print_error "Seeds configuration not found: $PAGES_CONFIG"
    exit 1
fi

if ! containers_running; then
    print_error "Docker containers are not running"
    exit 1
fi

print_header "Seeding WordPress Content"

# Check if jq is available, otherwise use Python
if command -v jq &>/dev/null; then
    JSON_PARSER="jq"
else
    JSON_PARSER="python3"
fi

# Parse JSON helper
parse_json() {
    local file=$1
    local query=$2

    if [ "$JSON_PARSER" = "jq" ]; then
        jq -r "$query" "$file"
    else
        python3 -c "import json; data=json.load(open('$file')); print($query)"
    fi
}

# Get number of pages
get_page_count() {
    if [ "$JSON_PARSER" = "jq" ]; then
        jq '.pages | length' "$PAGES_CONFIG"
    else
        python3 -c "import json; print(len(json.load(open('$PAGES_CONFIG'))['pages']))"
    fi
}

# Get page property
get_page_prop() {
    local index=$1
    local prop=$2

    if [ "$JSON_PARSER" = "jq" ]; then
        jq -r ".pages[$index].$prop // empty" "$PAGES_CONFIG"
    else
        python3 -c "import json; d=json.load(open('$PAGES_CONFIG')); v=d['pages'][$index].get('$prop'); print(v if v else '')"
    fi
}

# Get setting
get_setting() {
    local key=$1

    if [ "$JSON_PARSER" = "jq" ]; then
        jq -r ".settings.$key // empty" "$PAGES_CONFIG"
    else
        python3 -c "import json; d=json.load(open('$PAGES_CONFIG')); print(d.get('settings',{}).get('$key',''))"
    fi
}

# Create pages
HOMEPAGE_ID=""
PAGE_COUNT=$(get_page_count)

print_info "Found $PAGE_COUNT pages to create"
echo ""

for ((i=0; i<PAGE_COUNT; i++)); do
    TITLE=$(get_page_prop $i "title")
    SLUG=$(get_page_prop $i "slug")
    TEMPLATE=$(get_page_prop $i "template")
    SET_AS_HOME=$(get_page_prop $i "set_as_homepage")

    # Check if page exists
    EXISTING_ID=$(docker compose exec -T wordpress wp --allow-root post list \
        --post_type=page \
        --name="$SLUG" \
        --field=ID \
        2>/dev/null | tr -d '\r' || echo "")

    if [ -n "$EXISTING_ID" ]; then
        if [ "$SKIP_EXISTING" = true ]; then
            print_info "Skipping existing page: $TITLE (ID: $EXISTING_ID)"
            if [ "$SET_AS_HOME" = "true" ]; then
                HOMEPAGE_ID="$EXISTING_ID"
            fi
            continue
        elif [ "$FORCE" = true ]; then
            print_warning "Deleting existing page: $TITLE (ID: $EXISTING_ID)"
            docker compose exec -T wordpress wp --allow-root post delete "$EXISTING_ID" --force 2>/dev/null
        else
            print_warning "Page '$TITLE' already exists (ID: $EXISTING_ID). Use --force to overwrite or --skip-existing to skip."
            if [ "$SET_AS_HOME" = "true" ]; then
                HOMEPAGE_ID="$EXISTING_ID"
            fi
            continue
        fi
    fi

    # Build create command
    CREATE_CMD="wp --allow-root post create --post_type=page --post_title='$TITLE' --post_name='$SLUG' --post_status=publish"

    # Add content if template exists
    if [ -n "$TEMPLATE" ] && [ -f "$PAGES_DIR/$TEMPLATE" ]; then
        # Copy template to container and create page
        docker compose cp "$PAGES_DIR/$TEMPLATE" wordpress:/tmp/page-content.html

        PAGE_ID=$(docker compose exec -T wordpress sh -c "wp --allow-root post create \
            --post_type=page \
            --post_title='$TITLE' \
            --post_name='$SLUG' \
            --post_status=publish \
            --post_content=\"\$(cat /tmp/page-content.html)\" \
            --porcelain" 2>/dev/null | tr -d '\r')

        docker compose exec -T wordpress rm /tmp/page-content.html 2>/dev/null || true
    else
        # Create empty page
        PAGE_ID=$(docker compose exec -T wordpress wp --allow-root post create \
            --post_type=page \
            --post_title="$TITLE" \
            --post_name="$SLUG" \
            --post_status=publish \
            --porcelain 2>/dev/null | tr -d '\r')
    fi

    if [ -n "$PAGE_ID" ]; then
        print_success "Created page: $TITLE (ID: $PAGE_ID)"

        if [ "$SET_AS_HOME" = "true" ]; then
            HOMEPAGE_ID="$PAGE_ID"
        fi
    else
        print_error "Failed to create page: $TITLE"
    fi
done

# Apply settings
if [ "$PAGES_ONLY" = false ]; then
    echo ""
    print_info "Applying settings..."

    # Set homepage
    if [ -n "$HOMEPAGE_ID" ]; then
        docker compose exec -T wordpress wp --allow-root option update show_on_front page 2>/dev/null
        docker compose exec -T wordpress wp --allow-root option update page_on_front "$HOMEPAGE_ID" 2>/dev/null
        print_success "Set homepage to page ID: $HOMEPAGE_ID"
    fi

    # Apply other settings
    BLOGNAME=$(get_setting "blogname")
    if [ -n "$BLOGNAME" ]; then
        docker compose exec -T wordpress wp --allow-root option update blogname "$BLOGNAME" 2>/dev/null
        print_success "Set site title: $BLOGNAME"
    fi

    BLOGDESC=$(get_setting "blogdescription")
    if [ -n "$BLOGDESC" ]; then
        docker compose exec -T wordpress wp --allow-root option update blogdescription "$BLOGDESC" 2>/dev/null
        print_success "Set tagline: $BLOGDESC"
    fi
fi

# Flush caches
docker compose exec -T wordpress wp --allow-root cache flush 2>/dev/null || true

echo ""
print_success "Content seeding complete!"
echo ""
