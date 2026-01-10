#!/bin/bash
#
# Create a git worktree with standardized naming for WordPress development
#
# Usage: ./scripts/worktree-create.sh
#        ./scripts/worktree-create.sh "Client Website"
#        ./scripts/worktree-create.sh "PN1-T683" "Client Website"
#        ./scripts/worktree-create.sh "PN1-T683" "Client Website" bugfix
#        ./scripts/worktree-create.sh --existing feature/my-branch
#        ./scripts/worktree-create.sh -e feature/my-branch
#
# Arguments (all optional - prompts if not provided):
#   $1 - Feature name, OR Prefix/ticket ID (if $2 provided)
#   $2 - Feature name (if $1 is a prefix)
#   $3 - Branch type (feature, bugfix, hotfix, refactor)
#
# Flags:
#   --existing, -e <branch>  Check out an existing branch by exact name

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the repository root and parent directory
REPO_ROOT=$(git rev-parse --show-toplevel)
REPO_NAME=$(basename "$REPO_ROOT")
PARENT_DIR=$(dirname "$REPO_ROOT")

# Handle --existing flag
if [[ "$1" == "--existing" || "$1" == "-e" ]]; then
    if [ -z "$2" ]; then
        echo -e "${RED}Error: --existing requires a branch name${NC}"
        echo "Usage: $0 --existing <branch-name>"
        exit 1
    fi

    BRANCH_NAME="$2"

    # Verify branch exists locally or remotely
    if ! git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null && \
       ! git show-ref --verify --quiet "refs/remotes/origin/$BRANCH_NAME" 2>/dev/null; then
        echo -e "${RED}Error: Branch '$BRANCH_NAME' not found locally or on remote${NC}"
        echo ""
        echo "Available branches matching pattern:"
        git branch -a | grep -i "${BRANCH_NAME##*/}" | head -10 || echo "  (none found)"
        exit 1
    fi

    # Extract directory name from branch (strip type prefix like feature/, bugfix/, etc.)
    DIR_NAME=$(echo "$BRANCH_NAME" | sed 's|^[^/]*/||')
    WORKTREE_DIR="${PARENT_DIR}/${DIR_NAME}"

    # Check if directory already exists
    if [ -d "$WORKTREE_DIR" ]; then
        echo -e "${RED}Error: Directory already exists: $WORKTREE_DIR${NC}"
        exit 1
    fi

    # For port calculation, use the directory name as KEBAB_NAME
    KEBAB_NAME="$DIR_NAME"
    PREFIX=""

    echo -e "${YELLOW}Creating worktree for existing branch...${NC}"
    echo "  Branch:    $BRANCH_NAME"
    echo "  Directory: $WORKTREE_DIR"
    echo ""

    # Check out the branch
    if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
        echo -e "${YELLOW}Branch exists locally, checking out...${NC}"
        git worktree add "$WORKTREE_DIR" "$BRANCH_NAME"
    else
        echo -e "${YELLOW}Branch exists on remote, tracking...${NC}"
        git worktree add "$WORKTREE_DIR" "$BRANCH_NAME"
    fi

    EXISTING_MODE=true
else
    EXISTING_MODE=false
fi

# Only run normal argument parsing if not in --existing mode
if [ "$EXISTING_MODE" = false ]; then

# Determine argument layout
if [ -z "$1" ]; then
    echo -e "${YELLOW}Enter prefix/ticket ID (optional, press Enter to skip):${NC}"
    read -r PREFIX
    echo ""
    echo -e "${YELLOW}Enter feature name (required):${NC}"
    read -r FEATURE_NAME
    echo ""
    BRANCH_TYPE=""

    if [ -z "$FEATURE_NAME" ]; then
        echo -e "${RED}Error: Feature name is required${NC}"
        exit 1
    fi
elif [ -z "$2" ]; then
    PREFIX=""
    FEATURE_NAME="$1"
    BRANCH_TYPE=""
elif [[ "$2" =~ ^(feature|bugfix|hotfix|refactor)$ ]]; then
    PREFIX=""
    FEATURE_NAME="$1"
    BRANCH_TYPE="$2"
