# Production Readiness

This document defines **what "production-ready" means**.

**Production deployments are intentional, gated, and boring.**

---

## Production Readiness Definition

An artifact is **production-ready** if:

1. **Validated in staging** (comprehensive verification passed)
2. **Approved for deployment** (manual approval granted)
3. **Deployed within window** (scheduled deployment time)
4. **Roll back plan exists** (previous version available)
5. **Audit trail complete** (all promotion steps logged)

**All five criteria must be met. No exceptions.**

---

## Mandatory Checks Before Production

Before any production deployment, the platform validates:

### 1. Staging Verification Passed

**Check**: Artifact was deployed to staging and all verification passed.

**Validation**:
```bash
# Query staging verification results
STAGING_VERIFICATION=$(get_verification_status "staging" "$ARTIFACT_TAG")

if [[ "$STAGING_VERIFICATION" != "PASSED" ]]; then
  echo "❌ BLOCKED: Artifact not verified in staging"
  echo "Staging verification status: $STAGING_VERIFICATION"
  exit 1
fi
```

**Failure action**: Production deployment blocked

---

### 2. Staging Soak Time Completed

**Check**: Artifact has been running in staging for minimum duration (default: 1 hour).

**Rationale**: Catch latent issues (memory leaks, performance degradation) before production.

**Validation**:
```bash
STAGING_DEPLOYED_AT=$(get_deployment_time "staging" "$ARTIFACT_TAG")
CURRENT_TIME=$(date +%s)
SOAK_DURATION=$((CURRENT_TIME - STAGING_DEPLOYED_AT))

MIN_SOAK_TIME=3600  # 1 hour in seconds

if [[ $SOAK_DURATION -lt $MIN_SOAK_TIME ]]; then
  echo "❌ BLOCKED: Staging soak time not met"
  echo "Required: $MIN_SOAK_TIME seconds, Actual: $SOAK_DURATION seconds"
  exit 1
fi
```

**Failure action**: Production deployment delayed until soak time met

---

### 3. No Critical Vulnerabilities

**Check**: Security scan shows no critical or high-severity CVEs.

**Validation**:
```bash
SCAN_RESULT=$(get_security_scan "$ARTIFACT_TAG")
CRITICAL_COUNT=$(echo "$SCAN_RESULT" | jq '.critical')

if [[ $CRITICAL_COUNT -gt 0 ]]; then
  echo "❌ BLOCKED: $CRITICAL_COUNT critical vulnerabilities detected"
  echo "Production deployment requires zero critical CVEs"
  exit 1
fi
```

**Failure action**: Production deployment blocked until vulnerabilities patched

---

### 4. Artifact Immutability Verified

**Check**: Artifact tag is immutable and digest matches build-time hash.

**Validation**:
```bash
if [[ "$ARTIFACT_TAG" == "latest" || "$ARTIFACT_TAG" == "prod" ]]; then
  echo "❌ BLOCKED: Mutable tag not allowed for production"
  exit 1
fi

BUILD_DIGEST=$(get_build_digest "$ARTIFACT_TAG")
REGISTRY_DIGEST=$(get_registry_digest "$ARTIFACT_TAG")

if [[ "$BUILD_DIGEST" != "$REGISTRY_DIGEST" ]]; then
  echo "❌ BLOCKED: Artifact digest mismatch (potential tampering)"
  exit 1
fi
```

**Failure action**: Production deployment blocked (security concern)

---

### 5. Change Freeze Compliance

**Check**: Production deployment respects change freeze windows.

**Change freeze periods**:
- During critical business periods (e.g., Black Friday, tax season)
- During incident response (active production issue)
- Outside approved deployment windows

**Validation**:
```bash
CURRENT_DATE=$(date +%Y-%m-%d)

# Check if date is in freeze window
if is_change_freeze "$CURRENT_DATE"; then
  echo "❌ BLOCKED: Production change freeze in effect"
  echo "Deployments paused during critical business period"
  exit 1
fi
```

**Failure action**: Production deployment delayed until freeze lifts

