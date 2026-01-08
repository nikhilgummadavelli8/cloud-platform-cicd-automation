# Pipeline Structure

This document defines the **mandatory structure** for all CI/CD pipelines.

## Mandatory Pipeline Stages

All pipelines must implement the following stages in order:

### 1. Build
**Purpose**: Compile source code and generate deployable artifacts.

**Requirements**:
- Must execute before all other stages
- Must produce versioned, immutable artifacts
- Must generate artifact metadata (commit SHA, build timestamp, semantic version)
- Must fail if compilation or dependency resolution fails

**Blocking**: Yes. Pipeline cannot proceed if build fails.

**Skippable**: No. Build stage is always required.

---

### 2. Test
**Purpose**: Validate application correctness through automated tests.

**Requirements**:
- Must execute after Build stage completes
- Must run unit tests (minimum coverage threshold defined by application team)
- May run integration tests if applicable
- Must produce test results in standardized format (JUnit XML or equivalent)

**Blocking**: Yes. Pipeline cannot proceed if tests fail.

**Skippable**: No. Test stage is always required.

**Parallelization**: Test suites may run in parallel within the Test stage.

---

### 3. Scan
**Purpose**: Identify security vulnerabilities and compliance violations before deployment.

**Requirements**:
- Must execute after Build stage completes (can run in parallel with Test stage)
- Must scan container images for vulnerabilities (CVEs)
- Must scan dependencies for known vulnerabilities
- Must perform static application security testing (SAST)
- Must generate Software Bill of Materials (SBOM)
- Must fail if critical vulnerabilities are detected

**Blocking**: Yes. Pipeline cannot proceed if critical vulnerabilities are found.

**Skippable**: No. Scan stage is always required.

**Parallelization**: Vulnerability scanning and SAST can run in parallel.

---

### 4. Deploy
**Purpose**: Deploy artifacts to target environment.

**Requirements**:
- Must execute after Build, Test, and Scan stages complete successfully
- Must use declarative deployment tools (Terraform, Helm)
- Must be idempotent (re-running deploy produces identical state)
- Must support rollback to previous version on failure
- Must execute per-environment (dev, test, prod are separate deploy stages)

**Blocking**: Yes. Deployment failure must halt pipeline.

**Skippable**: No for lower environments (dev, test). Conditional for production (requires approval gate).

**Environment-Specific**: Deploy stage is replicated per environment with different configurations.

---

### 5. Verify
**Purpose**: Validate deployment success through post-deployment checks.

**Requirements**:
- Must execute immediately after Deploy stage completes
- Must validate application health (HTTP health checks, readiness probes)
- Must execute smoke tests specific to deployed environment
- Must trigger rollback if verification fails
- Must validate infrastructure state matches expected configuration

**Blocking**: Yes. Verification failure triggers automatic rollback.

**Skippable**: No. Verify stage is always required after deployment.

**Timeout**: Verification must complete within 5 minutes or trigger rollback.

---

## Stage Ordering Rules

### Sequential Dependencies
The following stages **must** execute sequentially:

```
Build → Deploy → Verify
```

- **Deploy** cannot start until **Build** completes
- **Verify** cannot start until **Deploy** completes

### Parallel Execution Allowed
The following stages **may** execute in parallel:

```
Build → Test
     ↘ Scan
```

- **Test** and **Scan** can run concurrently after **Build** completes
- Both **Test** and **Scan** must complete before **Deploy** can start

### Complete Pipeline Flow

```
┌───────┐
│ Build │
└───┬───┘
    │
    ├──────────────────┐
    │                  │
    ▼                  ▼
┌───────┐          ┌──────┐
│ Test  │          │ Scan │
└───┬───┘          └───┬──┘
    │                  │
    └────────┬─────────┘
             │
             ▼
        ┌────────┐
        │ Deploy │
        └───┬────┘
            │
            ▼
        ┌────────┐
        │ Verify │
        └────────┘
```

## Blocking Stage Definitions

### Always Blocking
These stages **always** block pipeline progression on failure:

- **Build**: Artifacts cannot be deployed if they don't exist
- **Test**: Failing tests indicate broken functionality
- **Scan**: Critical vulnerabilities must not reach production
- **Deploy**: Deployment failures indicate infrastructure or configuration issues
- **Verify**: Failed verification triggers rollback and halts promotion

### Never Optional
All five stages are **mandatory**. Pipelines that omit any stage are non-conformant.

## Stages That Cannot Be Skipped

**No stage can be skipped under any circumstances.**

Common anti-patterns that are **explicitly prohibited**:

- ❌ Skipping tests "because it's just a hotfix"
- ❌ Skipping scans "because we're behind schedule"
- ❌ Skipping verification "because we tested locally"
- ❌ Fast-tracking to production by bypassing lower environments

## Environment-Specific Stage Behavior

### Development Environment
- All stages execute on every commit to feature branches
- Deployment is automatic after all stages pass
- Verification failures log warnings but do not block (dev only)

### Test/Staging Environment
- All stages execute on pull requests and merges to main
- Deployment is automatic after all stages pass
- Verification failures block promotion to production

### Production Environment
- All stages execute, **plus** manual approval gate before Deploy
- Deployment requires explicit approval (cannot be automatic)
- Verification failures trigger immediate automatic rollback
- Failed production deployments require incident review before retry

## Stage Inputs and Outputs

### Build Stage
- **Input**: Source code, dependency manifests
- **Output**: Container image, versioned artifact, build metadata

### Test Stage
- **Input**: Build artifacts
- **Output**: Test results (JUnit XML), coverage report

### Scan Stage
- **Input**: Container image, dependency tree
- **Output**: Vulnerability report, SBOM, scan status (pass/fail)

### Deploy Stage
- **Input**: Container image, deployment manifests, environment configuration
- **Output**: Deployment status, resource identifiers (URLs, service endpoints)

### Verify Stage
- **Input**: Deployment outputs (URLs, endpoints)
- **Output**: Health check results, smoke test status

## Additional Stages (Optional)

Applications may add supplementary stages if they do not interfere with mandatory stages:

### Allowed Optional Stages
- **Performance Testing**: After Verify in test/staging environments
- **Security Scanning (DAST)**: After deployment to non-production environments
- **Chaos Engineering**: In dedicated testing environments only

### Prohibited Stages
- Manual steps that require human intervention (except production approval)
- Interactive debugging or live troubleshooting
- Stages that modify production without going through Deploy stage

## Conformance Validation

Platform-provided reusable workflows enforce this structure.

Pipelines that deviate from mandatory stage structure will:
- Fail schema validation
- Be rejected by required status checks
- Not be eligible for production certification

## Exception Process

Exceptions to pipeline structure require:

1. Written justification documenting why standard structure cannot apply
2. Platform engineering review
3. Security team approval for any changes affecting Scan or Deploy stages
4. Expiration date (exceptions are time-limited, not permanent)

**Exceptions are rare and must be re-justified annually.**
