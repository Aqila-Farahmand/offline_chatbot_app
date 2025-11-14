#!/bin/bash
# Helper script to load .firebase.configs (or .env) and run Firebase setup
# Usage: ./scripts/load_env_and_setup.sh

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# Debug: Show current directory (only if DEBUG is set)
if [ -n "$DEBUG" ]; then
    echo -e "${YELLOW}Debug: Current directory: $(pwd)${NC}"
    echo -e "${YELLOW}Debug: Looking for .firebase.configs in: $PROJECT_ROOT${NC}"
fi

ENV_FILE=""
if [ -f .firebase.configs ]; then
    ENV_FILE=".firebase.configs"
    echo -e "${GREEN}Loading environment variables from .firebase.configs...${NC}"
elif [ -f .env ]; then
    ENV_FILE=".env"
    echo -e "${GREEN}Loading environment variables from .env...${NC}"
fi

if [ -n "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
    echo -e "${GREEN}✓ Loaded environment variables from $ENV_FILE${NC}"
else
    echo -e "${YELLOW}  No .firebase.configs or .env file found. Using environment variables from shell.${NC}"
    echo "Create a .firebase.configs file in the project root with your Firebase configuration."
    echo "See docs/FIREBASE_ENV_VARIABLES.md for details."
fi

echo ""
./scripts/setup_firebase_config.sh