**Exception**: Emergency security patches (requires VP-level approval)

---

## Approval Requirements

Production deployments require **explicit manual approval** from authorized personnel.

### Who Can Approve

**Authorized approvers** (role-based):

| Role | Approval Power | Use Case |
|------|---------------|----------|
| **Platform Lead** | All production deployments | Standard releases |
| **Release Manager** | Scheduled releases | Planned deployments |
| **On-Call SRE** | Emergency deployments | Incident response |
| **VP Engineering** | Change freeze exceptions | Critical security patches |

**Approver must have**:
- Appropriate Azure AD role
- GitHub team membership (`production-approvers`)
- MFA enabled (mandatory)

---

### When Approval Is Required

**Always required**:
- Initial production deployment (first release)
- Promotion from staging to production
- Rollback to previous version
- Configuration changes in production

**Never automatic**:
- Production deployments do not auto-promote from staging
- Merging to `main` does not deploy to production
- Passing staging verification does not deploy to production

---

### How Approval Works

1. **Deployment request initiated**: Engineer triggers `workflow_dispatch` for production

2. **GitHub environment protection**: Workflow pauses and requests approval

3. **Notification sent**: Slack/email to approvers with deployment details

4. **Approver reviews**:
   - Artifact version and source commit
   - Staging verification results
   - Recent production stability
   - Deployment timing (business hours vs off-hours)

5. **Approval decision**:
   - **Approve**: Deployment proceeds
   - **Reject**: Deployment canceled, reason logged

6. **Approval logged**:
   ```json
   {
     "artifact": "7a3f9c2",
     "approver": "platform-lead@example.com",
     "approved_at": "2024-01-08T16:00:00Z",
     "deployment_window": "business-hours",
     "approval_duration_seconds": 300
   }
   ```

---

## Deployment Windows

Production deployments are scheduled, not ad-hoc.

### Standard Deployment Window

**Preferred deployment time**: Tuesday-Thursday, 10:00 AM - 2:00 PM (local time)

**Rationale**:
- Mid-week (not Monday or Friday)
- Business hours (team available for incident response)
- Sufficient runway before weekend

---

### Restricted Windows

**Deployments discouraged or prohibited**:

| Time Period | Restriction | Rationale |
|-------------|-------------|-----------|
| **Friday after 2 PM** | Discouraged | Insufficient time before weekend |
| **Weekends** | Prohibited (except emergencies) | Reduced team availability |
| **Holidays** | Prohibited | Skeleton crew, limited support |
| **After 6 PM** | Discouraged | After-hours deploys increase risk |
| **Change freeze periods** | Prohibited | Business-critical periods |

---

### Emergency Deployment Window

**Emergency deployments** (security patches, critical bugs) allowed **any time** with:
- VP-level approval
- Incident ticket reference
- On-call team notified
- Rollback plan documented

---

## Rollback Expectations

Every production deployment must have a **rollback plan**.

### Rollback Readiness

**Before production deployment**:

1. **Identify rollback target**:
   ```bash
   # Previous working version
   ROLLBACK_TARGET=$(get_previous_production_version)
   echo "Rollback target: $ROLLBACK_TARGET"
   ```

2. **Verify rollback target availability**:
   ```bash
   # Confirm previous artifact exists in registry
   if ! artifact_exists "$ROLLBACK_TARGET"; then
     echo "❌ BLOCKED: Rollback target not available"
     exit 1
   fi
   ```

3. **Document rollback procedure**:
   ```bash
   # Rollback command (pre-generated)
   echo "Rollback command: helm rollback my-app -n production"
   ```

**If rollback target unavailable, deployment is blocked.**

---

### Automated Rollback Triggers

**Automatic rollback** is triggered if:

1. **Production verification fails** (health checks, smoke tests)
2. **Error rate spike** (> 5% errors within 5 minutes post-deployment)
3. **Latency degradation** (p99 latency > 2x baseline)
4. **Pod crash loop** (pods failing to start)

**Automatic rollback flow**:
```bash
if verification_failed || error_rate_spike || latency_spike; then
  echo "🚨 Triggering automatic rollback"
  helm rollback my-app -n production
  verify_rollback_success
  notify_team_urgent
fi
```

---

### Manual Rollback

**Manual rollback** initiated by:
- On-call engineer observing production issue
- Platform lead deciding to revert change
- Approver withdrawing approval post-deployment

**Manual rollback requires**:
- Incident ticket
- Rollback approval (same approver or on-call SRE)
- Rollback verification

---

### Rollback Verification

After rollback:

1. **Verify previous version deployed**:
   ```bash
   CURRENT_VERSION=$(get_production_version)
   if [[ "$CURRENT_VERSION" != "$ROLLBACK_TARGET" ]]; then
     echo "❌ Rollback failed: version mismatch"
     escalate_to_oncall
   fi
   ```

2. **Verify health checks pass**:
   ```bash
   curl -f https://prod.example.com/health/ready || escalate
   ```

3. **Verify traffic restoration**:
   ```bash
   # Confirm production serving traffic normally
   check_traffic_metrics || escalate
   ```

**If rollback verification fails, escalate to on-call team immediately.**

---

## Production Deployment Checklist

Before initiating production deployment, verify:

- [ ] **Staging verified**: Artifact passed comprehensive staging verification
- [ ] **Soak time met**: Artifact ran in staging for minimum 1 hour
- [ ] **No vulnerabilities**: Security scan shows zero critical CVEs
- [ ] **Immutable artifact**: Tag is commit SHA, digest verified
- [ ] **Deployment window**: Current time is within approved window
- [ ] **Approval obtained**: Authorized approver granted approval
- [ ] **Rollback plan**: Previous version identified and available
- [ ] **Team notified**: Relevant teams aware of pending deployment
- [ ] **Monitoring ready**: Dashboards and alerts configured

**All checkboxes must be checked before production deployment.**

---

## Post-Deployment Verification (Production)

After production deployment completes:

### Immediate Verification (0-5 minutes)

- **Health checks**: `/health/live` and `/health/ready` return 200 OK
- **Pod status**: All pods running and ready
- **Logs**: No errors or warnings in application logs
- **Traffic**: Production receiving and serving traffic normally

---

### Extended Verification (5-30 minutes)

- **Error rate**: < 1% error rate (baseline)
- **Latency**: p99 latency within 10% of baseline
- **Throughput**: Request volume matches expected traffic
- **Dependencies**: All downstream services healthy

---

### Continuous Monitoring (30 minutes - 24 hours)

- **Memory usage**: No memory leaks (stable over time)
- **CPU usage**: No CPU spikes or sustained high usage
- **Disk usage**: No unexpected disk growth
- **Business metrics**: Key business metrics (orders, signups) normal

**If any verification fails, consider rollback.**

---

## Production Deployment Metrics

Track production deployment health:

- **Deployment frequency**: How often production is deployed (weekly+ target)
- **Deployment success rate**: Percentage of deployments without rollback (> 95% target)
- **Mean time to deploy**: Duration from approval to production live (< 30 min target)
- **Rollback frequency**: Percentage of deployments rolled back (< 5% target)
- **Change failure rate**: Percentage of deployments causing incidents (< 3% target)

**These metrics drive platform improvements.**

---

## Incident Response Integration

Production deployments integrate with incident response:

### If Deployment Causes Incident

1. **Automatic rollback** triggers (if verification fails)
2. **Incident ticket** auto-created
3. **On-call paged** (high-severity alert)
4. **Post-mortem required** (5-whys analysis)

---

### If Incident Occurs During Deployment

1. **Pause deployment** (if rollout in progress)
2. **Assess impact**: Is deployment the cause?
3. **If deployment-related**: Immediate rollback
4. **If unrelated**: Continue deployment or pause based on severity

---

## Conformance

Production readiness requirements are **mandatory** and **non-negotiable**.

Production deployments that:
- Skip staging verification
- Bypass approval gates
- Deploy outside approved windows (non-emergency)
- Lack rollback plans

**...are rejected by the platform.**

Production is protected by design, not heroics.
