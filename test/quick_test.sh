#!/bin/bash

# Quick test script for retain-artifacts action
# Tests the action locally without requiring GitHub repository setup

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Quick Test for Retain Artifacts Action${NC}"
echo "==========================================="
echo ""

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper function
run_test() {
    local test_name="$1"
    local test_command="$2"

    echo -e "${YELLOW}🧪 $test_name${NC}"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✅ PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}❌ FAIL${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        # Show the error for debugging
        echo -e "  ${RED}Error:${NC}"
        eval "$test_command" 2>&1 | sed 's/^/    /'
    fi
    echo ""
}

# Test 1: Check action.yml exists and is valid
run_test "Action definition exists and is valid YAML" \
    "test -f '$ACTION_DIR/action.yml' && python3 -c 'import yaml; yaml.safe_load(open(\"$ACTION_DIR/action.yml\"))' 2>/dev/null || yq eval . '$ACTION_DIR/action.yml' >/dev/null"

# Test 2: Check required tools
run_test "jq is available" "command -v jq"
run_test "curl is available" "command -v curl"
run_test "GitHub CLI is available" "command -v gh"

# Test 3: Run unit tests
run_test "Unit tests pass" "cd '$ACTION_DIR' && bash test/unit/run_tests.sh"

# Test 4: Run local logic test
run_test "Local logic tests pass" "cd '$ACTION_DIR' && bash test/local_test.sh"

# Test 5: Check action.yml structure
run_test "Action has required inputs" "grep -q 'github_token:' '$ACTION_DIR/action.yml'"
run_test "Action has required outputs" "grep -q 'outputs:' '$ACTION_DIR/action.yml'"
run_test "Action is composite type" "grep -q \"using: 'composite'\" '$ACTION_DIR/action.yml'"

# Test 6: Check documentation exists
run_test "README exists" "test -f '$ACTION_DIR/README.md'"
run_test "Getting started guide exists" "test -f '$ACTION_DIR/doc/GETTING_STARTED.md'"
run_test "Architecture documentation exists" "test -f '$ACTION_DIR/doc/ARCHITECTURE.md'"

# Test 7: Check CI workflows exist
run_test "CI workflow exists" "test -f '$ACTION_DIR/.github/workflows/ci.yml'"
run_test "Release workflow exists" "test -f '$ACTION_DIR/.github/workflows/release.yml'"
run_test "Test workflow exists" "test -f '$ACTION_DIR/.github/workflows/test-action.yml'"

# Print summary
echo -e "${BLUE}📊 Quick Test Summary${NC}"
echo "===================="
echo -e "Total Tests: ${BLUE}$TESTS_TOTAL${NC}"
echo -e "Passed:      ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed:      ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All quick tests passed!${NC}"
    echo ""
    echo -e "${BLUE}📝 Next Steps:${NC}"
    echo "1. Create GitHub repository: NovoNordisk-OpenSource/retain_pipeline_run"
    echo "2. Push this code to the repository"
    echo "3. Run the GitHub workflow tests: gh workflow run test-action.yml"
    echo "4. Test in QMS pipeline with a release branch"
    echo ""
    echo -e "${GREEN}✅ Action is ready for GitHub deployment!${NC}"
    exit 0
else
    echo -e "${RED}💥 Some tests failed!${NC}"
    echo ""
    echo -e "${YELLOW}🔧 Fix the failing tests before deploying to GitHub${NC}"
    exit 1
fi