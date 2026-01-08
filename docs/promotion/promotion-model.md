# Promotion Model

This document defines **how artifacts are promoted across environments**.

**Promotion is not deployment. Promotion is validation of readiness.**

---

## Promotion Definition

**Promotion** is the act of moving a **validated, immutable artifact** from one environment to the next in the deployment pipeline.

**Key characteristics**:
- **Same artifact**: No rebuild, no modification
- **Explicit approval**: Human decision, not automatic
- **Preconditions validated**: Previous environment must be healthy
- **Audit trail**: Every promotion logged

---

## Promotion Eligibility

An artifact is eligible for promotion only if:

### 1. Artifact Is Immutable

- **Artifact tag is immutable** (commit SHA, not `latest`)
- **Artifact has not been modified** since initial build
- **Artifact digest matches** build-time digest

**Verification**: Pipeline queries registry to confirm artifact exists and digest matches.

---

### 2. Artifact Is Traceable

- **Artifact has required metadata** (commit SHA, pipeline run ID, build timestamp)
- **Metadata is complete and valid** (all required fields present)
- **Source commit is reachable** in repository

**Verification**: Pipeline validates metadata completeness before promotion.

---

### 3. Previous Environment Verification Passed

- **Artifact was deployed to previous environment** (dev or staging)
- **Verification passed** in previous environment (health checks, smoke tests)
- **No verification failures** in recent deployment history

**Example**:
- **Staging promotion**: Artifact must have passed dev verification
- **Production promotion**: Artifact must have passed staging verification

**Verification**: Pipeline checks deployment history and verification results.

---

### 4. No Critical Vulnerabilities

- **Security scan passed** (no critical CVEs)
- **License compliance met** (no prohibited licenses)
- **SBOM generated** and available

**Verification**: Pipeline validates scan results before promotion.

---

### 5. Approval Granted (Production Only)

- **Manual approval obtained** from authorized approver
- **Approval is current** (not stale or revoked)
- **Approver has appropriate privilege** (production deployment role)

**Verification**: GitHub environment protection rules enforce approval.

---

## Promotion Flow

Artifacts progress through environments in a defined order:

```
Build
  ↓
Deploy to Dev
  ↓
Verify Dev ✅
  ↓
[PROMOTION GATE 1] → Promote to Staging
  ↓
Deploy to Staging
  ↓
Verify Staging ✅
  ↓
[PROMOTION GATE 2] → Promote to Production (MANUAL APPROVAL)
  ↓
Deploy to Production
  ↓
Verify Production ✅
```

**Promotion gates validate eligibility before allowing progression.**

---

## Promotion Gate 1: Dev → Staging

### Preconditions

- ✅ Artifact deployed to dev successfully
- ✅ Dev verification passed (health checks, smoke tests, dependencies)
- ✅ Artifact is immutable and traceable
- ✅ No critical vulnerabilities

### Approval

**Automatic** (no human approval required)

**Rationale**: Staging is pre-production validation environment, low risk.

### Enforcement

Pipeline checks:
```yaml
if: |
  needs.verify-dev.result == 'success' &&
  needs.build.outputs.image_tag != 'latest'
```

**If preconditions not met, staging deployment is blocked.**

---

## Promotion Gate 2: Staging → Production

### Preconditions

- ✅ Artifact deployed to staging successfully
- ✅ Staging verification passed (comprehensive health checks, E2E tests)
- ✅ Artifact is immutable and traceable
- ✅ No critical vulnerabilities
- ✅ Artifact has been in staging for minimum duration (e.g., 1 hour soak time)

### Approval

**Manual approval required** from authorized approver.

**Approvers**:
- Platform lead
- Release manager
- On-call SRE (for emergency deployments)

**Approval method**: GitHub environment protection rule (manual approval within GitHub UI)

### Enforcement

Pipeline enforces:
```yaml
environment:
  name: production  # Requires manual approval
if: github.event_name == 'workflow_dispatch'  # Explicit trigger only
```

**Production deployment requires**:
1. Manual workflow dispatch (not automatic on push)
2. GitHub environment approval (human approver)
3. Authorized approver identity logged

**If approval not granted, production deployment is blocked.**

---

## Promotion vs Deployment

### Promotion (Eligibility Check)

