# Architecture Documentation

## Overview

The Retain Artifacts Action is designed as a composite GitHub Action that provides automated artifact retention through immutable releases. It follows the established patterns used by other nn-dma actions like `generate-verification-report`.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Retain Artifacts Action                   │
├─────────────────────────────────────────────────────────────┤
│  Input Validation & Environment Setup                        │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────┐  ┌─────────────────────────────────┐│
│  │ Immutable Releases  │  │     Artifact Discovery          ││
│  │    Detection        │  │                                 ││
│  │                     │  │ • Query GitHub Actions API     ││
│  │ • Check Security    │  │ • Collect artifact metadata    ││
│  │   Features          │  │ • Calculate total sizes        ││
│  │ • Analyze Repo      │  │ • Generate artifact inventory  ││
│  │   Visibility        │  │                                 ││
│  └─────────────────────┘  └─────────────────────────────────┘│
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────┐  ┌─────────────────────────────────┐│
│  │ Release Generation  │  │    Artifact Attachment          ││
│  │                     │  │                                 ││
│  │ • Generate Tags     │  │ • Download artifacts as ZIP    ││
│  │ • Create Metadata   │  │ • Upload to GitHub Release     ││
│  │ • Format Release    │  │ • Verify successful upload     ││
│  │   Body              │  │ • Handle upload failures       ││
│  └─────────────────────┘  └─────────────────────────────────┘│
├─────────────────────────────────────────────────────────────┤
│  Output Generation & Summary                                 │
└─────────────────────────────────────────────────────────────┘
```

## Component Architecture

### 1. Input Processing Layer

**Purpose**: Validates and processes all input parameters.

**Components**:
- Input validation and sanitization
- Environment variable setup
- Default value assignment

**Key Features**:
- Flexible parameter handling
- Graceful defaults for optional inputs
- Environment variable override support

### 2. Repository Analysis Layer

**Purpose**: Analyzes repository configuration and capabilities.

**Components**:
- **Immutable Releases Detector**: Checks repository security features
- **Repository Metadata Collector**: Gathers repository information

**Detection Logic**:
```bash
# Security Features Check
if secret_scanning_enabled || push_protection_enabled; then
    immutable_capable = true
fi

# Repository Type Check
if repository.visibility == "public"; then
    immutable_capable = true
fi

# Organization Check
if repository.owner.type == "Organization"; then
    immutable_capable = true
fi
```

### 3. Artifact Management Layer

**Purpose**: Discovers, processes, and manages pipeline artifacts.

**Components**:
- **Artifact Discovery Engine**: Queries GitHub Actions API
- **Metadata Processor**: Extracts and formats artifact information
- **Size Calculator**: Computes total sizes and formats for human readability

**API Integration**:
```
GET /repos/{owner}/{repo}/actions/runs/{run_id}/artifacts
├── Extract artifact metadata
├── Calculate total sizes
├── Format human-readable sizes
└── Generate artifact inventory
```

### 4. Release Management Layer

**Purpose**: Creates and manages GitHub releases with rich metadata.

**Components**:
- **Release Generator**: Creates releases with comprehensive metadata
- **Tag Manager**: Generates and manages release tags
- **Content Formatter**: Creates rich Markdown content

**Release Structure**:
```markdown
## Pipeline Information
- Run ID, commit, branch, workflow
- Trigger event, actor, timestamp

## Artifacts (N)
- Complete inventory with sizes
- Human-readable format
- Direct download links

## Immutable Release Status
- Capability detection results
- Security feature analysis
```

### 5. Artifact Attachment Layer

**Purpose**: Downloads and attaches artifacts to releases.

**Components**:
- **Download Manager**: Handles artifact ZIP downloads
- **Upload Controller**: Manages release asset uploads
- **Error Handler**: Provides resilient error handling

**Process Flow**:
```
For each artifact:
  1. Download as ZIP from GitHub API
  2. Upload to GitHub Release
  3. Verify successful upload
  4. Handle failures gracefully
  5. Report status