else
    PREFIX="$1"
    FEATURE_NAME="$2"
    BRANCH_TYPE="$3"
fi

# Sanitize PREFIX
if [ -n "$PREFIX" ]; then
    PREFIX=$(echo "$PREFIX" | \
        tr '[:lower:]' '[:upper:]' | \
        sed 's/[[:space:]_]/-/g' | \
        sed 's/[^A-Z0-9-]//g' | \
        sed 's/-\+/-/g' | \
        sed 's/^-//' | \
        sed 's/-$//')
fi

# Interactive branch type selection if not provided
if [ -z "$BRANCH_TYPE" ]; then
    echo -e "${YELLOW}Select branch type:${NC}"
    echo ""
    PS3="Enter choice [1-4]: "
    options=("feature" "bugfix" "hotfix" "refactor")
    select opt in "${options[@]}"; do
        case $opt in
            "feature"|"bugfix"|"hotfix"|"refactor")
                BRANCH_TYPE="$opt"
                echo ""
                break
                ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-4.${NC}"
                ;;
        esac
    done
fi

# Convert feature name to kebab-case
KEBAB_NAME=$(echo "$FEATURE_NAME" | \
    sed "s/['\"]//g" | \
    tr '[:upper:]' '[:lower:]' | \
    sed 's/[[:space:]_]/-/g' | \
    sed 's/[^a-z0-9-]//g' | \
    sed 's/-\+/-/g' | \
    sed 's/^-//' | \
    sed 's/-$//')

# Construct base branch name and directory name
if [ -n "$PREFIX" ]; then
    BASE_BRANCH_NAME="${BRANCH_TYPE}/${PREFIX}-${KEBAB_NAME}"
    BASE_DIR_NAME="${PREFIX}-${KEBAB_NAME}"
else
    BASE_BRANCH_NAME="${BRANCH_TYPE}/${KEBAB_NAME}"
    BASE_DIR_NAME="${KEBAB_NAME}"
fi

# Function to check if branch or directory exists
branch_or_dir_exists() {
    local branch="$1"
    local dir="$2"

    if [ -d "$dir" ]; then
        return 0
    fi

    if git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
        return 0
    fi
    if git show-ref --verify --quiet "refs/remotes/origin/$branch" 2>/dev/null; then
        return 0
    fi

    return 1
}

# Find unique branch name and directory
BRANCH_NAME="$BASE_BRANCH_NAME"
DIR_NAME="$BASE_DIR_NAME"
WORKTREE_DIR="${PARENT_DIR}/${DIR_NAME}"
SUFFIX=1

while branch_or_dir_exists "$BRANCH_NAME" "$WORKTREE_DIR"; do
    SUFFIX=$((SUFFIX + 1))
    BRANCH_NAME="${BASE_BRANCH_NAME}-${SUFFIX}"
    DIR_NAME="${BASE_DIR_NAME}-${SUFFIX}"
    WORKTREE_DIR="${PARENT_DIR}/${DIR_NAME}"
done

if [ "$SUFFIX" -gt 1 ]; then
    echo -e "${YELLOW}Note: Base name already exists, using suffix -${SUFFIX}${NC}"
    echo ""
fi

echo -e "${YELLOW}Creating worktree...${NC}"
echo "  Branch:    $BRANCH_NAME"
echo "  Directory: $WORKTREE_DIR"
echo ""

# Create the worktree
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
    echo -e "${YELLOW}Branch exists locally, checking out...${NC}"
    git worktree add "$WORKTREE_DIR" "$BRANCH_NAME"
elif git show-ref --verify --quiet "refs/remotes/origin/$BRANCH_NAME" 2>/dev/null; then
    echo -e "${YELLOW}Branch exists on remote, tracking...${NC}"
    git worktree add "$WORKTREE_DIR" "$BRANCH_NAME"
else
    echo -e "${YELLOW}Fetching latest main...${NC}"
    git fetch origin main 2>/dev/null || git fetch origin master 2>/dev/null || true
    echo -e "${YELLOW}Creating new branch from origin/main...${NC}"
    git worktree add --no-track -b "$BRANCH_NAME" "$WORKTREE_DIR" origin/main 2>/dev/null || \
    git worktree add --no-track -b "$BRANCH_NAME" "$WORKTREE_DIR" origin/master
