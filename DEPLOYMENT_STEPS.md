# Deployment & Testing Steps

## 🎯 **Current Status: Ready for Deployment**

All local tests pass. Integration tests fail only because the repository doesn't exist yet.

## 🚀 **Complete Deployment & Testing Sequence**

### **Step 1: Authentication Setup**
```bash
# Clear environment variable and refresh auth with proper scopes
unset GITHUB_TOKEN
gh auth refresh -h github.com -s workflow,repo

# Verify authentication
gh auth status
```

### **Step 2: Create GitHub Repository**

**Option A: Via GitHub CLI**
```bash
cd /Users/sjrj/Platform/retain-artifacts

# Create repository
gh repo create NovoNordisk-OpenSource/retain_pipeline_run --public \
  --description "GitHub Action for retaining pipeline artifacts with immutable releases assessment" \
  --clone=false

# Initialize and push
git init
git add .
git commit -m "Initial retain-artifacts action

Complete GitHub Action for pipeline artifact retention:
- Immutable releases assessment based on GitHub documentation
- Comprehensive artifact collection and attachment
- Rich release metadata for compliance and audit
- Production-ready with full testing suite
- Follows nn-dma action patterns (similar to generate-verification-report)"

git remote add origin https://github.com/NovoNordisk-OpenSource/retain_pipeline_run.git
git branch -M main
git push -u origin main
```

**Option B: Via GitHub Web Interface**
1. Go to https://github.com/organizations/innersource-nn/repositories/new
2. Repository name: `retain-artifacts`
3. Description: "GitHub Action for retaining pipeline artifacts with immutable releases assessment"
4. Public repository
5. Create repository
6. Then push code:
```bash
cd /Users/sjrj/Platform/retain-artifacts
git init
git add .
git commit -m "Initial retain-artifacts action"
git remote add origin https://github.com/NovoNordisk-OpenSource/retain_pipeline_run.git
git branch -M main
git push -u origin main
```

### **Step 3: Test the Action**

```bash
# Test basic functionality
gh workflow run test-action.yml -f test_scenario=basic

# Monitor the run
gh run list --workflow=test-action.yml

# View detailed logs
gh run view --log

# Check created releases
gh release list
```

### **Step 4: Test QMS Integration**

```bash
cd /Users/sjrj/Platform/qms-reference

# Create test release branch
git checkout -b release/test-retain-artifacts-$(date +%Y%m%d-%H%M)
git push origin release/test-retain-artifacts-$(date +%Y%m%d-%H%M)

# Create PR to trigger QMS pipeline
gh pr create --title "Test retain-artifacts integration" \
  --body "Testing NovoNordisk-OpenSource/retain_pipeline_run@main in QMS pipeline

This PR tests the new retain-artifacts action integration:
- Artifact collection from QMS validation pipeline
- Release creation with compliance metadata
- Immutable releases assessment
- Full audit trail retention

The retain_pipeline_run job should execute and create a release with all pipeline artifacts."
```

### **Step 5: Verify Results**

After each test:

1. **Check Releases**: Go to repository → Releases tab
2. **Verify Artifacts**: Each release should have ZIP files attached
3. **Review Metadata**: Release notes should include pipeline info and immutable assessment
4. **Test Downloads**: Verify artifacts can be downloaded and contain expected content

## 🔍 **Expected Test Results**

### **Basic Test Success:**
- ✅ Release created: `Test Release - basic - {run_id}`
- ✅ 3 artifacts attached (test-basic-artifacts.zip, test-data-artifacts.zip, test-report-artifacts.zip)
- ✅ Assessment: `likely` or `supported` for nn-dma organization
- ✅ Rich release notes with pipeline metadata

### **QMS Test Success:**
- ✅ Release created: `QMS Release - release/test-retain-artifacts-{date}`
- ✅ All QMS pipeline artifacts attached
- ✅ Comprehensive validation summary in release notes
- ✅ Full compliance audit trail

## 🐛 **Troubleshooting**

### **Common Issues & Solutions:**

1. **"Resource not accessible by integration"**
   - **Fix**: Add `contents: write` to workflow permissions

2. **"No artifacts found"**
   - **Fix**: Ensure previous jobs use `actions/upload-artifact@v4`

3. **"Authentication required"**
   - **Fix**: Run `gh auth refresh -s workflow,repo`

4. **"Release already exists"**
   - **Fix**: Each test creates unique tags, but if needed: `gh release delete <tag>`

5. **"Action not found"**
   - **Fix**: Ensure repository exists and action.yml is in root

## ✅ **Success Criteria**

The deployment is successful when:
- ✅ Action repository exists and is accessible
- ✅ Test workflows run without errors
- ✅ Releases are created with artifacts attached
- ✅ QMS pipeline integration works smoothly
- ✅ Immutable releases assessment appears correctly
- ✅ All compliance requirements are met

## 🎯 **Ready to Deploy!**

All components are prepared. Start with **Step 1** above to begin the deployment process.