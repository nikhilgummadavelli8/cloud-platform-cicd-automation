#!/bin/bash

# Repository Validation Script
# Validates that a repository meets platform requirements
# Exit 0 on success, non-zero on failure

set -e

REPO_DIR="${1:-.}"

echo "============================================"
echo "DETAILED REPOSITORY VALIDATION"
echo "============================================"
echo ""
echo "Repository directory: $REPO_DIR"
echo ""

# Track validation failures
VALIDATION_FAILED=0

# ============================================
# CHECK 1: Required Files
# ============================================
echo "CHECK 1: Required Files"
echo "-------------------------------------------"

check_file() {
    local file=$1
    local description=$2
    
    if [ -f "$REPO_DIR/$file" ]; then
        echo "✅ Found: $file ($description)"
        return 0
    else
        echo "❌ Missing: $file ($description)"
        VALIDATION_FAILED=1
        return 1
    fi
}

# Check for app pipeline workflow
check_file ".github/workflows/app-pipeline.yml" "Application CI/CD workflow"

# Check for CODEOWNERS (either location is acceptable)
if [ -f "$REPO_DIR/CODEOWNERS" ] || [ -f "$REPO_DIR/.github/CODEOWNERS" ]; then
    echo "✅ Found: CODEOWNERS (Code ownership)"
    CODEOWNERS_FILE=$([ -f "$REPO_DIR/CODEOWNERS" ] && echo "$REPO_DIR/CODEOWNERS" || echo "$REPO_DIR/.github/CODEOWNERS")
else
    echo "❌ Missing: CODEOWNERS (must be at root or in .github/)"
    VALIDATION_FAILED=1
    CODEOWNERS_FILE=""
fi

echo ""

# ============================================
# CHECK 2: CODEOWNERS Validation
# ============================================
if [ -n "$CODEOWNERS_FILE" ]; then
    echo "CHECK 2: CODEOWNERS Validation"
    echo "-------------------------------------------"
    
    # Check file is not empty
    if [ -s "$CODEOWNERS_FILE" ]; then
        echo "✅ CODEOWNERS file is not empty"
        
        # Check for at least one owner entry
        # Skip comments and blank lines
        OWNER_COUNT=$(grep -v '^#' "$CODEOWNERS_FILE" | grep -v '^[[:space:]]*$' | wc -l)
        
        if [ "$OWNER_COUNT" -gt 0 ]; then
            echo "✅ CODEOWNERS contains $OWNER_COUNT ownership rule(s)"
        else
            echo "❌ CODEOWNERS has no ownership rules (only comments/blank lines)"
            VALIDATION_FAILED=1
        fi
    else
        echo "❌ CODEOWNERS file is empty"
        VALIDATION_FAILED=1
    fi
    
    echo ""
fi

# ============================================
# CHECK 3: App Pipeline Workflow Validation
# ============================================
if [ -f "$REPO_DIR/.github/workflows/app-pipeline.yml" ]; then
    echo "CHECK 3: App Pipeline Workflow Validation"
    echo "-------------------------------------------"
    
    WORKFLOW_FILE="$REPO_DIR/.github/workflows/app-pipeline.yml"
    
    # Check file is not empty
    if [ -s "$WORKFLOW_FILE" ]; then
        echo "✅ Workflow file is not empty"
        
        # Check for required workflow structure
        if grep -q "^on:" "$WORKFLOW_FILE"; then
            echo "✅ Workflow has trigger definition"
        else
            echo "⚠️  Workflow missing 'on:' trigger (may be invalid)"
        fi
        
        # Check if it uses the platform reusable workflow
        if grep -q "uses:.*workflows/cicd-platform.yml" "$WORKFLOW_FILE"; then
            echo "✅ Workflow uses platform reusable workflow"
        else
            echo "⚠️  Workflow doesn't use platform reusable workflow"
            echo "   Recommendation: Use reusable workflow for consistency"
        fi
    else
        echo "❌ Workflow file is empty"
        VALIDATION_FAILED=1
    fi
    
    echo ""
fi

# ============================================
# VALIDATION SUMMARY
# ============================================
echo "============================================"
echo "VALIDATION SUMMARY"
echo "============================================"
echo ""

if [ $VALIDATION_FAILED -eq 0 ]; then
    echo "✅ ALL VALIDATIONS PASSED"
    echo ""
    echo "Repository meets platform requirements."
    echo "Proceed with onboarding."
    exit 0
else
    echo "❌ VALIDATION FAILED"
    echo ""
    echo "Repository does not meet platform requirements."
    echo ""
    echo "To fix:"
    echo "  1. Add missing required files"
    echo "  2. Ensure CODEOWNERS is properly configured"
    echo "  3. Verify app-pipeline.yml workflow is valid"
    echo "  4. Re-run onboarding validation"
    echo ""
    exit 1
fi
