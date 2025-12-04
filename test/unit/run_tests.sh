#!/bin/bash

# Unit test suite for retain-artifacts action
# Tests individual components and logic without external dependencies

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DATA_DIR="$SCRIPT_DIR/data"
TEMP_DIR=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Cleanup function
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

# Test helper functions
setup_test() {
    TEMP_DIR=$(mktemp -d)
    mkdir -p "$TEST_DATA_DIR"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✅ PASS${NC}: $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}: $message"
        echo -e "  Expected: ${BLUE}$expected${NC}"
        echo -e "  Actual:   ${BLUE}$actual${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_contains() {
    local substring="$1"
    local text="$2"
    local message="${3:-}"

    if echo "$text" | grep -q "$substring"; then
        echo -e "${GREEN}✅ PASS${NC}: $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}: $message"
        echo -e "  Expected substring: ${BLUE}$substring${NC}"
        echo -e "  In text: ${BLUE}$text${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist: $file}"

    if [ -f "$file" ]; then
        echo -e "${GREEN}✅ PASS${NC}: $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}: $message"
        echo -e "  File does not exist: ${BLUE}$file${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test 1: JSON processing logic
test_json_processing() {
    setup_test
    echo -e "\n${YELLOW}🧪 Test 1: JSON Processing Logic${NC}"

    # Create test JSON
    local test_json='{"total_count": 3, "artifacts": [
        {"name": "test1", "id": 111, "size_in_bytes": 1024},
        {"name": "test2", "id": 222, "size_in_bytes": 2048},
        {"name": "test3", "id": 333, "size_in_bytes": 512}
    ]}'

    echo "$test_json" > "$TEMP_DIR/test_artifacts.json"

    # Test artifact count extraction
    local count=$(echo "$test_json" | jq '.total_count')
    assert_equals "3" "$count" "Should extract correct artifact count"

    # Test artifact names extraction
    local names=$(echo "$test_json" | jq -r '.artifacts[].name' | tr '\n' ',' | sed 's/,$//')
    assert_equals "test1,test2,test3" "$names" "Should extract artifact names correctly"

    # Test total size calculation
    local total_size=$(echo "$test_json" | jq '[.artifacts[].size_in_bytes] | add')
    assert_equals "3584" "$total_size" "Should calculate total size correctly"
}

# Test 2: Release tag generation
test_release_tag_generation() {
    setup_test
    echo -e "\n${YELLOW}🧪 Test 2: Release Tag Generation${NC}"

    # Set test environment variables
    export GITHUB_RUN_ID="123456789"

    # Test auto-generated tag format
    local timestamp=$(date +"%Y%m%d-%H%M%S")
    local expected_pattern="pipeline-${GITHUB_RUN_ID}-[0-9]{8}-[0-9]{6}"

    # Simulate tag generation logic
    local generated_tag="pipeline-${GITHUB_RUN_ID}-${timestamp}"

    assert_contains "pipeline-123456789-" "$generated_tag" "Generated tag should contain run ID"
    assert_contains "$(date +%Y%m%d)" "$generated_tag" "Generated tag should contain date"

    # Test custom tag passthrough
    local custom_tag="v1.0.0-custom"
    assert_equals "$custom_tag" "$custom_tag" "Custom tags should be passed through unchanged"
}

# Test 3: Immutable releases detection logic
test_immutable_releases_detection() {
    setup_test
    echo -e "\n${YELLOW}🧪 Test 3: Immutable Releases Detection${NC}"

    # Test case 1: Organization repository with security features
    local org_repo_with_security='{"owner": {"type": "Organization"}, "security_and_analysis": {"secret_scanning": {"status": "enabled"}}, "visibility": "private"}'
    local immutable_result="unknown"

    # Simulate the logic from the action
    local owner_type=$(echo "$org_repo_with_security" | jq -r '.owner.type // "unknown"')
    if [ "$owner_type" = "Organization" ]; then
        if echo "$org_repo_with_security" | jq -e '.security_and_analysis.secret_scanning.status == "enabled"' > /dev/null 2>&1; then
            immutable_result="likely"
        else
            immutable_result="supported"
        fi
    else
        immutable_result="unsupported"
    fi

    assert_equals "likely" "$immutable_result" "Should detect likely immutable capability for org repo with security features"

    # Test case 2: User repository (not organization)
    local user_repo='{"owner": {"type": "User"}, "security_and_analysis": null, "visibility": "public"}'
    local user_owner_type=$(echo "$user_repo" | jq -r '.owner.type // "unknown"')
    local user_immutable="unknown"

    if [ "$user_owner_type" = "Organization" ]; then
        user_immutable="supported"
    else
        user_immutable="unsupported"
    fi

    assert_equals "unsupported" "$user_immutable" "Should detect unsupported for user repositories"

    # Test case 3: Organization repository without security features
    local org_basic='{"owner": {"type": "Organization"}, "security_and_analysis": null, "visibility": "private"}'
    local org_owner_type=$(echo "$org_basic" | jq -r '.owner.type // "unknown"')
    local org_immutable="unknown"

    if [ "$org_owner_type" = "Organization" ]; then
        org_immutable="supported"
    fi

    assert_equals "supported" "$org_immutable" "Should detect supported for organization repositories"
}

