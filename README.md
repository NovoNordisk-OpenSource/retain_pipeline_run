# Retain Artifacts Action

[![CI](https://github.com/NovoNordisk-OpenSource/retain_pipeline_run/actions/workflows/ci.yml/badge.svg)](https://github.com/NovoNordisk-OpenSource/retain_pipeline_run/actions/workflows/ci.yml)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/NovoNordisk-OpenSource/retain_pipeline_run)](https://github.com/NovoNordisk-OpenSource/retain_pipeline_run/releases/latest)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A GitHub Action that checks for immutable releases configuration and creates a release with all artifacts from the current pipeline run. Designed for compliance, audit trails, and artifact retention in regulated environments.

## 🚀 Features

- ✅ **Immutable Releases Assessment**: Evaluates repository capability for GitHub's immutable releases feature
- 📦 **Complete Artifact Collection**: Discovers and collects all artifacts from the current workflow run
- 🚀 **Automated Release Creation**: Creates comprehensive GitHub releases with rich metadata
- 📋 **Audit Trail**: Provides detailed pipeline information and validation summaries
- 🔒 **Compliance Ready**: Designed for QMS/regulatory compliance with full traceability
- 🛡️ **Error Resilience**: Robust error handling with graceful degradation
- ⚡ **Performance Optimized**: Efficient artifact processing and minimal API calls

## 📖 Quick Start

### QMS Pattern (Recommended)

For QMS compliance and regulatory environments:

```yaml
retain_pipeline_run:
    runs-on: ubuntu-latest
    needs: post_release_tag_commit
    if: always() && !failure() && !cancelled() && contains(github.ref_name, 'release')
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-tags: true  # Required for git tag detection
      - name: Retain Pipeline Artifacts
        uses: NovoNordisk-OpenSource/retain_pipeline_run@main
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
```


## 📝 Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `github_token` | GitHub token with repository and release permissions | ✅ | - |

## 📤 Outputs

| Output | Description | Example |
|--------|-------------|---------|
| `release_id` | ID of the created release | `123456789` |
| `release_url` | URL of the created release | `https://github.com/owner/repo/releases/tag/v1.0.0` |
| `release_tag` | Tag of the created release | `v1.0.0` |
| `immutable_releases_enabled` | Whether immutable releases are supported | `true` |
| `artifacts_count` | Number of artifacts attached | `5` |

## 🏗️ How It Works

### 1. 🔍 Immutable Releases Assessment

The action evaluates your repository's potential for GitHub's immutable releases feature:

**What Immutable Releases Provide:**
- Git tags cannot be moved or deleted after release publication
- Release assets cannot be modified or deleted
- Automatic generation of release attestations for cryptographic verification
- Protection against repository resurrection attacks

**Assessment Factors:**
- **Organization Context**: Checks if repository belongs to an organization
- **Security Features**: Evaluates GitHub Advanced Security indicators
- **Repository Configuration**: Considers visibility and access patterns

### 2. 📦 Artifact Discovery

Automatically finds and catalogs all artifacts:

```bash
# Discovers artifacts from current workflow run
GET /repos/{owner}/{repo}/actions/runs/{run_id}/artifacts

# Collects metadata for each artifact:
- Name and ID
- Size and creation timestamp
- Download URL and permissions
```

### 3. 🚀 Release Creation

Creates comprehensive releases with:

- **Pipeline Metadata**: Run ID, commit SHA, branch, workflow name
- **Execution Context**: Trigger event, actor, timestamp
- **Artifact Inventory**: Complete list with sizes and descriptions
- **Compliance Information**: Immutable release status
- **Rich Formatting**: Markdown formatting with links and emojis

### 4. 📎 Artifact Attachment

Downloads and attaches artifacts:

```bash
# For each artifact:
1. Download as ZIP archive
2. Attach to GitHub release
3. Verify successful upload
4. Report attachment status
```


## 📋 Requirements

### Permissions

Your workflow needs the following permissions:

```yaml
permissions:
  contents: write    # Create releases and attach artifacts
  actions: read      # Access workflow run artifacts
```

### Token Requirements

The `github_token` must have:
- `repo` scope (for private repositories)
- `public_repo` scope (for public repositories)
- Release creation permissions
- Artifact read access

## 🧪 Testing

### Running Tests Locally

```bash
# Clone the repository
git clone https://github.com/NovoNordisk-OpenSource/retain_pipeline_run.git
cd retain_pipeline_run

# Run unit tests
./test/unit/run_tests.sh

# Run integration tests
./test/integration/run_tests.sh

# Run local development tests
./test/local_test.sh
```

### GitHub Action Testing

The repository includes comprehensive test workflows:

```bash
# Run basic functionality tests
gh workflow run ci.yml

# Run end-to-end tests with real artifacts
gh workflow run e2e-test.yml

# Run performance tests with large artifacts
gh workflow run performance-test.yml
```

## 🛠️ Development

### Local Development Setup

```bash
# Prerequisites
- GitHub CLI (gh)
- jq for JSON processing
- Standard Unix tools (curl, tar, etc.)

# Environment variables for testing
export GITHUB_REPOSITORY="owner/repo"
export GITHUB_RUN_ID="123456789"
export GITHUB_TOKEN="your_token"
export GITHUB_SHA="commit_sha"
```

### Contributing

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/amazing-feature`
3. **Write** tests for your changes
4. **Commit** your changes: `git commit -m 'Add amazing feature'`
5. **Push** to the branch: `git push origin feature/amazing-feature`
6. **Open** a Pull Request

## 📊 Example Release Output

The action creates releases with comprehensive information:

```markdown
## 🎉 QMS Implementation Release

This release contains all artifacts from the QMS pipeline validation process.

### 📋 Pipeline Information
- **Run ID:** [123456789](https://github.com/owner/repo/actions/runs/123456789)
- **Commit:** [`abc123def`](https://github.com/owner/repo/commit/abc123def456)
- **Branch:** `release/v1.0.0`
- **Workflow:** `QMS Validation Pipeline`
- **Triggered by:** `push`
- **Actor:** @developer
- **Created:** 2024-11-27 14:30:22 UTC

### 📦 Artifacts (5)
This release contains **5** artifacts with a total size of **15.2 MiB**:
- **validation-results** (8.1 MiB)
- **test-reports** (4.2 MiB)
- **security-scans** (1.8 MiB)
- **performance-metrics** (892 KiB)
- **compliance-docs** (341 KiB)

> 💾 **Retention Period:** Indefinite (GitHub releases)

### 🔒 Immutable Release
⚡ **This release benefits from GitHub's immutable releases capability.**

Detected features: `secret_scanning_enabled,organization_repository`

---
*🤖 This release was created automatically by the [retain_pipeline_run](https://github.com/NovoNordisk-OpenSource/retain_pipeline_run) action*
```

## 🔒 Security Considerations

- **Token Security**: Use repository secrets for GitHub tokens
- **Artifact Access**: Respects repository and artifact permissions
- **Immutable Storage**: Leverages GitHub's release immutability when available
- **Audit Logging**: All actions are logged in GitHub's audit log

## 📚 Related Resources

- 📖 [GitHub Immutable Releases Documentation](https://docs.github.com/en/code-security/supply-chain-security/understanding-your-software-supply-chain/immutable-releases)
- 🔧 [GitHub Actions Artifacts Documentation](https://docs.github.com/en/actions/using-workflows/storing-workflow-data-as-artifacts)
- 🚀 [GitHub Releases API](https://docs.github.com/en/rest/releases/releases)
- 🏥 [QMS Implementation Guide](https://github.com/NovoNordisk-OpenSource/generate-verification-report)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Support

- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/NovoNordisk-OpenSource/retain_pipeline_run/issues)
- 💡 **Feature Requests**: [GitHub Discussions](https://github.com/NovoNordisk-OpenSource/retain_pipeline_run/discussions)

---
