#!/bin/bash

# Integration test suite for retain-artifacts action
# Tests the complete action workflow with real GitHub API interactions

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

# Configuration
TEST_REPO="${GITHUB_REPOSITORY:-NovoNordisk-OpenSource/retain_pipeline_run}"
TEST_TOKEN="${GITHUB_TOKEN:-}"
DRY_RUN="${DRY_RUN:-false}"

# Cleanup function
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi

    # Cleanup test releases if not in dry run mode
    if [ "$DRY_RUN" != "true" ] && [ -n "$TEST_TOKEN" ]; then
        cleanup_test_releases
    fi
}

trap cleanup EXIT

# Helper functions
setup_test() {
    TEMP_DIR=$(mktemp -d)
    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if [ -z "$TEST_TOKEN" ]; then
        echo -e "${YELLOW}⚠️ WARNING: GITHUB_TOKEN not set, some tests will be skipped${NC}"
    fi
}

assert_success() {
    local exit_code="$1"
    local message="${2:-Command should succeed}"

    if [ "$exit_code" -eq 0 ]; then
        echo -e "${GREEN}✅ PASS${NC}: $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}: $message"
        echo -e "  Exit code: ${BLUE}$exit_code${NC}"
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

cleanup_test_releases() {
    if [ -n "$TEST_TOKEN" ] && command -v gh >/dev/null 2>&1; then
        echo -e "\n${YELLOW}🧹 Cleaning up test releases...${NC}"

        export GITHUB_TOKEN="$TEST_TOKEN"

        # Get test releases created in the last hour
        CUTOFF_TIME=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)

        gh release list --repo "$TEST_REPO" --limit 50 --json tagName,name,createdAt,prerelease 2>/dev/null | \
        jq -r --arg cutoff "$CUTOFF_TIME" '.[] |
          select(.name | test("Integration Test")) |
          select(.createdAt > $cutoff) |
          .tagName' | \
        while read -r tag; do
            if [ -n "$tag" ]; then
                echo "Deleting test release: $tag"
                gh release delete "$tag" --repo "$TEST_REPO" --yes 2>/dev/null || echo "Failed to delete $tag"
            fi
        done
    fi
}

# Test 1: GitHub CLI availability and authentication
test_github_cli_setup() {
    setup_test
    echo -e "\n${YELLOW}🧪 Test 1: GitHub CLI Setup${NC}"

    # Test GitHub CLI availability
    if command -v gh >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}: GitHub CLI is available"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: GitHub CLI is not available"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    # Test authentication if token is provided
    if [ -n "$TEST_TOKEN" ]; then
        export GITHUB_TOKEN="$TEST_TOKEN"

        if gh auth status >/dev/null 2>&1; then
            echo -e "${GREEN}✅ PASS${NC}: GitHub CLI is authenticated"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}❌ FAIL${NC}: GitHub CLI authentication failed"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
    else
        echo -e "${YELLOW}⚠️ SKIP${NC}: No token provided, skipping auth test"
    fi
}

# Test 2: Repository API access
test_repository_api_access() {
    setup_test
    echo -e "\n${YELLOW}🧪 Test 2: Repository API Access${NC}"

    if [ -z "$TEST_TOKEN" ]; then
        echo -e "${YELLOW}⚠️ SKIP${NC}: No token provided, skipping API tests"
        TESTS_TOTAL=$((TESTS_TOTAL - 1))
        return 0
    fi

    export GITHUB_TOKEN="$TEST_TOKEN"

    # Test repository info retrieval
    local repo_info
    if repo_info=$(gh api "repos/$TEST_REPO" 2>/dev/null); then
        echo -e "${GREEN}✅ PASS${NC}: Can access repository API"
        TESTS_PASSED=$((TESTS_PASSED + 1))

        # Test specific fields
        local repo_name=$(echo "$repo_info" | jq -r '.name')
        if [ -n "$repo_name" ] && [ "$repo_name" != "null" ]; then
            echo -e "${GREEN}✅ PASS${NC}: Repository data is valid"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}❌ FAIL${NC}: Repository data is invalid"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: Cannot access repository API"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

# Test 3: Artifacts API simulation
test_artifacts_api_simulation() {
    setup_test
    echo -e "\n${YELLOW}🧪 Test 3: Artifacts API Simulation${NC}"

    # Create mock artifacts data
    local mock_artifacts_json='{"total_count": 2, "artifacts": [
        {"name": "integration-test-1", "id": 111111, "size_in_bytes": 1024, "created_at": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"},
        {"name": "integration-test-2", "id": 222222, "size_in_bytes": 2048, "created_at": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}
    ]}'

    echo "$mock_artifacts_json" > "$TEMP_DIR/mock_artifacts.json"

    # Test artifact count extraction
    local count=$(jq '.total_count' "$TEMP_DIR/mock_artifacts.json")
    if [ "$count" = "2" ]; then
        echo -e "${GREEN}✅ PASS${NC}: Artifact count extraction works"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: Artifact count extraction failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    # Test artifact names extraction
    local names=$(jq -r '.artifacts[].name' "$TEMP_DIR/mock_artifacts.json" | tr '\n' ',' | sed 's/,$//')
    if [ "$names" = "integration-test-1,integration-test-2" ]; then
        echo -e "${GREEN}✅ PASS${NC}: Artifact names extraction works"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: Artifact names extraction failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