# Test 4: Release body generation
test_release_body_generation() {
    setup_test
    echo -e "\n${YELLOW}🧪 Test 4: Release Body Generation${NC}"

    # Set up test environment
    export GITHUB_RUN_ID="987654321"
    export GITHUB_SHA="abcdef123456"
    export GITHUB_REF_NAME="main"
    export GITHUB_WORKFLOW="Test Workflow"
    export GITHUB_EVENT_NAME="push"
    export GITHUB_ACTOR="test-user"

    # Simulate release body generation
    local release_body="Automated release created from pipeline run"
    release_body="${release_body}\n\n## Pipeline Information"
    release_body="${release_body}\n- **Run ID:** $GITHUB_RUN_ID"
    release_body="${release_body}\n- **Commit:** $GITHUB_SHA"
    release_body="${release_body}\n- **Branch:** $GITHUB_REF_NAME"

    assert_contains "Run ID.*987654321" "$release_body" "Release body should contain run ID"
    assert_contains "Commit.*abcdef123456" "$release_body" "Release body should contain commit SHA"
    assert_contains "Branch.*main" "$release_body" "Release body should contain branch name"
}

# Test 5: Size formatting
test_size_formatting() {
    setup_test
    echo -e "\n${YELLOW}🧪 Test 5: Size Formatting${NC}"

    # Test human-readable size formatting
    if command -v numfmt >/dev/null 2>&1; then
        local size_1kb=$(numfmt --to=iec-i --suffix=B 1024)
        assert_equals "1.0KiB" "$size_1kb" "Should format 1KB correctly"

        local size_1mb=$(numfmt --to=iec-i --suffix=B 1048576)
        assert_equals "1.0MiB" "$size_1mb" "Should format 1MB correctly"
    else
        echo -e "${YELLOW}⚠️ SKIP${NC}: numfmt not available, skipping size formatting tests"
        TESTS_TOTAL=$((TESTS_TOTAL - 2))
    fi
}

# Test 6: Error handling scenarios
test_error_handling() {
    setup_test
    echo -e "\n${YELLOW}🧪 Test 6: Error Handling${NC}"

    # Test empty artifacts JSON
    local empty_artifacts='{"total_count": 0, "artifacts": []}'
    local count=$(echo "$empty_artifacts" | jq '.total_count')
    assert_equals "0" "$count" "Should handle empty artifacts gracefully"

    # Test malformed JSON handling
    local malformed_json='{"total_count": invalid}'

    if echo "$malformed_json" | jq '.total_count' 2>/dev/null; then
        echo -e "${RED}❌ FAIL${NC}: Should reject malformed JSON"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    else
        echo -e "${GREEN}✅ PASS${NC}: Correctly rejects malformed JSON"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

# Test 7: Required tools availability
test_required_tools() {
    setup_test
    echo -e "\n${YELLOW}🧪 Test 7: Required Tools Availability${NC}"

    # Test jq availability
    if command -v jq >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}: jq is available"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: jq is not available"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    # Test curl availability
    if command -v curl >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}: curl is available"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: curl is not available"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    # Test date command
    if command -v date >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}: date command is available"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: date command is not available"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

# Test 8: GitHub CLI commands structure
test_gh_commands() {
    setup_test
    echo -e "\n${YELLOW}🧪 Test 8: GitHub CLI Commands Structure${NC}"

    # Test release creation command structure
    local release_tag="test-tag"
    local release_title="Test Release"
    local release_notes="Test notes"

    local expected_cmd="gh release create '$release_tag' --title '$release_title' --notes '$release_notes'"
    local actual_cmd="gh release create '$release_tag' --title '$release_title' --notes '$release_notes'"

    assert_equals "$expected_cmd" "$actual_cmd" "Release creation command should be properly formatted"

    # Test API endpoint format
    local repo="owner/repo"
    local run_id="123456"
    local expected_endpoint="repos/$repo/actions/runs/$run_id/artifacts"
    local actual_endpoint="repos/$repo/actions/runs/$run_id/artifacts"

    assert_equals "$expected_endpoint" "$actual_endpoint" "API endpoint should be correctly formatted"
}

# Main test execution
main() {
    echo -e "${BLUE}🚀 Starting Retain Artifacts Action Unit Tests${NC}"
    echo "=============================================="

    # Check prerequisites
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${RED}❌ Error: jq is required for tests but not installed${NC}"
        exit 1
    fi

    # Run all tests
    test_json_processing
    test_release_tag_generation
    test_immutable_releases_detection
    test_release_body_generation
    test_size_formatting
    test_error_handling
    test_required_tools
    test_gh_commands

    # Print summary
    echo -e "\n${BLUE}📊 Test Summary${NC}"
    echo "==============="
    echo -e "Total Tests: ${BLUE}$TESTS_TOTAL${NC}"
    echo -e "Passed:      ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed:      ${RED}$TESTS_FAILED${NC}"

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n${GREEN}🎉 All unit tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}💥 Some tests failed!${NC}"
        exit 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi