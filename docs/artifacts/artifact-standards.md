# Artifact Standards

This document defines **what qualifies as a valid artifact** in the CI/CD platform.

**Non-conforming artifacts must not be deployable.**

---

## Artifact Types

The platform supports the following artifact types:

### Container Images

**Primary artifact type** for application deployments.

- **Format**: OCI-compliant container images (Docker, containerd)
- **Registry**: Azure Container Registry (ACR)
- **Base images**: Approved base images only (security-scanned, minimal OS)
- **Layers**: Optimized for size and security (no unnecessary packages)

**Example**: `myapp:7a3f9c2`

---

### Helm Charts

**Infrastructure and application configuration** packaged as Helm charts.

- **Format**: Helm 3 charts (`.tgz` archive)
- **Registry**: ACR (Helm OCI support) or GitHub Packages
- **Versioning**: Semantic versioning (e.g., `1.2.3`)

**Example**: `myapp-chart:1.2.3`

---

### Compiled Binaries (Optional)

**Non-containerized artifacts** for specific use cases.

- **Format**: Language-specific packages (npm, Maven, NuGet, Go binaries)
- **Registry**: GitHub Packages or language-specific registries
- **Use case**: Shared libraries, CLI tools, Lambda functions

**Example**: `mylib-1.2.3.tar.gz`

---

### Terraform Modules (Infrastructure Artifacts)

**Reusable infrastructure definitions** versioned as artifacts.

- **Format**: Terraform modules (directory structure)
- **Registry**: GitHub releases or Terraform registry
- **Versioning**: Semantic versioning

**Example**: `terraform-azure-aks:2.1.0`

---

## Naming Conventions

All artifacts follow consistent naming patterns.

### Container Image Naming

```
<registry>/<repository>:<tag>
```

**Components**:
- `<registry>`: Azure Container Registry FQDN (e.g., `myregistry.azurecr.io`)
- `<repository>`: Application or service name (lowercase, hyphens allowed)
- `<tag>`: Immutable version identifier (commit SHA or semantic version)

**Examples**:
- `myregistry.azurecr.io/api-gateway:7a3f9c2`
- `myregistry.azurecr.io/data-processor:v1.2.3`

**Prohibited**:
- ❌ `latest` (mutable, non-traceable)
- ❌ `dev` or `prod` (environment tags are mutable)
- ❌ `master` or `main` (branch names are mutable)

---

### Helm Chart Naming

```
<chart-name>:<version>
```

**Components**:
- `<chart-name>`: Application name (matches repository name)
- `<version>`: Semantic version (`MAJOR.MINOR.PATCH`)

**Examples**:
- `api-gateway:1.2.3`
- `data-processor:2.0.1`

---

### Package Naming

```
<package-name>-<version>.<extension>
```

**Examples**:
- `mylib-1.2.3.tar.gz`
- `mycli-2.0.0.zip`

---

## Versioning Rules

Artifacts must use **immutable, traceable version identifiers**.

### Semantic Versioning (SemVer)

Use semantic versioning for **release artifacts**:

```
MAJOR.MINOR.PATCH
```

**Rules**:
- `MAJOR`: Breaking changes
- `MINOR`: New features (backward-compatible)
- `PATCH`: Bug fixes (backward-compatible)

**Example**: `1.2.3`

**Pre-release tags** (optional):
- `1.2.3-alpha.1`
- `1.2.3-beta.2`
- `1.2.3-rc.1`

---

### Commit SHA-Based Versioning

Use **short commit SHA** for **non-release artifacts** (dev, staging):

```
<short-sha>
```

**Format**: 7-character Git commit SHA  
**Example**: `7a3f9c2`

**Advantages**:
- Immutable (commit SHAs never change)
- Traceable (directly links to source code)
- Unique (no collisions)

---

### Combined Versioning

Use **semantic version + commit SHA** for full traceability:

```
<semver>-<short-sha>
```

**Example**: `1.2.3-7a3f9c2`

**Use case**: Release candidates that need both semantic meaning and exact commit traceability.

---

### Prohibited Version Tags

The following version tags are **prohibited**:

| Prohibited Tag | Reason |
|----------------|--------|
| `latest`       | Mutable, non-traceable |
| `dev`, `staging`, `prod` | Environment-based tags are mutable |
| `main`, `master` | Branch names are mutable |
| `v1`, `v2` | Too coarse, not traceable |
| Date-based (e.g., `2024-01-08`) | Not linked to source code |

**Enforcement**: Pipeline fails if artifact uses prohibited tags.

---

## Required Metadata

All artifacts must include **required metadata** for traceability and auditability.

### Container Image Metadata (OCI Labels)

Container images must include the following OCI labels:

```dockerfile
LABEL org.opencontainers.image.source="https://github.com/nikhilgummadavelli8/cloud-platform-cicd-automation"
LABEL org.opencontainers.image.revision="7a3f9c29b1e4f8d3a5c6e2f1b9d4a8c7e5f3b2a1"
LABEL org.opencontainers.image.created="2024-01-08T12:34:56Z"
LABEL org.opencontainers.image.version="1.2.3"
LABEL org.opencontainers.image.title="api-gateway"
LABEL io.github.pipeline.run-id="1234567890"
LABEL io.github.pipeline.run-url="https://github.com/org/repo/actions/runs/1234567890"
```

**Required labels**:
- `org.opencontainers.image.source`: Git repository URL
- `org.opencontainers.image.revision`: Full commit SHA (40 characters)
- `org.opencontainers.image.created`: Build timestamp (ISO 8601 UTC)
- `org.opencontainers.image.version`: Artifact version (semver or SHA)
- `io.github.pipeline.run-id`: GitHub Actions run ID
- `io.github.pipeline.run-url`: Link to pipeline execution

---

### Helm Chart Metadata

Helm charts must include metadata in `Chart.yaml`:

```yaml
apiVersion: v2
name: api-gateway
version: 1.2.3
appVersion: 7a3f9c2
annotations:
  git.commit: 7a3f9c29b1e4f8d3a5c6e2f1b9d4a8c7e5f3b2a1
  git.repository: https://github.com/nikhilgummadavelli8/cloud-platform-cicd-automation
  pipeline.run-id: "1234567890"
  build.timestamp: "2024-01-08T12:34:56Z"
```

**Required fields**:
- `version`: Chart version (semantic)
- `appVersion`: Application version (commit SHA)
- `annotations.git.commit`: Full commit SHA
- `annotations.git.repository`: Repository URL
- `annotations.pipeline.run-id`: Pipeline run ID
- `annotations.build.timestamp`: Build timestamp

---

### Artifact Manifest (Sidecar Metadata)

For artifacts that don't support embedded metadata, create a **sidecar manifest**:

```json
{
  "artifact": {
    "name": "api-gateway",
    "version": "7a3f9c2",
    "type": "container-image",
    "registry": "myregistry.azurecr.io/api-gateway:7a3f9c2"
  },
  "source": {
    "repository": "https://github.com/nikhilgummadavelli8/cloud-platform-cicd-automation",
    "commit": "7a3f9c29b1e4f8d3a5c6e2f1b9d4a8c7e5f3b2a1",
    "branch": "main",
    "commit_message": "Add new feature"
  },
  "build": {
    "pipeline_run_id": "1234567890",
    "pipeline_url": "https://github.com/org/repo/actions/runs/1234567890",
    "build_timestamp": "2024-01-08T12:34:56Z",
    "builder": "GitHub Actions"
  },
  "security": {
    "vulnerability_scan": "passed",
    "scan_timestamp": "2024-01-08T12:35:30Z",
    "sbom_url": "https://example.com/sbom/7a3f9c2.json"
  }
}
```

**Sidecar manifest** stored alongside artifact in registry or as pipeline artifact.

---

## Metadata Validation

The platform validates metadata before deployment.

### Validation Rules

1. **All required metadata present**: Missing fields cause deployment failure
2. **Commit SHA is valid**: Must be a valid Git commit in the repository
3. **Pipeline run ID is traceable**: Must link to a real pipeline execution
4. **Timestamp is recent**: Artifacts older than retention policy are rejected (e.g., 90 days for dev)

### Enforcement

Deployment stages include metadata validation step:

```yaml
- name: Validate Artifact Metadata
  run: |
    # Extract metadata from container image
    docker inspect <image> --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}'
    
    # Fail if required labels missing
    if [ -z "$COMMIT_SHA" ]; then
      echo "ERROR: Missing required metadata: org.opencontainers.image.revision"
      exit 1
    fi
```

**Artifacts without valid metadata cannot proceed to deployment.**

---

## Immutability Enforcement

Artifacts are **immutable** once published.

### Registry-Level Enforcement

Azure Container Registry enforces immutability via **Content Trust** and **Retention Policies**:

- **Content Trust**: Signed images cannot be overwritten
- **Tag locking**: Specific tags can be locked to prevent deletion or modification
- **Retention policies**: Old artifacts are automatically archived or deleted

### Pipeline-Level Enforcement

Pipelines enforce immutability by:

1. **Refusing to overwrite existing tags**: Build fails if tag already exists
2. **Using content-addressable storage**: Images referenced by digest, not tag
3. **Validating artifact existence**: Deploy fails if artifact doesn't exist in registry

### Example Enforcement

```bash
# Check if artifact already exists
if docker manifest inspect myregistry.azurecr.io/api-gateway:7a3f9c2 > /dev/null 2>&1; then
  echo "ERROR: Artifact with tag '7a3f9c2' already exists. Artifacts are immutable."
  exit 1
fi

# Push artifact
docker push myregistry.azurecr.io/api-gateway:7a3f9c2
```

---

## Artifact Lifecycle

### State Transitions

```
Created → Published → Deployed (Dev) → Deployed (Staging) → Deployed (Production) → Archived
```

**States**:
- **Created**: Built locally during pipeline build stage
- **Published**: Pushed to registry (immutable)
- **Deployed (Dev/Staging/Production)**: Pulled from registry and deployed
- **Archived**: Moved to cold storage after retention period

**Artifacts never transition backward** (e.g., production artifacts are not re-deployed to dev).

---

### Retention Policies

| Environment | Retention Period | Policy |
|-------------|------------------|--------|
| Development | 7 days           | Auto-delete after 7 days |
| Staging     | 30 days          | Auto-archive after 30 days |
| Production  | 1 year           | Archive, manual deletion only |

**Rationale**: Dev artifacts are ephemeral; production artifacts must be retained for audit and rollback.

---

## Artifact Promotion

Artifacts are **promoted** between environments, not rebuilt.

### Promotion Flow

```
Build (creates artifact)
    ↓
Publish to Registry (immutable tag: 7a3f9c2)
    ↓
Deploy to Dev (pull 7a3f9c2)
    ↓
Test in Dev
    ↓
Promote to Staging (same tag: 7a3f9c2)
    ↓
Test in Staging
    ↓
Promote to Production (same tag: 7a3f9c2)
```

**Key principle**: The artifact deployed to production is **byte-for-byte identical** to the artifact tested in dev and staging.

---

## Conformance

These artifact standards are **mandatory** and **non-negotiable**.

Artifacts that:
- Use mutable tags (`latest`, `dev`, `prod`)
- Lack required metadata
- Are rebuilt for production instead of promoted

**...will be rejected by the platform.**

The platform enforces artifact discipline architecturally.
