# Non-Prod Deployment Model

This document defines **how non-production deployments are executed**.

Non-prod deployments must be **safe, repeatable, and self-verifying**.

---

## Supported Non-Prod Environments

The platform supports the following non-production environments:

### Development (dev)

**Purpose**: Early-stage integration testing and rapid iteration.

- **Deployment trigger**: Automatic on push to `feature/*`, `bugfix/*` branches
- **Artifact source**: Latest build from feature/bugfix branch
- **Configuration**: Dev-specific (lower resource limits, verbose logging)
- **Verification**: Basic health checks + smoke tests
- **Rollback**: Automatic on verification failure
- **Retention**: Latest deployment only (no history preservation)

**Example dev endpoint**: `https://dev.example.com`

---

### Staging (staging)

**Purpose**: Pre-production validation in production-like environment.

- **Deployment trigger**: Automatic on merge to `main` or `release/*` branches
- **Artifact source**: Artifact validated in dev
- **Configuration**: Production-like (same resource limits, minimal logging)
- **Verification**: Comprehensive health checks + E2E tests + performance validation
- **Rollback**: Automatic on verification failure
- **Retention**: Last 5 deployments preserved for rollback

**Example staging endpoint**: `https://staging.example.com`

**Critical**: Staging configuration must match production as closely as possible (infrastructure parity).

---

### Optional: Test Environment (test)

**Purpose**: Dedicated environment for QA/automated test suites.

- **Deployment trigger**: Manual or scheduled
- **Artifact source**: Specific artifact version (not always latest)
- **Configuration**: Test-specific (may include test data fixtures)
- **Verification**: Test suite execution results
- **Rollback**: Not applicable (test environment is ephemeral)

**Note**: Test environment is optional. Many teams use dev for testing.

---

## Environment Configuration Injection

Configuration is **externalized from artifacts** and injected at deployment time.

### Configuration vs Secrets

| Aspect | Configuration | Secrets |
|--------|---------------|---------|
| **Sensitivity** | Non-sensitive | Sensitive |
| **Storage** | Environment variables, config files | Azure Key Vault |
| **Examples** | API endpoints, feature flags, timeouts | Database passwords, API keys |
| **Visibility** | Can be logged (non-sensitive) | Never logged |

**Rule**: If exposure would compromise security, it's a secret.

---

### Configuration Sources

Configuration is loaded from multiple sources (in order of precedence):

1. **Environment Variables** (highest precedence)
   - Set by deployment pipeline or Kubernetes ConfigMap
   - Example: `API_GATEWAY_URL=https://api-dev.example.com`

2. **Configuration Files**
   - Deployed alongside application (non-sensitive config)
   - Example: `config/dev.json`, `config/staging.json`

3. **Azure Key Vault** (for secrets only)
   - Retrieved at runtime using OIDC authentication
   - Example: Database connection strings, third-party API keys

4. **Defaults** (lowest precedence)
   - Hardcoded defaults in application code (for non-critical settings)

---

### Environment-Specific Configuration

Each environment has distinct configuration values:

#### Development Configuration

```yaml
environment: development
api_gateway_url: https://api-dev.example.com
database_connection_pool_size: 5
log_level: DEBUG
enable_debug_endpoints: true
cache_ttl_seconds: 60
```

#### Staging Configuration

```yaml
environment: staging
api_gateway_url: https://api-staging.example.com
database_connection_pool_size: 20
log_level: INFO
enable_debug_endpoints: false
cache_ttl_seconds: 300
```

**Key principle**: Configuration changes do not require rebuilding the artifact.

---

### Configuration Injection Methods

#### Kubernetes ConfigMaps

For containerized applications deployed to AKS:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-dev
  namespace: development
data:
  API_GATEWAY_URL: "https://api-dev.example.com"
  LOG_LEVEL: "DEBUG"
  CACHE_TTL: "60"
```

Mount as environment variables or volume in deployment:

```yaml
env:
  - name: API_GATEWAY_URL
    valueFrom:
      configMapKeyRef:
        name: app-config-dev
        key: API_GATEWAY_URL