**Purpose**: Validate artifact is ready for next environment

**Actions**:
- Check artifact immutability
- Validate metadata completeness
- Confirm previous environment verification passed
- Enforce approval requirements (production)

**Outcome**: Artifact is **eligible** or **ineligible** for next environment

**Example**:
```bash
# Promotion check (before deployment)
if artifact_verified_in_staging && approva

l_granted; then
  echo "Artifact eligible for production promotion"
  deploy_to_production
else
  echo "Artifact NOT eligible for promotion"
  exit 1
fi
```

---

### Deployment (Artifact Installation)

**Purpose**: Install artifact in target environment

**Actions**:
- Pull artifact from registry
- Apply Kubernetes manifests
- Inject environment-specific configuration
- Wait for rollout completion

**Outcome**: Artifact is **deployed** (running in environment)

**Example**:
```bash
# Deployment (after promotion eligibility confirmed)
helm upgrade --install my-app ./chart \
  --set image.tag=$PROMOTED_TAG \
  --namespace production
```

---

## Explicitly Disallowed Promotion Behaviors

The following promotion patterns are **prohibited** and **prevented by the platform**:

### ❌ No Rebuilds for Production

**Prohibited**:
- Building a new artifact specifically for production
- Compiling code in production deployment pipeline
- Creating production-specific container images

**Why prohibited**: Production artifact must be byte-for-byte identical to tested artifact.

**Enforcement**: Production deployment pipeline has no build stage; only deploys existing artifacts.

---

### ❌ No Skipping Environments

**Prohibited**:
- Promoting directly from dev to production (skipping staging)
- Deploying to production without staging validation
- "Hotfix" deployments that bypass staging

**Why prohibited**: Staging is pre-production validation gate; skipping defeats safety.

**Enforcement**: Production deployment requires staging verification success.

**Exception**: Critical security patches may use expedited promotion with additional approvals (documented separately).

---

### ❌ No Manual Artifact Overrides

**Prohibited**:
- Operator manually specifying artifact tag for production
- Deploying different artifact than validated in staging
- Promoting artifact that failed verification

**Why prohibited**: Breaks traceability and bypasses safety gates.

**Enforcement**: Production deployment uses artifact tag from staging deployment (not manual input).

---

### ❌ No Automatic Production Deployments

**Prohibited**:
- Automatic production deployment on merge to `main`
- Scheduled production deployments without approval
- Production deployment triggered by CI/CD without human intervention

**Why prohibited**: Production changes must be intentional and approved.

**Enforcement**: Production deployment requires `workflow_dispatch` (manual trigger) and GitHub environment approval.

---

## Promotion Workflow (Detailed)

### Step 1: Artifact Deployed and Verified in Staging

```bash
# Deploy to staging (automatic on merge to main)
deploy_to_staging artifact:7a3f9c2

# Verify staging deployment
verify_staging
  ✅ Health checks passed
  ✅ Smoke tests passed (3/3)
  ✅ Dependencies UP
  ✅ No errors in staging logs

# Record verification result
echo "artifact:7a3f9c2 verified in staging at 2024-01-08T15:00:00Z" >> promotion-log.txt
```

---

### Step 2: Promotion Request Initiated

**Trigger**: Platform lead or release manager decides to promote to production.

**Action**: Navigate to GitHub Actions and trigger `workflow_dispatch` for production deployment.

**Input**:
- Target environment: `production`
- Artifact tag: `7a3f9c2` (same as staging)

---

### Step 3: Promotion Eligibility Check

Pipeline validates preconditions:

```yaml
- name: Validate Promotion Eligibility
  run: |
    # Check 1: Artifact immutable
    if [[ "$IMAGE_TAG" == "latest" ]]; then
      echo "❌ BLOCKED: Mutable tag not allowed for production"
      exit 1
    fi
    
    # Check 2: Artifact verified in staging
    STAGING_VERIFIED=$(check_staging_verification $IMAGE_TAG)
    if [[ "$STAGING_VERIFIED" != "PASSED" ]]; then
      echo "❌ BLOCKED: Artifact not verified in staging"
      exit 1
    fi
    
    # Check 3: No critical vulnerabilities
    SCAN_RESULT=$(check_security_scan $IMAGE_TAG)
    if [[ "$SCAN_RESULT" == "CRITICAL_FOUND" ]]; then
      echo "❌ BLOCKED: Critical vulnerabilities detected"
      exit 1
    fi
    
    echo "✅ Artifact eligible for production promotion"
```

