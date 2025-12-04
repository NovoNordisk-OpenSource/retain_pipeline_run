# Getting Started with Retain Artifacts Action

## Quick Setup

### 1. Add to Your Workflow

```yaml
name: My Pipeline
on:
  push:
    branches: [main]

permissions:
  contents: write
  actions: read

jobs:
  my_pipeline:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Your pipeline steps that create artifacts
      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: my-artifacts
          path: outputs/

  retain_artifacts:
    needs: my_pipeline
    runs-on: ubuntu-latest
    if: always() && !failure()
    steps:
      - name: Retain pipeline artifacts
        uses: innersource-nn/retain-artifacts@main
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
```

### 2. Verify Results

After your workflow runs:
1. Check the **Releases** section of your repository
2. Look for a new release with your artifacts attached
3. Review the release notes for pipeline information

## Configuration Examples

### Basic Configuration
```yaml
- uses: innersource-nn/retain-artifacts@main
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
```

### Custom Release Information
```yaml
- uses: innersource-nn/retain-artifacts@main
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    release_tag: "v1.0.0-${{ github.run_id }}"
    release_name: "Production Release v1.0.0"
    release_body: |
      ## Production Release

      This release contains validated production artifacts.

      ### Changes
      - Feature A implemented
      - Bug B fixed

      All validation checks passed.
```

### Compliance Configuration
```yaml
- uses: innersource-nn/retain-artifacts@main
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    release_name: "QMS Release - ${{ github.ref_name }}"
    artifact_retention_days: 2555  # 7 years for regulatory compliance
    release_body: |
      ## QMS Validation Release

      This release contains artifacts from our validated QMS pipeline.

      **Retention Period**: 7 years (regulatory requirement)
      **Validation Status**: All checks passed
```

## Common Patterns

### 1. Multi-Environment Pipeline
```yaml
jobs:
  deploy_staging:
    # ... staging deployment

  deploy_production:
    needs: deploy_staging
    # ... production deployment

  retain_artifacts:
    needs: [deploy_staging, deploy_production]
    if: always() && !failure()
    steps:
      - uses: innersource-nn/retain-artifacts@main
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          release_name: "Multi-Env Release - ${{ github.run_id }}"
```

### 2. Conditional Retention
```yaml
  retain_artifacts:
    if: contains(github.ref, 'release/') && !failure()
    steps:
      - uses: innersource-nn/retain-artifacts@main
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          prerelease: ${{ !contains(github.ref, 'main') }}
```

### 3. QMS/Regulated Environment
```yaml
  retain_validated_artifacts:
    needs: [validation, verification, approval]
    if: always() && !failure() && !cancelled()
    steps:
      - uses: innersource-nn/retain-artifacts@main
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          release_name: "Validated Release - ${{ github.ref_name }}"
          artifact_retention_days: 2555
          release_body: |
            ## Regulatory Compliance Release

            ### Validation Summary
            - ✅ Installation Verification (IV) completed
            - ✅ Performance Verification (PV) completed
            - ✅ All compliance checks passed

            **Retention**: 7 years (regulatory requirement)
            **Audit Trail**: Complete pipeline metadata included
```

## Required Permissions

Your workflow needs these permissions:

```yaml
permissions:
  contents: write    # Create releases and attach artifacts
  actions: read      # Access workflow run artifacts
```

## Troubleshooting

### Common Issues

1. **"Resource not accessible by integration"**
   - **Cause**: Missing `contents: write` permission
   - **Fix**: Add required permissions to your workflow

2. **"No artifacts found"**
   - **Cause**: Previous jobs didn't upload artifacts
   - **Fix**: Ensure `actions/upload-artifact@v4` is used in earlier jobs

3. **"Authentication required"**
   - **Cause**: Invalid or missing GitHub token
   - **Fix**: Use `${{ secrets.GITHUB_TOKEN }}` (automatically provided)

### Debug Mode

Enable detailed logging:

```yaml
env:
  ACTIONS_STEP_DEBUG: true
  RUNNER_DEBUG: 1
```

### Getting Help

- 📖 [Full Documentation](README.md)
- 🐛 [Report Issues](https://github.com/innersource-nn/retain-artifacts/issues)
- 💬 [Discussions](https://github.com/innersource-nn/retain-artifacts/discussions)

## Next Steps

1. **Test the Action**: Try it in a test repository first
2. **Customize**: Adapt the examples to your use case
3. **Monitor**: Check the created releases and verify artifacts
4. **Integrate**: Add to your production pipelines

## Best Practices

- **Test First**: Always test in a non-production environment
- **Clear Names**: Use descriptive release names and bodies
- **Retention Policy**: Set appropriate retention periods
- **Security**: Only use required permissions
- **Documentation**: Document your retention strategy