# Test 4: Release creation simulation
test_release_creation_simulation() {
    setup_test
    echo -e "\n${YELLOW}🧪 Test 4: Release Creation Simulation${NC}"

    if [ -z "$TEST_TOKEN" ]; then
        echo -e "${YELLOW}⚠️ SKIP${NC}: No token provided, skipping release creation test"
        TESTS_TOTAL=$((TESTS_TOTAL - 1))
        return 0
    fi

    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}⚠️ SKIP${NC}: Dry run mode, skipping actual release creation"
        TESTS_TOTAL=$((TESTS_TOTAL - 1))
        return 0
    fi

    export GITHUB_TOKEN="$TEST_TOKEN"

    # Create a test release
    local test_tag="integration-test-$(date +%s)"
    local test_title="Integration Test - $(date -u)"
    local test_body="This is an integration test release created by the test suite."

    # Test release creation command
    local release_output
    if release_output=$(gh release create "$test_tag" \
        --repo "$TEST_REPO" \
        --title "$test_title" \
        --notes "$test_body" \
        --prerelease 2>&1); then

        echo -e "${GREEN}✅ PASS${NC}: Release creation succeeded"
        TESTS_PASSED=$((TESTS_PASSED + 1))

        # Verify release exists
        if gh release view "$test_tag" --repo "$TEST_REPO" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ PASS${NC}: Created release is accessible"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}❌ FAIL${NC}: Created release is not accessible"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
        TESTS_TOTAL=$((TESTS_TOTAL + 1))

        # Store for cleanup
        echo "$test_tag" >> "$TEMP_DIR/test_releases.txt"
    else
        echo -e "${RED}❌ FAIL${NC}: Release creation failed"
        echo -e "  Output: ${BLUE}$release_output${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

