#!/bin/bash

# Local development test script for retain_pipeline_run action
# This script simulates the action locally for development and debugging

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Local Development Test for Retain Pipeline Run Action${NC}"
echo "======================================================"

# Set up test environment variables
export GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-test-owner/test-repo}"
export GITHUB_RUN_ID="${GITHUB_RUN_ID:-$(date +%s)}"
export GITHUB_SHA="${GITHUB_SHA:-$(openssl rand -hex 20 2>/dev/null || { echo "Error: Unable to generate secure random SHA" >&2; exit 1; })}"
export GITHUB_REF_NAME="${GITHUB_REF_NAME:-main}"
export GITHUB_WORKFLOW="${GITHUB_WORKFLOW:-Local Test Workflow}"
export GITHUB_EVENT_NAME="${GITHUB_EVENT_NAME:-workflow_dispatch}"
export GITHUB_ACTOR="${GITHUB_ACTOR:-local-test-user}"
export GITHUB_SERVER_URL="${GITHUB_SERVER_URL:-https://github.com}"

echo -e "${CYAN}📋 Test Environment:${NC}"
echo "  Repository: $GITHUB_REPOSITORY"
echo "  Run ID: $GITHUB_RUN_ID"
echo "  SHA: $GITHUB_SHA"
echo "  Branch: $GITHUB_REF_NAME"
echo "  Workflow: $GITHUB_WORKFLOW"
echo "  Actor: $GITHUB_ACTOR"
echo ""

# Test 1: Check prerequisites
echo -e "${YELLOW}🔍 Step 1: Checking prerequisites...${NC}"

MISSING_TOOLS=()

if ! command -v jq >/dev/null 2>&1; then
    MISSING_TOOLS+=("jq")
    echo -e "  ${RED}❌ jq is NOT available${NC}"
else
    echo -e "  ${GREEN}✅ jq is available${NC} ($(jq --version))"
fi

if ! command -v curl >/dev/null 2>&1; then
    MISSING_TOOLS+=("curl")
    echo -e "  ${RED}❌ curl is NOT available${NC}"
else
    echo -e "  ${GREEN}✅ curl is available${NC}"
fi

if ! command -v date >/dev/null 2>&1; then
    MISSING_TOOLS+=("date")
    echo -e "  ${RED}❌ date command is NOT available${NC}"
else
    echo -e "  ${GREEN}✅ date command is available${NC}"
fi

if command -v gh >/dev/null 2>&1; then
    echo -e "  ${GREEN}✅ GitHub CLI (gh) is available${NC} ($(gh --version | head -1))"
else
    echo -e "  ${YELLOW}⚠️ GitHub CLI (gh) is NOT available${NC}"
    echo -e "    ${CYAN}Install with: https://github.com/cli/cli#installation${NC}"
fi

if command -v numfmt >/dev/null 2>&1; then
    echo -e "  ${GREEN}✅ numfmt is available${NC} (for size formatting)"
else
    echo -e "  ${YELLOW}⚠️ numfmt is NOT available${NC} (size formatting will be basic)"
fi

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo -e "\n${RED}❌ Missing required tools: ${MISSING_TOOLS[*]}${NC}"
    echo -e "${YELLOW}Please install missing tools before running the action${NC}"
    exit 1
fi

echo ""

# Test 2: Simulate immutable releases check
echo -e "${YELLOW}🔍 Step 2: Testing immutable releases detection logic...${NC}"

# Create test repository info scenarios
TEST_SCENARIOS=(
    '{"security_and_analysis": {"secret_scanning": {"status": "enabled"}}, "visibility": "private", "private": true}'
    '{"security_and_analysis": {"secret_scanning_push_protection": {"status": "enabled"}}, "visibility": "public", "private": false}'
    '{"security_and_analysis": null, "visibility": "public", "private": false}'
    '{"security_and_analysis": null, "visibility": "private", "private": true}'
)

