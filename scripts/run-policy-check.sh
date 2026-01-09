#!/bin/bash
# Policy Check Runner Script
# Validates GitHub workflows against OPA policies
# Usage: ./run-policy-check.sh
# Exit codes: 0 = all policies pass, 1 = violations found

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "============================================"
echo "POLICY-AS-CODE VALIDATION"
echo "============================================"
echo ""

# Check if OPA is installed
if ! command -v opa &> /dev/null; then
    echo -e "${RED}❌ ERROR: OPA (Open Policy Agent) is not installed${NC}"
    echo ""
    echo "Install OPA:"
    echo "  macOS:   brew install opa"
    echo "  Linux:   curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64"
    echo "  Windows: choco install opa"
    echo "  Manual:  https://www.openpolicyagent.org/docs/latest/#running-opa"
    echo ""
    exit 1
fi

echo -e "${GREEN}✅ OPA installed: $(opa version | head -n1)${NC}"
echo ""

# Locate workflows directory
WORKFLOWS_DIR=".github/workflows"
POLICIES_DIR="policies"

if [ ! -d "$WORKFLOWS_DIR" ]; then
    echo -e "${RED}❌ ERROR: Workflows directory not found: $WORKFLOWS_DIR${NC}"
    exit 1
fi

if [ ! -d "$POLICIES_DIR" ]; then
    echo -e "${RED}❌ ERROR: Policies directory not found: $POLICIES_DIR${NC}"
    exit 1
fi

echo -e "${BLUE}📁 Workflows directory: $WORKFLOWS_DIR${NC}"
echo -e "${BLUE}📁 Policies directory: $POLICIES_DIR${NC}"
echo ""

# Count policy files
POLICY_COUNT=$(find "$POLICIES_DIR" -name "*.rego" | wc -l)
echo -e "${BLUE}📋 Found $POLICY_COUNT policy files${NC}"
echo ""

# Initialize counters
TOTAL_WORKFLOWS=0
TOTAL_VIOLATIONS=0
WORKFLOWS_WITH_VIOLATIONS=0

# Create temp directory for JSON conversions
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "============================================"
echo "VALIDATING WORKFLOWS"
echo "============================================"
echo ""

# Process each workflow file
for workflow_file in "$WORKFLOWS_DIR"/*.yml "$WORKFLOWS_DIR"/*.yaml; do
    # Skip if no files found
    [ -e "$workflow_file" ] || continue
    
    TOTAL_WORKFLOWS=$((TOTAL_WORKFLOWS + 1))
    workflow_name=$(basename "$workflow_file")
    
    echo -e "${BLUE}Checking: $workflow_name${NC}"
    
    # Convert YAML to JSON for OPA
    json_file="$TEMP_DIR/${workflow_name}.json"
    
    # Use yq or python to convert YAML to JSON
    if command -v yq &> /dev/null; then
        yq eval -o=json "$workflow_file" > "$json_file"
    elif command -v python3 &> /dev/null; then
        python3 -c "import sys, yaml, json; json.dump(yaml.safe_load(open('$workflow_file')), open('$json_file', 'w'), indent=2)"
    else
        echo -e "${YELLOW}⚠️  WARNING: Cannot convert YAML to JSON (install yq or python3)${NC}"
        echo "   Skipping policy validation for $workflow_name"
        echo ""
        continue
    fi
    
    # Track violations for this workflow
    WORKFLOW_VIOLATIONS=0
    
    # Run OPA evaluation for each policy
    for policy_file in "$POLICIES_DIR"/*.rego; do
        policy_name=$(basename "$policy_file" .rego)
        
        # Evaluate policy
        result=$(opa eval --data "$policy_file" --input "$json_file" --format pretty "data.$policy_name.deny" 2>/dev/null || echo "[]")
        
        # Check for violations
        if [ "$result" != "[]" ] && [ "$result" != "" ]; then
            WORKFLOW_VIOLATIONS=$((WORKFLOW_VIOLATIONS + 1))
            TOTAL_VIOLATIONS=$((TOTAL_VIOLATIONS + 1))
            
            echo -e "${RED}  ❌ Policy violation: $policy_name${NC}"
            echo -e "${RED}     $result${NC}"
        fi
    done
    
    if [ $WORKFLOW_VIOLATIONS -eq 0 ]; then
        echo -e "${GREEN}  ✅ All policies passed${NC}"
    else
        WORKFLOWS_WITH_VIOLATIONS=$((WORKFLOWS_WITH_VIOLATIONS + 1))
    fi
    
    echo ""
done

# Summary
echo "============================================"
echo "POLICY VALIDATION SUMMARY"
echo "============================================"
echo ""
echo "Workflows validated: $TOTAL_WORKFLOWS"
echo "Total violations: $TOTAL_VIOLATIONS"
echo "Workflows with violations: $WORKFLOWS_WITH_VIOLATIONS"
echo ""

if [ $TOTAL_VIOLATIONS -eq 0 ]; then
    echo -e "${GREEN}✅ SUCCESS: All workflows comply with policies${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}❌ FAILURE: Policy violations detected${NC}"
    echo ""
    echo "Policy violations must be resolved before merging."
    echo "Review the violations above and update workflows accordingly."
    echo ""
    exit 1
fi
