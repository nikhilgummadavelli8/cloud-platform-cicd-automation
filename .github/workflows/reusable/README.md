# Reusable CI/CD Platform Workflow

**Location**: `.github/workflows/reusable/cicd-platform.yml`  
**Type**: Reusable GitHub Actions Workflow  
**Purpose**: Consumable CI/CD platform enforcing all architectural standards

---

## Overview

This is the **reusable CI/CD platform workflow** that application repositories can consume to get instant, enforced, production-grade pipelines. It implements all platform standards automatically:

✅ Branch validation and environment routing  
✅ Artifact immutability enforcement  
✅ Security scanning with CVE blocking  
✅ Promotion gates (staging → production)  
✅ OIDC authentication (zero static credentials)  
✅ Structured observability (metrics, logs, audit artifacts)

**Key principle**: Application teams get enforcement without implementation burden.

---

## Quick Start

### Minimal Example

Create `.github/workflows/cicd.yml` in your application repository:

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main, 'feature/**', 'bugfix/**']
  pull_request:
    branches: [main]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options: [development, staging, production]

jobs:
  cicd:
    uses: YOUR_ORG/cloud-platform-cicd-automation/.github/workflows/reusable/cicd-platform.yml@main
    with:
      service_name: "my-service"
      environment: "auto"
      artifact_type: "container-image"
```

**That's it.** Your service now has:
- Automated builds with immutable versioning
- Security scanning
- Multi-environment deployment
- Full observability
- All platform enforcement

---

## Required Inputs

### `service_name` (required)

**Type**: `string`  
**Description**: Name of the service being built

**Examples**:
- `api-gateway`
- `user-service`
- `payment-processor`
- `notification-worker`

**Constraints**:
- Must be provided (workflow will fail without it)
- Used for artifact naming: `{registry}/{service_name}:{tag}`
- Used for deployment identification

---

## Optional Inputs

### `environment` (optional)

**Type**: `string`  
**Default**: `"auto"`  
**Allowed values**: `auto`, `development`, `staging`, `production`

**Behavior**:
- `auto` **(recommended)**: Platform determines environment from branch
  - `feature/**` → development
  - `main` → staging
  - `release/**` → staging
  - `hotfix/**` → development + staging
- `development`: Force deploy to dev environment
- `staging`: Force deploy to staging environment
- `production`: Deploy to production (requires manual approval)

---

### `artifact_type` (optional)

**Type**: `string`  
**Default**: `"container-image"`  
**Allowed values**: `container-image`, `helm-chart`

**Description**: Type of artifact to build

---

### `deploy_enabled` (optional)

**Type**: `boolean`  
**Default**: `true`

**Description**: Enable or disable deployment stages

**Use case**: Set to `false` for build-only pipelines (e.g., library packages)

---

### `run_tests` (optional)

**Type**: `boolean`  
**Default**: `true`

**Description**: Run test stage

**Use case**: Temporarily disable for debugging (NOT recommended for production)

---

### `run_security_scan` (optional)

**Type**: `boolean`  
**Default**: `true`

**Description**: Run security scanning stage

**Use case**: Should almost always be `true` (required for production deployments)

---

## What the Platform Enforces Automatically

The platform enforces these standards **regardless of application team configuration**:

### ✅ 1. Branch Validation

**What**: Only allowed branch patterns can trigger pipelines  
**Allowed**: `main`, `feature/**`, `bugfix/**`, `hotfix/**`, `release/**`  
**Blocked**: Random branch names, personal branches  
**Cannot bypass**: Hardcoded in platform logic

---

### ✅ 2. Artifact Immutability

**What**: Mutable tags are blocked  
**Prohibited tags**: `latest`, `dev`, `staging`, `prod`, `main`, `master`  
**Required**: Commit SHA-based tags (e.g., `7a3f9c2`) or semantic versions  
**Cannot bypass**: Enforced in build stage

---

### ✅ 3. Promotion Gates

**What**: Production deployments require staging verification  
**Rules**:
- Feature branches → dev only
- Main/release branches → staging (automatic)
- Production → staging must pass first + manual approval required

**Cannot bypass**: Enforced in deployment logic

---

### ✅ 4. Security Scanning

**What**: Automatic vulnerability scanning with blocking  
**Blocks deployment on**: Critical CVEs  
**Warns on**: High severity vulnerabilities (production only)  
**Cannot bypass**: Scan stage is mandatory

---

### ✅ 5. OIDC Authentication

**What**: Zero static credentials for cloud access  
**Prohibited**: Service principal secrets, API keys, long-lived credentials  
**Required**: Federated identity (OIDC) for Azure authentication  
**Cannot bypass**: No repository secrets accepted for cloud auth

---

### ✅ 6. Observability

**What**: Structured logs, metrics, and audit artifacts  
**Emitted automatically**:
- Build metadata (artifact manifest)
- Verification results (health checks, smoke tests)
- Pipeline run summary (complete execution record)
- Timing metrics (per-stage duration)

**Cannot bypass**: Observability is built-in

---

## Application Team Responsibilities

While the platform enforces standards, application teams **must provide**:

### ❌ 1. Build Commands

Platform provides: Build stage structure, versioning, metadata  
**App team provides**: How to actually build the service

**Future Enhancement**: Platform will support build config files (e.g., `Dockerfile`, `buildspec.yml`)

---

### ❌ 2. Test Commands

Platform provides: Test stage execution, failure handling  
**App team provides**: How to run tests, expected coverage

**Future Enhancement**: Platform will detect test frameworks automatically

---

### ❌ 3. Deployment Manifests

Platform provides: Deployment orchestration, environment routing, OIDC auth  
**App team provides**: Kubernetes manifests, Helm charts, configuration

**Current State**: Placeholder deployment (no actual deployment logic yet)

---

### ❌ 4. Service-Specific Configuration

Platform provides: Foundation and enforcement  
**App team provides**:
- Environment variables
- Resource limits (CPU, memory)
- Scaling configuration
- Dependencies and service connections

---

## Example Use Cases

### Example 1: Standard Web API

```yaml
jobs:
  cicd:
    uses: YOUR_ORG/cloud-platform-cicd-automation/.github/workflows/reusable/cicd-platform.yml@main
    with:
      service_name: "user-api"
      artifact_type: "container-image"
      environment: "auto"  # Branch-based routing
      deploy_enabled: true
      run_tests: true
      run_security_scan: true
```

**Behavior**:
- Feature branches → build + test + scan + deploy to dev
- Main branch → build + test + scan + deploy to staging
- Manual workflow dispatch → production (with approval)

---

### Example 2: Production Hotfix

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [production]

jobs:
  hotfix:
    uses: YOUR_ORG/cloud-platform-cicd-automation/.github/workflows/reusable/cicd-platform.yml@main
    with:
      service_name: "payment-gateway"
      environment: "production"  # Explicit production deployment
```

**Behavior**:
- Requires `hotfix/**` branch
- Requires manual approval (GitHub environment protection)
- Validates staging verification passed
- Blocks if critical vulnerabilities exist

---

### Example 3: Library Package (No Deployment)

```yaml
jobs:
  build:
    uses: YOUR_ORG/cloud-platform-cicd-automation/.github/workflows/reusable/cicd-platform.yml@main
    with:
      service_name: "shared-utils"
      artifact_type: "helm-chart"
      deploy_enabled: false  # Build + test only, no deployment
```

**Behavior**:
- Runs build, test, scan stages
- Skips all deployment and verification stages
- Useful for shared libraries, Helm charts, SDKs

---

## Outputs

The workflow exposes these outputs for downstream jobs:

### `artifact_version`

**Type**: `string`  
**Description**: Version of the built artifact (e.g., `1.0.0-7a3f9c2`)  
**Use case**: Reference in deployment jobs, release notes

---

### `image_tag`

**Type**: `string`  
**Description**: Container image tag (immutable, commit-based) (e.g., `7a3f9c2`)  
**Use case**: Deploy specific version, rollback target

---

### `artifact_registry`

**Type**: `string`  
**Description**: Artifact registry URL (e.g., `myregistry.azurecr.io`)  
**Use case**: Pull images, configure deployment

---

## Troubleshooting

### Issue: "service_name is required"

**Cause**: `service_name` input not provided  
**Fix**: Add `service_name` to `with:` section

```yaml
with:
  service_name: "my-service"  # Add this
```

---

### Issue: "Invalid artifact_type"

**Cause**: Unsupported artifact type provided  
**Fix**: Use `container-image` or `helm-chart`

```yaml
with:
  artifact_type: "container-image"  # Must be one of these
```

---

### Issue: "Production deployment blocked"

**Causes**:
1. Branch not authorized for production (`main`, `release/**`, `hotfix/**` only)
2. Staging verification not passed
3. Critical vulnerabilities detected
4. Manual approval not granted

**Fix**: Check deployment gate messages in workflow logs

---

### Issue: "Deployment skipped"

**Cause**: Branch-environment mapping resulted in no deployment  
**Example**: Pull requests don't deploy anywhere (build + test only)  
**Expected behavior**: PRs validate code but don't deploy

---

## Migration Guide

### From Copy-Pasted Pipelines

**Before** (copied YAML, ~1400 lines):
```yaml
# .github/workflows/cicd.yml
name: CI/CD Pipeline
# ... 1400 lines of copied pipeline logic ...
```

**After** (reusable workflow, ~30 lines):
```yaml
# .github/workflows/cicd.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main, 'feature/**']

jobs:
  cicd:
    uses: YOUR_ORG/cloud-platform-cicd-automation/.github/workflows/reusable/cicd-platform.yml@main
    with:
      service_name: "my-service"
```

**Benefits**:
- ✅ 98% YAML reduction
- ✅ Platform updates flow automatically
- ✅ Enforcement cannot be bypassed
- ✅ Consistent across all services

---

## Advanced Customization

### Conditional Deployment

```yaml
jobs:
  cicd:
    uses: ./.github/workflows/reusable/cicd-platform.yml
    with:
      service_name: "my-service"
      deploy_enabled: ${{ github.event_name != 'pull_request' }}  # Deploy only on push
```

---

### Multi-Service Repository

```yaml
jobs:
  service-a:
    uses: ./.github/workflows/reusable/cicd-platform.yml
    with:
      service_name: "service-a"
  
  service-b:
    uses: ./.github/workflows/reusable/cicd-platform.yml
    with:
      service_name: "service-b"
```

---

## Versioning and Updates

### Recommended approach

```yaml
uses: YOUR_ORG/cloud-platform-cicd-automation/.github/workflows/reusable/cicd-platform.yml@main
```

**Pros**: Automatic platform updates  
**Cons**: Breaking changes could affect your pipeline

### Pinning to a specific version

```yaml
uses: YOUR_ORG/cloud-platform-cicd-automation/.github/workflows/reusable/cicd-platform.yml@v2.0.0
```

**Pros**: Stability, explicit upgrades  
**Cons**: Manual version bumps required, miss platform improvements

**Recommendation**: Use `@main` in non-critical environments, pin versions in production

---

## Related Documentation

- [Platform Architecture](../../docs/architecture/README.md)
- [Artifact Standards](../../docs/artifacts/README.md)
- [Promotion Model](../../docs/promotion/README.md)
- [Security (OIDC)](../../docs/security/README.md)
- [Observability](../../docs/observability/README.md)

---

## Support

**Issues**: Open an issue in the platform repository  
**Questions**: Contact the platform team via Slack #platform-ci-cd  
**Feature requests**: Submit via platform backlog board

---

## Changelog

### v2.0.0-reusable (Day 9)
- Initial reusable workflow release
- Introduced `workflow_call` interface
- Added input validation
- Made service_name parameterized
- Enforced all platform standards

### v1.0.0 (Day 8)
- Reference implementation (pipeline-skeleton.yml)
- Observability features added