```

---

#### Azure App Configuration (Optional)

Centralized configuration management across environments:

- Configuration stored in Azure App Configuration service
- Application loads config at startup using OIDC
- Dynamic configuration updates without redeployment

**Use case**: Feature flags, A/B testing, gradual rollouts.

---

## Idempotency Expectations

Non-prod deployments must be **idempotent**: re-deploying the same artifact to the same environment produces the same result.

### Idempotency Requirements

1. **Re-running deployment with same artifact is safe**
   - No data loss
   - No duplicate resource creation
   - State converges to desired state

2. **Deployment scripts use declarative operations**
   - Kubernetes: `kubectl apply` (declarative, idempotent)
   - Terraform: `terraform apply` (declarative, idempotent)
   - Helm: `helm upgrade --install` (idempotent)

3. **No destructive operations during deployment**
   - Database migrations are additive (no DROP TABLE)
   - Old resources are gracefully terminated (no abrupt deletion)
   - Rollback is always possible

4. **State is externalized**
   - Application state stored in databases, not in-memory
   - No reliance on ephemeral local state
   - Stateless application pods

### Idempotency Testing

To verify idempotency, deploy the same artifact twice:

```bash
# First deployment
deploy.sh dev my-app:7a3f9c2

# Second deployment (should succeed without errors)
deploy.sh dev my-app:7a3f9c2
```

**Expected outcome**: Both deployments succeed. Second deployment reports "no changes" or "state already converged."

---

## Deployment Ordering and Dependencies

### Dependency Deployment Order

When deploying applications with dependencies, deploy in dependency order:

1. **Infrastructure** (Terraform: networking, AKS, databases)
2. **Platform services** (ingress controllers, cert-manager, monitoring)
3. **Application dependencies** (message queues, caches, databases)
4. **Application services** (backend APIs, workers)
5. **Frontend** (web UI, mobile app backends)

**Rule**: Dependencies must be healthy before dependents are deployed.

---

### Parallel Deployment (When Safe)

Independent services can be deployed in parallel:

```
deploy-api-gateway (independent)
    ↓
verify-api-gateway

deploy-data-processor (independent)
    ↓
verify-data-processor
```

**Safe for parallel deployment if**:
- Services do not depend on each other
- Services do not share mutable state
- Deployment order does not affect correctness

---

## Deployment Execution Steps

Every non-prod deployment follows this sequence:

### Step 1: Pre-Deployment Validation

Before deployment begins:

- **Artifact exists**: Verify artifact in registry (immutable tag)
- **Metadata valid**: Artifact has required metadata (commit SHA, pipeline run ID)
- **Environment healthy**: Target environment is ready to receive deployment
- **Concurrency check**: No other deployment in progress for this environment

**If validation fails, deployment is blocked.**

---

### Step 2: Deploy Artifact

Deploy the artifact to the target environment:

```bash
# Kubernetes example (Helm)
helm upgrade --install my-app ./chart \
  --namespace development \
  --set image.repository=myregistry.azurecr.io/my-app \
  --set image.tag=7a3f9c2 \
  --set environment=dev \
  --values config/dev-values.yaml
```

**Deployment is declarative**: Helm/Kubernetes converges current state to desired state.

---

### Step 3: Wait for Rollout Completion

Wait for deployment to complete before verification:

```bash
# Wait for all pods to be ready
kubectl rollout status deployment/my-app -n development --timeout=5m
```

**Timeout**: 5 minutes (configurable per service).

**If rollout times out, deployment is failed.**

---

### Step 4: Verify Deployment

Run verification checks (see [verification-and-health-checks.md](./verification-and-health-checks.md)):

- Health endpoint returns 200 OK
- Readiness checks pass
- Dependencies are reachable
- Smoke tests pass

**If verification fails, rollback is triggered.**

---

### Step 5: Record Deployment

Log deployment details for audit and traceability:

```json
{
  "environment": "development",
  "artifact": "myregistry.azurecr.io/my-app:7a3f9c2",
  "deployed_at": "2024-01-08T14:30:00Z",
  "deployed_by": "pipeline-run-12345",
  "status": "success",
  "verification_passed": true,
  "rollout_duration_seconds": 45
}
```

**Deployment record stored in**:
- Kubernetes annotations (on Deployment resource)
- Git tags (e.g., `deployed-dev-7a3f9c2`)
- Deployment history service (optional centralized logging)

---

## No Environment-Specific Builds

**Prohibited**: Building different artifacts for different environments.

### ❌ Prohibited Pattern

```bash
# Build for dev
docker build --build-arg ENV=dev -t myapp:dev .

