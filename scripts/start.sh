#!/bin/bash
#
# Start WordPress development environment
#
# Usage: ./scripts/start.sh
#        ./scripts/start.sh --fresh  # Regenerate ports and reinstall

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$REPO_ROOT"

# Handle --fresh flag
FRESH_FLAG=""
if [[ "$1" == "--fresh" || "$1" == "-f" ]]; then
    FRESH_FLAG="--force"
fi

# Setup .env with random ports
"$SCRIPT_DIR/setup.sh" $FRESH_FLAG

# Start containers
echo ""
docker compose up -d

# Install WordPress
"$SCRIPT_DIR/install-wp.sh"