**If any check fails, promotion is blocked.**

---

### Step 4: Manual Approval

**GitHub environment protection rule** pauses workflow and requests approval.

**Notification sent to approvers**:
- Slack/email: "Production deployment pending approval for artifact:7a3f9c2"
- Includes: artifact version, staging verification results, approver list

**Approver reviews**:
- Staging deployment history
- Verification results
- Recent production stability
- Deployment window (business hours vs off-hours)

**Approver decision**:
- **Approve**: Production deployment proceeds
- **Reject**: Production deployment canceled

**Approval is logged**:
```json
{
  "artifact": "7a3f9c2",
  "approver": "platform-lead@example.com",
  "approved_at": "2024-01-08T15:05:00Z",
  "environment": "production"
}
```

---

### Step 5: Production Deployment

**Only if approval granted**:

```bash
# Deploy to production (same artifact as staging)
helm upgrade --install my-app ./chart \
  --namespace production \
  --set image.tag=7a3f9c2 \  # Same tag as staging
  --set environment=production

# Wait for rollout
kubectl rollout status deployment/my-app -n production --timeout=5m
```

---

### Step 6: Production Verification

```bash
# Verify production deployment
verify_production
  ✅ Health checks passed
  ✅ Smoke tests passed
  ✅ Traffic routing correct
  ✅ Zero-downtime confirmed

# Record promotion
echo "artifact:7a3f9c2 promoted to production at 2024-01-08T15:10:00Z" >> promotion-log.txt
```

**If verification fails, automatic rollback is triggered.**

---

## Promotion Audit Trail

Every promotion is logged with:

```json
{
  "promotion_id": "prom-12345",
  "artifact": {
    "name": "api-gateway",
    "tag": "7a3f9c2",
    "digest": "sha256:abc123...",
    "source_commit": "7a3f9c29b1e4f8d3a5c6e2f1b9d4a8c7e5f3b2a1"
  },
  "source_environment": "staging",
  "target_environment": "production",
  "promotion_requested_at": "2024-01-08T15:00:00Z",
  "promotion_approved_at": "2024-01-08T15:05:00Z",
  "promotion_completed_at": "2024-01-08T15:10:00Z",
  "approver": "platform-lead@example.com",
  "pipeline_run_id": "67890",
  "verification_results": {
    "staging": "PASSED",
    "production": "PASSED"
  },
  "status": "SUCCESS"
}
```

**Audit log retained for**: 2 years (compliance requirement)

---

## Rollback Is a Promotion

**Rollback** is promoting a previous artifact back to production.

### Rollback Flow

1. **Identify previous working version**:
   ```bash
   kubectl rollout history deployment/my-app -n production
   # Previous version: 6d3a7c9
   ```

2. **Validate rollback target eligibility**:
   - Previous artifact is immutable
   - Previous artifact was verified in production (known-good)

3. **Request rollback approval** (same process as promotion)

4. **Deploy previous artifact**:
   ```bash
   helm upgrade my-app ./chart --set image.tag=6d3a7c9
   ```

5. **Verify rollback success**

6. **Log rollback event** (same audit trail as promotion)

**Rollback is not a bypass; it follows the same approval and audit process.**

---

## Promotion Metrics

Track promotion health:

- **Promotion frequency**: How often artifacts are promoted to production
- **Promotion success rate**: Percentage of promotions that succeed (no rollback)
- **Time to promote**: Duration from staging verification to production deployment
- **Approval duration**: Time from promotion request to approval

**Targets**:
- Promotion frequency: Weekly+ (indicates healthy release cadence)
- Success rate: > 95% (high-quality promotions)
- Time to promote: < 1 day (fast feedback loop)
- Approval duration: < 1 hour (responsive approvers)

---

## Conformance

This promotion model is **mandatory** and **non-negotiable**.

Production deployments that:
- Skip staging environment
- Use artifacts not verified in staging
- Bypass approval gates
- Rebuild artifacts for production

**...are rejected by the platform.**

Promotion discipline ensures production safety.