# Build for staging
docker build --build-arg ENV=staging -t myapp:staging .
```

**Why prohibited**:
- Different artifacts for different environments (not the same tested code)
- Cannot promote artifact from dev to staging (must rebuild)
- Breaks traceability

---

### ✅ Correct Pattern

```bash
# Build once (environment-agnostic)
docker build -t myapp:7a3f9c2 .

# Deploy to dev with dev config
helm install myapp ./chart --set env=dev

# Deploy to staging with staging config (SAME ARTIFACT)
helm install myapp ./chart --set env=staging
```

**Why correct**:
- Same artifact deployed to all environments
- Configuration injected at deployment time
- Promotes tested artifact from dev to staging

---

## No Manual Steps

Non-prod deployments must be **fully automated**.

### ❌ Prohibited Manual Steps

- SSH into server and restart service
- Manually edit configuration files post-deployment
- Run database migrations manually
- Copy files to production via `scp` or FTP

**All manual steps must be automated into the deployment pipeline.**

---

### ✅ Automated Alternatives

| Manual Step | Automated Alternative |
|-------------|----------------------|
| SSH and restart service | Kubernetes rollout (automatic) |
| Edit config files | ConfigMap updates via pipeline |
| Run migrations manually | Migration job in pipeline |
| Copy files | Artifact registry + automated deployment |

---

## Rollback on Failure

If verification fails, deployment is **automatically rolled back**.

### Rollback Process

1. **Identify previous working version**
   - Query deployment history: `kubectl rollout history deployment/my-app`
   - Identify last successful deployment

2. **Execute rollback**
   ```bash
   kubectl rollout undo deployment/my-app -n development
   ```

3. **Verify rollback success**
   - Run same verification checks
   - Confirm application is healthy

4. **Log rollback event**
   - Record rollback in audit log
   - Notify team of rollback

**Rollback is automatic in non-prod. Notification is informational, not blocking.**

---

## Deployment Concurrency Control

**Only one deployment per environment at a time.**

### Concurrency Enforcement

GitHub Actions enforces concurrency via `concurrency` groups:

```yaml
concurrency:
  group: deploy-${{ github.workflow }}-${{ inputs.environment }}
  cancel-in-progress: false  # Queue deployments, don't cancel
```

**Behavior**:
- If deployment is in progress for `dev`, next deployment waits
- Queued deployments execute sequentially
- No parallel deployments to same environment (prevents race conditions)

---

## Deployment Observability

Every deployment is observable and auditable.

### Deployment Logs

All deployment actions are logged:

- Deployment start/end timestamps
- Artifact version deployed
- Configuration applied
- Verification results
- Rollback events (if any)

**Logs retained for**: 30 days (dev), 90 days (staging).

---

### Deployment Metrics

Track deployment health:

- **Deployment frequency**: How often we deploy (higher is better, indicates CI/CD maturity)
- **Deployment duration**: Time from deploy start to verification success
- **Failure rate**: Percentage of deployments that fail verification
- **Rollback rate**: Percentage of deployments rolled back

**Targets**:
- Dev: Multiple deployments per day
- Staging: Daily deployments (after dev validation)

---

## Environment Parity

Staging environment must closely match production.

### Parity Requirements

| Aspect | Dev | Staging | Production |
|--------|-----|---------|------------|
| **Infrastructure** | Scaled down | Same as prod | Full scale |
| **Resource limits** | Low (cost optimization) | Same as prod | Production-grade |
| **Network config** | Simplified | Same as prod | Production-grade |
| **Data** | Synthetic/test data | Anonymized prod data | Real data |
| **Monitoring** | Basic | Same as prod | Full observability |

**Staging parity goal**: Catch production issues before production deployment.

---

## Conformance

This non-prod deployment model is **mandatory** and **non-negotiable**.

Non-prod deployments that:
- Require manual intervention
- Use environment-specific builds
- Skip verification

**...are rejected by the platform.**

Non-prod deployment discipline ensures safe, repeatable deployments.