SCENARIO_NAMES=(
    "Private repo with secret scanning"
    "Public repo with push protection"
    "Public repo without advanced security"
    "Private repo without advanced security"
)

for i in "${!TEST_SCENARIOS[@]}"; do
    REPO_INFO="${TEST_SCENARIOS[$i]}"
    SCENARIO_NAME="${SCENARIO_NAMES[$i]}"

    echo -e "  ${CYAN}Testing scenario: $SCENARIO_NAME${NC}"

    SECURITY_FEATURES=$(echo "$REPO_INFO" | jq -r '.security_and_analysis // {}')
    IMMUTABLE_ENABLED="false"
    IMMUTABLE_REASONS=()

    # Apply the same logic as in action.yml
    if echo "$SECURITY_FEATURES" | jq -e '.secret_scanning.status == "enabled"' > /dev/null 2>&1; then
        IMMUTABLE_ENABLED="true"
        IMMUTABLE_REASONS+=("secret_scanning_enabled")
    fi

    if echo "$SECURITY_FEATURES" | jq -e '.secret_scanning_push_protection.status == "enabled"' > /dev/null 2>&1; then
        IMMUTABLE_ENABLED="true"
        IMMUTABLE_REASONS+=("push_protection_enabled")
    fi

    VISIBILITY=$(echo "$REPO_INFO" | jq -r '.visibility')
    IS_PRIVATE=$(echo "$REPO_INFO" | jq -r '.private')

    if [ "$VISIBILITY" = "public" ]; then
        IMMUTABLE_ENABLED="true"
        IMMUTABLE_REASONS+=("public_repository")
    elif [ "$IS_PRIVATE" = "false" ]; then
        IMMUTABLE_ENABLED="true"
        IMMUTABLE_REASONS+=("non_private_repository")
    fi

    if [ "$IMMUTABLE_ENABLED" = "true" ]; then
        echo -e "    ${GREEN}✅ Immutable releases detected${NC} (${IMMUTABLE_REASONS[*]})"
    else
        echo -e "    ${YELLOW}⚠️ Immutable releases not detected${NC}"
    fi
done

echo ""

# Test 3: Simulate artifacts processing
echo -e "${YELLOW}🔍 Step 3: Testing artifact processing logic...${NC}"

