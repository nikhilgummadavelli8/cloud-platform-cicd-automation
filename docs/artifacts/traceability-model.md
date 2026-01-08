# Traceability Model

This document defines **how deployments trace back to source code, pipelines, and artifacts**.

Every deployment must be **traceable, reproducible, and auditable**.

---

## Why Traceability Matters

Traceability answers critical questions:

- **What is deployed?** Which artifact version is running in production?
- **Where did it come from?** Which commit, branch, and repository?
- **Who deployed it?** Which pipeline, approver, and timestamp?
- **How do we roll back?** Which previous artifact should we revert to?
- **Has it been tested?** Which environments validated this artifact?

**Without traceability, deployments are unauditable and risky.**

---

## Traceability Requirements

The platform enforces **end-to-end traceability**:

1. **Every artifact links to source code** (commit SHA, repository URL)
2. **Every deployment links to an artifact** (image tag, digest)
3. **Every artifact links to a pipeline** (run ID, execution URL)
4. **Every change is auditable** (who, what, when, why)

**No deployment is allowed without traceability.**

---

## Forward Traceability

**Forward trace**: From source code to deployed environment.

### Trace Flow

```
Commit SHA
    ↓
Pipeline Run
    ↓
Artifact (Container Image)
    ↓
Deployment (Dev)
    ↓
Deployment (Staging)
    ↓
Deployment (Production)
```

### Example Forward Trace

**Scenario**: Developer commits code; deployment reaches production.

1. **Commit**:
   - SHA: `7a3f9c29b1e4f8d3a5c6e2f1b9d4a8c7e5f3b2a1`
   - Repository: `https://github.com/nikhilgummadavelli8/cloud-platform-cicd-automation`
   - Branch: `main`
   - Author: `developer@example.com`
   - Message: "Add new feature"

2. **Pipeline Run**:
   - Run ID: `1234567890`
   - Triggered by: Merge to `main`
   - Started: `2024-01-08T12:34:56Z`
   - Status: `success`

3. **Artifact Created**:
   - Image: `myregistry.azurecr.io/api-gateway:7a3f9c2`
   - Digest: `sha256:abc123...`
   - Build timestamp: `2024-01-08T12:35:30Z`
   - Metadata: Commit SHA, pipeline run ID, repository URL

4. **Deployed to Dev**:
   - Environment: `development`
   - Deployment timestamp: `2024-01-08T12:36:00Z`
   - Artifact: `myregistry.azurecr.io/api-gateway:7a3f9c2`
   - Status: `healthy`

5. **Deployed to Staging**:
   - Environment: `staging`
   - Deployment timestamp: `2024-01-08T14:00:00Z`
   - Artifact: `myregistry.azurecr.io/api-gateway:7a3f9c2` (same artifact)
   - Status: `healthy`

6. **Deployed to Production**:
   - Environment: `production`
   - Deployment timestamp: `2024-01-08T16:00:00Z`
   - Artifact: `myregistry.azurecr.io/api-gateway:7a3f9c2` (same artifact)
   - Approver: `platform-lead@example.com`
   - Status: `healthy`

**Forward trace complete**: From commit to production deployment.

---

## Reverse Traceability

**Reverse trace**: From deployed environment back to source code.

### Trace Flow

```
Production Environment
    ↓
Deployed Artifact (Image Tag)
    ↓
Artifact Metadata (OCI Labels)
    ↓
Commit SHA
    ↓
Source Code
```

### Example Reverse Trace

**Scenario**: Production has an issue; engineer investigates what's deployed.

1. **Query Production Environment**:
   ```bash
   kubectl get deployment api-gateway -o jsonpath='{.spec.template.spec.containers[0].image}'
   # Output: myregistry.azurecr.io/api-gateway:7a3f9c2
   ```

2. **Inspect Artifact Metadata**:
   ```bash
   docker inspect myregistry.azurecr.io/api-gateway:7a3f9c2 --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}'
   # Output: 7a3f9c29b1e4f8d3a5c6e2f1b9d4a8c7e5f3b2a1
   ```

