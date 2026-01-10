#!/bin/bash
#
# Remove a git worktree and clean up Docker resources
#
# Usage: ./scripts/worktree-remove.sh <worktree-path>
#        ./scripts/worktree-remove.sh ../client-website

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

if [ -z "$1" ]; then
    echo -e "${YELLOW}Available worktrees:${NC}"
    git worktree list
    echo ""
    echo "Usage: $0 <worktree-path>"
    exit 1
fi

WORKTREE_PATH="$1"

# Convert to absolute path if relative
if [[ ! "$WORKTREE_PATH" = /* ]]; then
    WORKTREE_PATH="$(cd "$(dirname "$WORKTREE_PATH")" 2>/dev/null && pwd)/$(basename "$WORKTREE_PATH")"
fi

# Check if it's a valid worktree
if ! git worktree list | grep -q "$WORKTREE_PATH"; then
    echo -e "${RED}Error: '$WORKTREE_PATH' is not a valid worktree${NC}"
    echo ""
    echo "Available worktrees:"
    git worktree list
    exit 1
fi

# Check for .env to get PROJECT_NAME for Docker cleanup
if [ -f "$WORKTREE_PATH/.env" ]; then
    PROJECT_NAME=$(grep "^PROJECT_NAME=" "$WORKTREE_PATH/.env" | cut -d'=' -f2)

    if [ -n "$PROJECT_NAME" ]; then
        echo -e "${YELLOW}Stopping Docker containers for project: $PROJECT_NAME${NC}"
        cd "$WORKTREE_PATH"
        docker compose down -v 2>/dev/null || true
    fi
fi

echo -e "${YELLOW}Removing worktree: $WORKTREE_PATH${NC}"
git worktree remove "$WORKTREE_PATH" --force

echo ""
echo -e "${GREEN}✓ Worktree removed successfully${NC}"