fi

fi # End of EXISTING_MODE=false block

echo ""
echo -e "${GREEN}✓ Worktree created successfully!${NC}"
echo ""

# Create worktree-specific .env with unique ports
if [ -f "$REPO_ROOT/.env" ]; then
    ENV_SOURCE="$REPO_ROOT/.env"
elif [ -f "$WORKTREE_DIR/.env.example" ]; then
    ENV_SOURCE="$WORKTREE_DIR/.env.example"
else
    ENV_SOURCE=""
fi

if [ -n "$ENV_SOURCE" ]; then
    # Calculate port offset from prefix or hash of kebab name
    if [ -n "$PREFIX" ]; then
        PORT_OFFSET=$(echo "$PREFIX" | grep -oE '[0-9]+' | tail -1)
    fi
    if [ -z "$PORT_OFFSET" ]; then
        PORT_OFFSET=$(echo -n "$KEBAB_NAME" | cksum | cut -d' ' -f1)
        PORT_OFFSET=$((PORT_OFFSET % 999 + 1))
    fi

    PORT_OFFSET=$((PORT_OFFSET % 1000))
    if [ "$PORT_OFFSET" -eq 0 ]; then
        PORT_OFFSET=1
    fi

    # WordPress-specific ports
    WP_PORT=$((8000 + PORT_OFFSET))
    PMA_PORT=$((9000 + PORT_OFFSET))

    # Generate project name for Docker
    if [ -n "$PREFIX" ]; then
        PROJECT_NAME=$(echo "${PREFIX}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
    else
        PROJECT_NAME=$(echo "${KEBAB_NAME}" | cut -c1-20 | sed 's/-$//')
    fi

    # Copy env file
    cp "$ENV_SOURCE" "$WORKTREE_DIR/.env"

    # Update WordPress-specific settings
    sed -i "s|^PROJECT_NAME=.*|PROJECT_NAME=${PROJECT_NAME}|" "$WORKTREE_DIR/.env"
    sed -i "s|^WP_PORT=.*|WP_PORT=${WP_PORT}|" "$WORKTREE_DIR/.env"
    sed -i "s|^PMA_PORT=.*|PMA_PORT=${PMA_PORT}|" "$WORKTREE_DIR/.env"
    sed -i "s|^WP_HOME=.*|WP_HOME=http://localhost:${WP_PORT}|" "$WORKTREE_DIR/.env"
    sed -i "s|^WP_SITEURL=.*|WP_SITEURL=http://localhost:${WP_PORT}|" "$WORKTREE_DIR/.env"

    # Add COMPOSE_PROJECT_NAME for Docker resource isolation
    if ! grep -q "^COMPOSE_PROJECT_NAME=" "$WORKTREE_DIR/.env"; then
        echo "" >> "$WORKTREE_DIR/.env"
        echo "# Docker Compose project name (ensures isolated volumes/networks)" >> "$WORKTREE_DIR/.env"
        echo "COMPOSE_PROJECT_NAME=${PROJECT_NAME}" >> "$WORKTREE_DIR/.env"
    else
        sed -i "s|^COMPOSE_PROJECT_NAME=.*|COMPOSE_PROJECT_NAME=${PROJECT_NAME}|" "$WORKTREE_DIR/.env"
    fi

    echo -e "${GREEN}✓ .env created with unique ports:${NC}"
    echo "  WordPress:   http://localhost:$WP_PORT"
    echo "  phpMyAdmin:  http://localhost:$PMA_PORT"
    echo "  Project:     $PROJECT_NAME"
fi

echo ""
echo "Next steps:"
echo "  cd $WORKTREE_DIR"
echo "  docker compose up -d"
echo ""
echo "To remove this worktree later:"
echo "  git worktree remove $WORKTREE_DIR"

# Open VS Code
echo ""
echo -e "${GREEN}Opening VS Code...${NC}"
code "$WORKTREE_DIR"