3. **Identify Source Commit**:
   ```bash
   git log --oneline 7a3f9c29b1e4f8d3a5c6e2f1b9d4a8c7e5f3b2a1 -1
   # Output: 7a3f9c2 Add new feature
   ```

4. **Trace Pipeline Execution**:
   ```bash
   docker inspect myregistry.azurecr.io/api-gateway:7a3f9c2 --format '{{ index .Config.Labels "io.github.pipeline.run-url" }}'
   # Output: https://github.com/org/repo/actions/runs/1234567890
   ```

5. **Review Source Code**:
   - View commit: `https://github.com/org/repo/commit/7a3f9c29b1e4f8d3a5c6e2f1b9d4a8c7e5f3b2a1`
   - Review changes, tests, approvals
   - Identify root cause of issue

**Reverse trace complete**: From production issue to exact source code.

---

## Rollback Traceability

**Rollback**: Reverting to a previous known-good artifact.

### Rollback Process

1. **Identify Current Artifact**:
   - Query production: `kubectl get deployment api-gateway -o jsonpath='{.spec.template.spec.containers[0].image}'`
   - Current: `myregistry.azurecr.io/api-gateway:7a3f9c2`

2. **Query Deployment History**:
   ```bash
   kubectl rollout history deployment api-gateway
   # Output:
   # REVISION  CHANGE-CAUSE
   # 1         Initial deployment (4b2e8f1)
   # 2         Bug fix (6d3a7c9)
   # 3         New feature (7a3f9c2) <- current
   ```

3. **Identify Previous Working Version**:
   - Previous artifact: `myregistry.azurecr.io/api-gateway:6d3a7c9`
   - Verify artifact exists in registry
   - Confirm artifact passed staging validation

4. **Execute Rollback**:
   ```bash
   kubectl set image deployment/api-gateway api-gateway=myregistry.azurecr.io/api-gateway:6d3a7c9
   ```

5. **Validate Rollback**:
   - Health checks pass
   - Verify production traffic restored
   - Log rollback event with artifact version, timestamp, approver

**Rollback complete**: Production reverted to known-good artifact `6d3a7c9`.

### Rollback Metadata

All rollbacks are logged with:
- **From version**: Failing artifact (`7a3f9c2`)
- **To version**: Rollback target (`6d3a7c9`)
- **Timestamp**: When rollback occurred
- **Approver**: Who authorized rollback
- **Reason**: Incident ticket or failure description

---

## Artifact Linkage Model

Every artifact maintains linkage to:

### Source Code Linkage

- **Commit SHA** (full 40-character SHA)
- **Repository URL**
- **Branch name**
- **Commit author**
- **Commit message**

**Stored in**: OCI labels, Helm chart annotations, artifact manifest

---

### Pipeline Linkage

- **Pipeline run ID**
- **Pipeline execution URL**
- **Triggered by** (user, merge, schedule)
- **Build timestamp**
- **Pipeline success/failure status**

**Stored in**: OCI labels, build metadata, artifact manifest

---

### Environment Linkage

For each environment (dev, staging, production):

- **Deployment timestamp**
- **Deployer identity** (pipeline or human approver)
- **Deployment status** (healthy, degraded, failed)
- **Verification results** (smoke tests passed/failed)

**Stored in**: Kubernetes annotations, deployment logs, Git tags

---

## Cross-Environment Traceability

The same artifact is deployed to **all environments**.

### Environment Progression

```
Artifact: myregistry.azurecr.io/api-gateway:7a3f9c2

Dev:
  - Deployed: 2024-01-08T12:36:00Z
  - Status: Healthy
  - Tests: Unit, integration passed

Staging:
  - Deployed: 2024-01-08T14:00:00Z (same artifact)
  - Status: Healthy
  - Tests: E2E, performance passed

Production:
  - Deployed: 2024-01-08T16:00:00Z (same artifact)
  - Status: Healthy
  - Approver: platform-lead@example.com
```

**Key principle**: Production artifact has been validated in lower environments.

---

## Audit Trail

The platform maintains a complete audit trail of all deployments.