```

## Data Flow

### 1. Input Processing Flow

```
User Inputs → Validation → Default Assignment → Environment Setup
```

### 2. Repository Analysis Flow

```
Repository → API Query → Security Analysis → Capability Detection → Results
```

### 3. Artifact Processing Flow

```
Run ID → API Query → Metadata Extraction → Size Calculation → Inventory Generation
```

### 4. Release Creation Flow

```
Metadata → Tag Generation → Content Creation → Release API → Verification
```

### 5. Artifact Attachment Flow

```
Artifact List → Download Loop → Upload Loop → Status Reporting → Summary
```

## API Integration Points

### GitHub REST API Endpoints

| Endpoint | Purpose | Authentication |
|----------|---------|----------------|
| `GET /repos/{owner}/{repo}` | Repository information | Token |
| `GET /repos/{owner}/{repo}/actions/runs/{run_id}/artifacts` | Artifact discovery | Token |
| `GET /repos/{owner}/{repo}/actions/artifacts/{artifact_id}/zip` | Artifact download | Token |
| `POST /repos/{owner}/{repo}/releases` | Release creation | Token |
| `POST /repos/{owner}/{repo}/releases/{release_id}/assets` | Asset upload | Token |

### GitHub CLI Integration

The action uses GitHub CLI (`gh`) for simplified API interactions:

```bash
# Repository queries
gh api repos/$REPO

# Release creation
gh release create $TAG --title "$TITLE" --notes "$BODY"

# Asset upload
gh release upload $TAG $FILE
```

## Error Handling Strategy

### 1. Graceful Degradation

- **Missing Artifacts**: Continue with empty release
- **Download Failures**: Skip failed artifacts, report status
- **API Failures**: Retry with exponential backoff

### 2. Error Categories

| Category | Handling | Recovery |
|----------|----------|----------|
| **Input Errors** | Validation, clear messages | User correction required |
| **API Errors** | Retry logic, rate limiting | Automatic retry |
| **Network Errors** | Timeout handling | Exponential backoff |
| **Permission Errors** | Clear diagnostics | Configuration fix |

### 3. Error Reporting

- Detailed error messages with context
- Actionable suggestions for resolution
- Comprehensive logging for debugging

## Security Considerations

### 1. Token Security

- **Minimal Permissions**: Only required scopes
- **Secure Storage**: GitHub Secrets integration
- **Audit Logging**: All API calls logged

### 2. Data Protection

- **Temporary Storage**: All downloads in temp directories
- **Cleanup**: Automatic cleanup on completion/failure
- **Access Control**: Respects repository permissions

### 3. Input Validation

- **Parameter Sanitization**: All inputs validated
- **Injection Prevention**: Proper escaping and quoting
- **Size Limits**: Protection against resource exhaustion

## Performance Optimization

### 1. Efficient API Usage

- **Batch Operations**: Minimize API calls
- **Parallel Processing**: Concurrent artifact handling where possible
- **Caching**: Avoid redundant API requests

### 2. Resource Management

- **Memory Efficiency**: Stream large files, avoid loading into memory
- **Disk Management**: Temporary file cleanup
- **Network Optimization**: Connection reuse, compression

### 3. Scalability Considerations

- **Large Artifact Sets**: Efficient processing of 100+ artifacts
- **Size Limits**: Graceful handling of GB-sized artifacts
- **Rate Limiting**: Respect GitHub API limits

## Compliance and Audit Features

### 1. Audit Trail

- Complete pipeline metadata capture
- Immutable release creation
- Comprehensive logging

### 2. Regulatory Compliance

- **Traceability**: Full artifact lineage
- **Retention**: Configurable retention periods
- **Integrity**: Checksums and verification

### 3. Reporting

- **Summary Reports**: Comprehensive action summaries
- **Status Tracking**: Detailed success/failure reporting
- **Metrics**: Performance and usage analytics

## Extensibility

### 1. Configuration Options

- Flexible input parameters
- Environment variable overrides
- Runtime configuration

### 2. Integration Points

- **Pre/Post Hooks**: Extension points for custom logic
- **Output Formats**: Structured outputs for downstream processing
- **Notification**: Integration with external systems

### 3. Customization

- **Templates**: Customizable release content
- **Filtering**: Selective artifact inclusion
- **Transformation**: Custom metadata processing