#!/bin/bash

# Approval Validation Script
# Validates that a PR has been approved by an authorized platform administrator
# Exit 0 if valid approver found, exit 1 if no valid approver

set -e

PR_NUMBER="$1"
REPO="$2"

if [ -z "$PR_NUMBER" ] || [ -z "$REPO" ]; then
    echo "Usage: $0 <pr_number> <repo>"
    echo "Example: $0 123 owner/repo"
    exit 1
fi

echo "============================================"
echo "APPROVAL VALIDATION"
echo "============================================"
echo ""
echo "PR: #$PR_NUMBER"
echo "Repository: $REPO"
echo ""

# Define allowed approvers
# In production, this should be loaded from a config file or GitHub team API
ALLOWED_APPROVERS=(
    "platform-admin-1"
    "platform-admin-2"
    "platform-lead"
    "nikhilgummadavelli8"  # Repository owner - adjust as needed
)

echo "Authorized platform administrators:"
for approver in "${ALLOWED_APPROVERS[@]}"; do
    echo "  - @$approver"
done
echo ""

# Check if GitHub CLI is available
if ! command -v gh &> /dev/null; then
    echo "❌ ERROR: GitHub CLI (gh) is not installed"
    echo "This script requires gh CLI to query PR approvals"
    exit 1
fi

# Check if GITHUB_TOKEN is set
if [ -z "$GITHUB_TOKEN" ] && [ -z "$GH_TOKEN" ]; then
    echo "❌ ERROR: GITHUB_TOKEN or GH_TOKEN environment variable not set"
    echo "This script requires authentication to query PR reviews"
    exit 1
fi

echo "Fetching PR reviews from GitHub API..."

# Get PR reviews
REVIEWS=$(gh api "repos/$REPO/pulls/$PR_NUMBER/reviews" --jq '.[] | select(.state == "APPROVED") | .user.login' 2>/dev/null || echo "")

if [ -z "$REVIEWS" ]; then
    echo ""
    echo "❌ NO APPROVALS FOUND"
    echo ""
    echo "This PR has not been approved yet."
    echo ""
    echo "Required action:"
    echo "  1. Request review from a platform administrator"
    echo "  2. Wait for approval"
    echo "  3. Re-run this validation"
    echo ""
    echo "Platform administrators who can approve:"
    for approver in "${ALLOWED_APPROVERS[@]}"; do
        echo "  - @$approver"
    done
    echo ""
    exit 1
fi

echo "Found approvals:"
echo "$REVIEWS" | while read -r reviewer; do
    echo "  - @$reviewer"
done
echo ""

# Check if any approver is in the allowed list
VALID_APPROVER_FOUND=false

while IFS= read -r reviewer; do
    for allowed in "${ALLOWED_APPROVERS[@]}"; do
        if [ "$reviewer" = "$allowed" ]; then
            VALID_APPROVER_FOUND=true
            VALID_APPROVER="$reviewer"
            break 2
        fi
    done
done <<< "$REVIEWS"

if [ "$VALID_APPROVER_FOUND" = true ]; then
    echo "✅ APPROVAL VALID"
    echo ""
    echo "Authorized approver: @$VALID_APPROVER"
    echo ""
    echo "Platform code changes have been approved by an authorized administrator."
    exit 0
else
    echo "❌ NO AUTHORIZED APPROVER"
    echo ""
    echo "This PR has approvals, but none from authorized platform administrators."
    echo ""
    echo "Current approvers:"
    echo "$REVIEWS" | while read -r reviewer; do
        echo "  - @$reviewer (NOT in authorized list)"
    done
    echo ""
    echo "Required action:"
    echo "  Request review from an authorized platform administrator:"
    for approver in "${ALLOWED_APPROVERS[@]}"; do
        echo "    - @$approver"
    done
    echo ""
    exit 1
fi