### Audit Log Contents

For every deployment:

1. **What**: Artifact name, version, digest
2. **Where**: Environment (dev, staging, production)
3. **When**: Deployment timestamp (UTC)
4. **Who**: Deployer identity (pipeline service principal or human approver)
5. **Why**: Trigger (commit, manual promotion, rollback)
6. **How**: Pipeline run ID, execution logs
7. **Status**: Success, failure, rolled back

### Audit Retention

- **Development**: 30 days
- **Staging**: 90 days
- **Production**: 2 years (compliance requirement)

---

## Traceability Tools

### Query Deployed Artifact

```bash
# Kubernetes
kubectl get deployment <name> -n <namespace> -o jsonpath='{.spec.template.spec.containers[0].image}'

# Azure App Service
az webapp config container show --name <app> --resource-group <rg> --query "[0].value" -o tsv
```

---

### Inspect Artifact Metadata

```bash
# Container image
docker inspect <image> --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}'

# Helm chart
helm show chart <chart> | grep commit
```

---

### Trace Pipeline Execution

```bash
# GitHub Actions
gh run view <run-id>

# Direct URL
https://github.com/<org>/<repo>/actions/runs/<run-id>
```

---

### Identify Source Commit

```bash
# Git log
git log --oneline <commit-sha> -1

# GitHub UI
https://github.com/<org>/<repo>/commit/<commit-sha>
```

---

## Provenance and Supply Chain Security

Traceability supports **supply chain security** and **SLSA compliance**.

### SLSA (Supply-chain Levels for Software Artifacts)

The platform aligns with SLSA Level 2 requirements:

1. **Version control**: All source code in Git
2. **Build service**: Builds run on trusted GitHub Actions runners
3. **Build as code**: Pipeline definitions in version control
4. **Provenance**: Artifact metadata links to source and build

**Future**: SLSA Level 3+ with signed provenance (Sigstore, cosign).

---

### Provenance Attestation

For each artifact, the platform generates a **provenance attestation**:

```json
{
  "subject": {
    "name": "myregistry.azurecr.io/api-gateway",
    "digest": "sha256:abc123..."
  },
  "predicateType": "https://slsa.dev/provenance/v0.2",
  "predicate": {
    "builder": {
      "id": "https://github.com/nikhilgummadavelli8/cloud-platform-cicd-automation/.github/workflows/pipeline-skeleton.yml"
    },
    "buildType": "https://github.com/actions/runner",
    "invocation": {
      "configSource": {
        "uri": "https://github.com/nikhilgummadavelli8/cloud-platform-cicd-automation",
        "digest": {"sha1": "7a3f9c29b1e4f8d3a5c6e2f1b9d4a8c7e5f3b2a1"}
      }
    },
    "metadata": {
      "buildStartedOn": "2024-01-08T12:34:56Z",
      "buildFinishedOn": "2024-01-08T12:35:30Z"
    },
    "materials": [
      {
        "uri": "https://github.com/nikhilgummadavelli8/cloud-platform-cicd-automation",
        "digest": {"sha1": "7a3f9c29b1e4f8d3a5c6e2f1b9d4a8c7e5f3b2a1"}
      }
    ]
  }
}
```

**Provenance attestation** signed and stored alongside artifact.

---

## Compliance and Reporting

Traceability enables compliance reporting:

### SOC 2 / ISO 27001

- **Change management**: Every deployment has audit trail
- **Access control**: Deployer identity logged
- **Rollback capability**: Previous versions traceable

### PCI-DSS

- **Change tracking**: All production changes logged
- **Approval workflows**: Manual approval for production
- **Audit logs**: 2-year retention for card data environments

### GDPR / Data Privacy

- **Data provenance**: Code handling PII is traceable to source
- **Right to rectification**: Bugs in data processing traceable to commits

---

## Conformance

This traceability model is **mandatory** and **non-negotiable**.

Deployments that:
- Lack artifact metadata
- Cannot trace back to source code
- Bypass audit logging

**...are rejected by the platform.**

Traceability is architectural, not optional.