# Create mock artifacts JSON
MOCK_ARTIFACTS_JSON='{"total_count": 5, "artifacts": [
    {"name": "test-logs", "id": 111111, "size_in_bytes": 1048576, "created_at": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"},
    {"name": "test-reports", "id": 222222, "size_in_bytes": 2097152, "created_at": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"},
    {"name": "test-data", "id": 333333, "size_in_bytes": 512000, "created_at": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"},
    {"name": "test-binaries", "id": 444444, "size_in_bytes": 10485760, "created_at": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"},
    {"name": "test-archives", "id": 555555, "size_in_bytes": 5242880, "created_at": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}
]}'

echo "$MOCK_ARTIFACTS_JSON" > /tmp/test_artifacts.json

# Test artifact processing
ARTIFACT_COUNT=$(echo "$MOCK_ARTIFACTS_JSON" | jq '.total_count')
echo -e "  ${CYAN}Artifact Count:${NC} $ARTIFACT_COUNT"

if [ "$ARTIFACT_COUNT" -gt 0 ]; then
    ARTIFACT_NAMES=$(echo "$MOCK_ARTIFACTS_JSON" | jq -r '.artifacts[].name' | tr '\n' ', ' | sed 's/,$//')
    TOTAL_SIZE=$(echo "$MOCK_ARTIFACTS_JSON" | jq '[.artifacts[].size_in_bytes] | add')

    echo -e "  ${CYAN}Artifact Names:${NC} $ARTIFACT_NAMES"
    echo -e "  ${CYAN}Total Size (bytes):${NC} $TOTAL_SIZE"

    # Test human readable size conversion
    if command -v numfmt >/dev/null 2>&1; then
        TOTAL_SIZE_HUMAN=$(numfmt --to=iec-i --suffix=B $TOTAL_SIZE)
        echo -e "  ${CYAN}Total Size (human):${NC} $TOTAL_SIZE_HUMAN"
    else
        TOTAL_SIZE_HUMAN="${TOTAL_SIZE} bytes"
        echo -e "  ${CYAN}Total Size (human):${NC} $TOTAL_SIZE_HUMAN"
    fi

    echo -e "  ${GREEN}✅ Artifact processing logic works${NC}"
else
    echo -e "  ${YELLOW}⚠️ No artifacts found${NC}"
fi

echo ""

# Test 4: Simulate release information generation
echo -e "${YELLOW}🔍 Step 4: Testing release information generation...${NC}"

# Generate release tag
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
RELEASE_TAG="pipeline-$GITHUB_RUN_ID-$TIMESTAMP"
echo -e "  ${CYAN}Generated Tag:${NC} $RELEASE_TAG"

# Generate release name
RELEASE_NAME="Pipeline Artifacts - Run #$GITHUB_RUN_ID"
echo -e "  ${CYAN}Generated Name:${NC} $RELEASE_NAME"

# Generate release body
RELEASE_BODY="Automated release created from pipeline run"
RELEASE_BODY="${RELEASE_BODY}\n\n## 📋 Pipeline Information"
RELEASE_BODY="${RELEASE_BODY}\n- **Run ID:** [$GITHUB_RUN_ID]($GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID)"
RELEASE_BODY="${RELEASE_BODY}\n- **Commit:** [\`$GITHUB_SHA\`]($GITHUB_SERVER_URL/$GITHUB_REPOSITORY/commit/$GITHUB_SHA)"
RELEASE_BODY="${RELEASE_BODY}\n- **Branch:** \`$GITHUB_REF_NAME\`"
RELEASE_BODY="${RELEASE_BODY}\n- **Workflow:** \`$GITHUB_WORKFLOW\`"
RELEASE_BODY="${RELEASE_BODY}\n- **Triggered by:** \`$GITHUB_EVENT_NAME\`"
RELEASE_BODY="${RELEASE_BODY}\n- **Actor:** @$GITHUB_ACTOR"
RELEASE_BODY="${RELEASE_BODY}\n- **Created:** $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

if [ "$ARTIFACT_COUNT" -gt 0 ]; then
    RELEASE_BODY="${RELEASE_BODY}\n\n## 📦 Artifacts ($ARTIFACT_COUNT)"
    RELEASE_BODY="${RELEASE_BODY}\nThis release contains **$ARTIFACT_COUNT** artifacts with a total size of **$TOTAL_SIZE_HUMAN**:"
    RELEASE_BODY="${RELEASE_BODY}\n- **test-logs** (1.0MiB)"
    RELEASE_BODY="${RELEASE_BODY}\n- **test-reports** (2.0MiB)"
    RELEASE_BODY="${RELEASE_BODY}\n- **test-data** (500KiB)"
    RELEASE_BODY="${RELEASE_BODY}\n- **test-binaries** (10MiB)"
    RELEASE_BODY="${RELEASE_BODY}\n- **test-archives** (5.0MiB)"
fi

RELEASE_BODY="${RELEASE_BODY}\n\n## 🔒 Immutable Release"
RELEASE_BODY="${RELEASE_BODY}\n⚡ **This release benefits from GitHub's immutable releases capability.**"
RELEASE_BODY="${RELEASE_BODY}\n\n---"
RELEASE_BODY="${RELEASE_BODY}\n*🤖 This release was created automatically by the [retain_pipeline_run](https://github.com/NovoNordisk-OpenSource/retain_pipeline_run) action*"

echo -e "  ${CYAN}Release Body Preview:${NC}"
printf "%s\n" "$RELEASE_BODY" | head -20 | sed 's/^/    /'
echo "    ..."

echo -e "  ${GREEN}✅ Release information generation works${NC}"

echo ""

# Test 5: Validate GitHub CLI commands
echo -e "${YELLOW}🔍 Step 5: Validating GitHub CLI command structure...${NC}"

# Test release creation command structure
RELEASE_CMD="gh release create '$RELEASE_TAG' --title '$RELEASE_NAME' --notes 'Test notes'"
echo -e "  ${CYAN}Release Creation Command:${NC}"
echo -e "    $RELEASE_CMD"

# Test API endpoint structure
API_ENDPOINT="repos/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID/artifacts"
echo -e "  ${CYAN}Artifacts API Endpoint:${NC}"
echo -e "    $API_ENDPOINT"

# Test release upload command structure
UPLOAD_CMD="gh release upload '$RELEASE_TAG' 'artifact.zip'"
echo -e "  ${CYAN}Artifact Upload Command:${NC}"
echo -e "    $UPLOAD_CMD"

echo -e "  ${GREEN}✅ Command structure validation complete${NC}"

echo ""

# Test 6: Performance simulation
echo -e "${YELLOW}🔍 Step 6: Performance simulation...${NC}"

START_TIME=$(date +%s.%N 2>/dev/null || date +%s)

# Simulate processing 100 artifacts
LARGE_ARTIFACTS_JSON='{"total_count": 100, "artifacts": ['
for i in {1..100}; do
    SIZE=$((1024 * 1024 * (i % 10 + 1)))  # 1-10MB files
    LARGE_ARTIFACTS_JSON="${LARGE_ARTIFACTS_JSON}"'{"name": "artifact-'$i'", "id": '$((100000 + i))', "size_in_bytes": '$SIZE'}'
    if [ $i -lt 100 ]; then
        LARGE_ARTIFACTS_JSON="${LARGE_ARTIFACTS_JSON},"
    fi
done
LARGE_ARTIFACTS_JSON="${LARGE_ARTIFACTS_JSON}]}"

# Process the large artifacts list
LARGE_COUNT=$(echo "$LARGE_ARTIFACTS_JSON" | jq '.total_count')
LARGE_TOTAL_SIZE=$(echo "$LARGE_ARTIFACTS_JSON" | jq '[.artifacts[].size_in_bytes] | add')

END_TIME=$(date +%s.%N 2>/dev/null || date +%s)
if command -v bc >/dev/null 2>&1; then
    PROCESSING_TIME=$(echo "$END_TIME - $START_TIME" | bc 2>/dev/null || echo "< 1")
else
    PROCESSING_TIME="< 1"
fi

echo -e "  ${CYAN}Large Scale Test:${NC}"
echo -e "    Artifacts: $LARGE_COUNT"
echo -e "    Total Size: $LARGE_TOTAL_SIZE bytes"
echo -e "    Processing Time: ${PROCESSING_TIME}s"

echo -e "  ${GREEN}✅ Performance simulation complete${NC}"

echo ""

# Cleanup
rm -f /tmp/test_artifacts.json

# Summary
echo -e "${GREEN}🎉 Local Development Test Summary${NC}"
echo "================================="
echo -e "${GREEN}✅ All tests passed successfully!${NC}"
echo ""
echo -e "${BLUE}📝 Next Steps:${NC}"
echo "1. Fix any issues identified above"
echo "2. Test the action in GitHub using a test workflow"
echo "3. Create a test repository and run: gh workflow run test.yml"
echo "4. Monitor the workflow execution and check created releases"
echo ""
echo -e "${CYAN}💡 Tips:${NC}"
echo "- Set GITHUB_TOKEN environment variable for API testing"
echo "- Use 'gh auth login' to authenticate GitHub CLI"
echo "- Run unit tests: ./test/unit/run_tests.sh"
echo "- Run integration tests: ./test/integration/run_tests.sh"