#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    cat << EOF
Usage: $0 [--dry-run] [--force]

Delete all remote branches except 'main' from the repository.

Options:
  --dry-run  Preview which branches would be deleted without making changes
  --force    Skip confirmation prompt and delete branches immediately

Examples:
  # Preview which branches would be deleted
  $0 --dry-run

  # Delete branches with confirmation
  $0

  # Delete branches without confirmation
  $0 --force

Safety:
  - The 'main' branch is protected and cannot be deleted
  - The 'HEAD' pointer is automatically excluded
  - Requires confirmation by default (unless --force is used)
EOF
    exit 0
}

# Parse arguments
DRY_RUN=false
FORCE=false

for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            ;;
        --force)
            FORCE=true
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Error: Unknown argument '$arg'${NC}"
            usage
            ;;
    esac
done

echo -e "${BLUE}=== Delete Non-Main Branches ===${NC}\n"

# Get list of remote branches, excluding main and HEAD
echo -e "${YELLOW}Fetching remote branches...${NC}"
BRANCHES=$(git ls-remote --heads origin | awk '{print $2}' | sed 's|refs/heads/||' | grep -v "^main$" || true)

if [ -z "$BRANCHES" ]; then
    echo -e "${GREEN}✓ No non-main branches found. Nothing to delete.${NC}"
    exit 0
fi

# Count branches
BRANCH_COUNT=$(echo "$BRANCHES" | wc -l | tr -d ' ')

echo -e "${YELLOW}Found ${BRANCH_COUNT} branch(es) to delete:${NC}"
echo "$BRANCHES" | while read -r branch; do
    echo "  - $branch"
done
echo ""

# Dry run mode
if [ "$DRY_RUN" = true ]; then
    echo -e "${BLUE}[DRY RUN] Would delete ${BRANCH_COUNT} branch(es)${NC}"
    echo -e "${GREEN}✓ Dry run complete. No branches were deleted.${NC}"
    exit 0
fi

# Confirmation prompt
if [ "$FORCE" = false ]; then
    echo -e "${YELLOW}This will permanently delete ${BRANCH_COUNT} remote branch(es).${NC}"
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo -e "${YELLOW}Aborted. No branches were deleted.${NC}"
        exit 0
    fi
fi

# Delete branches
echo -e "${YELLOW}Deleting branches...${NC}"
DELETED_COUNT=0
FAILED_COUNT=0

while read -r branch; do
    if [ -z "$branch" ]; then
        continue
    fi
    
    echo -n "  Deleting $branch... "
    if git push origin --delete "$branch" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        DELETED_COUNT=$((DELETED_COUNT + 1))
    else
        echo -e "${RED}✗ (failed)${NC}"
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
done <<< "$BRANCHES"

echo ""
echo -e "${GREEN}✓ Branch deletion complete${NC}"
echo -e "  Deleted: ${DELETED_COUNT} branch(es)"

if [ "$FAILED_COUNT" -gt 0 ]; then
    echo -e "  ${RED}Failed: ${FAILED_COUNT} branch(es)${NC}"
fi
