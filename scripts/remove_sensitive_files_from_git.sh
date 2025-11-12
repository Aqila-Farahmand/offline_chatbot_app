#!/bin/bash

# Script to remove sensitive Firebase config files from git history
# WARNING: This rewrites git history. Only run this if you understand the implications.
# After running, you'll need to force push: git push --force

set -e

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${YELLOW}WARNING: This script will rewrite git history!${NC}"
echo -e "${YELLOW}This should only be run if sensitive files were previously committed.${NC}"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo -e "${GREEN}Removing sensitive files from git history...${NC}"

# Remove files from git history using git filter-branch or git filter-repo
# Using BFG Repo-Cleaner is recommended, but git filter-branch works too

# Check if git-filter-repo is available (preferred method)
if command -v git-filter-repo &> /dev/null; then
    echo "Using git-filter-repo..."
    git filter-repo --path android/app/google-services.json --invert-paths
    git filter-repo --path ios/Runner/GoogleService-Info.plist --invert-paths
    git filter-repo --path macos/Runner/GoogleService-Info.plist --invert-paths
else
    echo "Using git filter-branch (slower, but works without additional tools)..."
    git filter-branch --force --index-filter \
        "git rm --cached --ignore-unmatch android/app/google-services.json ios/Runner/GoogleService-Info.plist macos/Runner/GoogleService-Info.plist" \
        --prune-empty --tag-name-filter cat -- --all
fi

echo -e "${GREEN}✓ Files removed from git history${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Verify the changes: git log --all --full-history -- android/app/google-services.json"
echo "2. Force push to remote: git push --force --all"
echo "3. Force push tags: git push --force --tags"
echo ""
echo -e "${RED}WARNING: Force pushing rewrites remote history.${NC}"
echo -e "${RED}Make sure all team members are aware and have pulled the changes.${NC}"