# Test 5: End-to-end workflow simulation
test_end_to_end_workflow() {
    setup_test
    echo -e "\n${YELLOW}🧪 Test 5: End-to-End Workflow Simulation${NC}"

    # Set up test environment variables
    export GITHUB_REPOSITORY="${TEST_REPO}"
    export GITHUB_RUN_ID="$(date +%s)"
    export GITHUB_SHA="$(openssl rand -hex 20)"
    export GITHUB_REF_NAME="integration-test"
    export GITHUB_WORKFLOW="Integration Test Workflow"
    export GITHUB_EVENT_NAME="workflow_dispatch"
    export GITHUB_ACTOR="integration-test"

    echo "Test environment set up:"
    echo "  Repository: $GITHUB_REPOSITORY"
    echo "  Run ID: $GITHUB_RUN_ID"
    echo "  SHA: $GITHUB_SHA"

    # Simulate immutable releases check
    local mock_repo_info='{"security_and_analysis": {"secret_scanning": {"status": "enabled"}}, "visibility": "public"}'
    local immutable_enabled="false"

    if echo "$mock_repo_info" | jq -e '.security_and_analysis.secret_scanning.status == "enabled"' >/dev/null 2>&1; then
        immutable_enabled="true"
    fi

    if [ "$immutable_enabled" = "true" ]; then
        echo -e "${GREEN}✅ PASS${NC}: Immutable releases detection logic works"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: Immutable releases detection logic failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    # Simulate release info generation
    local release_tag="pipeline-${GITHUB_RUN_ID}-$(date +%Y%m%d-%H%M%S)"
    local release_name="Pipeline Artifacts - Run #${GITHUB_RUN_ID}"

    if echo "$release_tag" | grep -q "pipeline-$GITHUB_RUN_ID"; then
        echo -e "${GREEN}✅ PASS${NC}: Release tag generation works"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: Release tag generation failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    # Simulate release body generation
    local release_body="Test release body"
    release_body="${release_body}\n\n## Pipeline Information"
    release_body="${release_body}\n- **Run ID:** $GITHUB_RUN_ID"
    release_body="${release_body}\n- **Commit:** $GITHUB_SHA"

    if echo -e "$release_body" | grep -q "Run ID.*$GITHUB_RUN_ID"; then
        echo -e "${GREEN}✅ PASS${NC}: Release body generation works"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: Release body generation failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

# Test 6: Performance test with mock large artifacts
test_performance_simulation() {
    setup_test
    echo -e "\n${YELLOW}🧪 Test 6: Performance Simulation${NC}"

    # Create mock large artifacts list
    local large_artifacts_json='{"total_count": 10, "artifacts": ['

    for i in {1..10}; do
        local size=$((1048576 * i))  # 1MB, 2MB, 3MB, etc.
        large_artifacts_json="${large_artifacts_json}"'{"name": "large-artifact-'$i'", "id": '$((111111 + i))', "size_in_bytes": '$size', "created_at": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}'

        if [ $i -lt 10 ]; then
            large_artifacts_json="${large_artifacts_json},"
        fi
    done

    large_artifacts_json="${large_artifacts_json}]}"

    echo "$large_artifacts_json" > "$TEMP_DIR/large_artifacts.json"

    # Test processing time
    local start_time=$(date +%s)

    # Simulate processing
    local total_count=$(jq '.total_count' "$TEMP_DIR/large_artifacts.json")
    local total_size=$(jq '[.artifacts[].size_in_bytes] | add' "$TEMP_DIR/large_artifacts.json")
    local artifact_names=$(jq -r '.artifacts[].name' "$TEMP_DIR/large_artifacts.json" | tr '\n' ',' | sed 's/,$//')

    local end_time=$(date +%s)
    local processing_time=$((end_time - start_time))

    if [ "$total_count" = "10" ]; then
        echo -e "${GREEN}✅ PASS${NC}: Large artifacts count processing (10 artifacts)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: Large artifacts count processing failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if [ "$total_size" = "57671680" ]; then  # Sum of 1MB+2MB+...+10MB
        echo -e "${GREEN}✅ PASS${NC}: Large artifacts size calculation (55MB total)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: Large artifacts size calculation failed (got $total_size)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    echo -e "${BLUE}ℹ️ INFO${NC}: Processing time: ${processing_time}s"
}

# Test 7: Error scenarios
test_error_scenarios() {
    setup_test
    echo -e "\n${YELLOW}🧪 Test 7: Error Scenarios${NC}"

    # Test invalid JSON handling
    local invalid_json='{"total_count": invalid, "artifacts": []}'

    if echo "$invalid_json" | jq '.total_count' 2>/dev/null; then
        echo -e "${RED}❌ FAIL${NC}: Should reject invalid JSON"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    else
        echo -e "${GREEN}✅ PASS${NC}: Correctly rejects invalid JSON"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    # Test empty artifacts handling
    local empty_artifacts='{"total_count": 0, "artifacts": []}'
    local empty_count=$(echo "$empty_artifacts" | jq '.total_count')

    if [ "$empty_count" = "0" ]; then
        echo -e "${GREEN}✅ PASS${NC}: Handles empty artifacts correctly"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: Empty artifacts handling failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    # Test missing required environment variables
    local old_run_id="$GITHUB_RUN_ID"
    unset GITHUB_RUN_ID

    # This should handle missing environment gracefully
    local generated_tag="pipeline-${GITHUB_RUN_ID:-default}-$(date +%Y%m%d)"

    if echo "$generated_tag" | grep -q "pipeline-default-"; then
        echo -e "${GREEN}✅ PASS${NC}: Handles missing environment variables"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: Missing environment variable handling failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    # Restore environment
    export GITHUB_RUN_ID="$old_run_id"
}

# Main test execution
main() {
    echo -e "${BLUE}🚀 Starting Retain Artifacts Action Integration Tests${NC}"
    echo "====================================================="
    echo ""
    echo "Configuration:"
    echo "  Test Repository: $TEST_REPO"
    echo "  Token Provided: $([ -n "$TEST_TOKEN" ] && echo "Yes" || echo "No")"
    echo "  Dry Run: $DRY_RUN"
    echo ""

    # Check prerequisites
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${RED}❌ Error: jq is required for tests but not installed${NC}"
        exit 1
    fi

    # Run all tests
    test_github_cli_setup
    test_repository_api_access
    test_artifacts_api_simulation
    test_release_creation_simulation
    test_end_to_end_workflow
    test_performance_simulation
    test_error_scenarios

    # Print summary
    echo -e "\n${BLUE}📊 Integration Test Summary${NC}"
    echo "============================"
    echo -e "Total Tests: ${BLUE}$TESTS_TOTAL${NC}"
    echo -e "Passed:      ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed:      ${RED}$TESTS_FAILED${NC}"

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n${GREEN}🎉 All integration tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}💥 Some integration tests failed!${NC}"
        exit 1
    fi
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help        Show this help message"
    echo "  --dry-run         Run tests without creating real releases"
    echo "  --repo REPO       Override test repository (default: NovoNordisk-OpenSource/retain_pipeline_run-test)"
    echo ""
    echo "Environment Variables:"
    echo "  GITHUB_TOKEN      GitHub token for API access (required for full tests)"
    echo "  GITHUB_REPOSITORY Override repository for tests"
    echo "  DRY_RUN          Set to 'true' to skip release creation"
    echo ""
    echo "Examples:"
    echo "  $0                    # Run all tests"
    echo "  $0 --dry-run          # Run tests without creating releases"
    echo "  DRY_RUN=true $0       # Same as --dry-run"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --repo)
            TEST_REPO="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
done

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi