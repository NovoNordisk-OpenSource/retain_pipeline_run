# Testing Checklist for Retain Artifacts Action

## ✅ **Status: Ready for Testing**

### 📋 **Pre-Test Validation (Completed)**

- ✅ Action definition exists and is properly structured
- ✅ All required tools available (jq, curl, gh)
- ✅ Unit tests pass (19/19 tests)
- ✅ Local logic tests pass
- ✅ Documentation complete
- ✅ CI workflows configured

### 🚀 **Recommended Testing Sequence**

#### **Phase 1: Repository Setup**
```bash
cd /Users/sjrj/Platform/retain-artifacts

# 1. Initialize git repository
git init
git add .
git commit -m "Initial retain-artifacts action

- Complete GitHub Action for artifact retention
- Immutable releases assessment capability
- Comprehensive testing suite
- Production-ready documentation"

# 2. Create GitHub repository: innersource-nn/retain-artifacts
# 3. Push to GitHub
git remote add origin https://github.com/innersource-nn/retain-artifacts.git
git branch -M main
git push -u origin main
```

#### **Phase 2: Action Testing**
```bash
# 4. Run basic test workflow
gh workflow run test-action.yml -f test_scenario=basic

# 5. Monitor results
gh run list --workflow=test-action.yml
gh run view --log  # Get the latest run

# 6. Check created releases
gh release list
```

#### **Phase 3: QMS Integration**
```bash
# 7. Test in QMS pipeline
cd /Users/sjrj/Platform/qms-reference

# 8. Create release branch to trigger pipeline
git checkout -b release/test-retain-artifacts-$(date +%Y%m%d)
git push origin release/test-retain-artifacts-$(date +%Y%m%d)

# 9. Create PR to trigger full QMS pipeline
gh pr create --title "Test retain-artifacts integration" \
  --body "Testing the new innersource-nn/retain-artifacts@main action in QMS pipeline"
```

### 🧪 **Test Scenarios Available**

#### **In retain-artifacts repository:**
1. **Basic Test**: `gh workflow run test-action.yml -f test_scenario=basic`
   - Tests with 3 small artifacts
   - Validates core functionality

2. **Large Artifacts Test**: `gh workflow run test-action.yml -f test_scenario=large-artifacts`
   - Tests with larger files (5MB+)
   - Validates performance

3. **No Artifacts Test**: `gh workflow run test-action.yml -f test_scenario=no-artifacts`
   - Tests graceful handling of zero artifacts
   - Validates error handling

#### **In QMS pipeline:**
4. **Full QMS Test**: Release branch in qms-reference
   - Tests real-world integration
   - Validates compliance workflow

### 🔍 **What to Verify**

After each test run, check:

1. **✅ GitHub Release Created**
   - Go to repository → Releases
   - Verify release exists with correct name
   - Check release notes format and content

2. **✅ Artifacts Attached**
   - Verify all expected artifacts are attached as ZIP files
   - Download and verify artifact contents

3. **✅ Action Outputs**
   - Check workflow summary for action outputs
   - Verify `artifacts_count`, `release_url`, `immutable_releases_enabled`

4. **✅ Immutable Release Assessment**
   - Verify assessment appears in release notes
   - Check assessment level (`likely`, `supported`, `unsupported`)

### 🐛 **Troubleshooting**

If tests fail, check:

1. **Permissions**: Workflow has `contents: write`, `actions: read`, `metadata: read`
2. **Token**: `GITHUB_TOKEN` is available and has correct scopes
   - For integration tests that create releases, ensure GitHub CLI has "workflow" scope:
     ```bash
     gh auth refresh -h github.com -s workflow
     ```
3. **Platform Compatibility**:
   - On macOS, ensure date command compatibility (fixed in this branch)
   - For Dagger tests, ensure Docker is installed and in PATH
4. **Artifacts**: Previous jobs actually uploaded artifacts
5. **Logs**: Use `gh run view --log` for detailed error messages

### 📊 **Expected Results**

#### **Successful Test Run Should Show:**

```
✅ Release Creation Summary
- Release Tag: pipeline-123456789-20241128-143022
- Release Name: Test Release - basic - 123456789
- Release URL: https://github.com/innersource-nn/retain-artifacts/releases/tag/pipeline-123456789-20241128-143022
- Artifacts Count: 3
- Immutable Releases: likely

✅ Release created successfully with all pipeline artifacts retained!
```

#### **GitHub Release Should Contain:**
- Rich description with pipeline metadata
- All test artifacts as downloadable ZIP files
- Immutable releases assessment
- Links back to workflow run and commit

### 🎯 **Success Criteria**

The action is working correctly when:
- ✅ Releases are created automatically
- ✅ All artifacts are attached and downloadable
- ✅ Release metadata is comprehensive and accurate
- ✅ Immutable releases assessment is present
- ✅ No errors in workflow logs
- ✅ QMS pipeline integration works smoothly

### 🚀 **Ready to Test!**

All components are ready. Start with **Phase 1** above to begin testing!