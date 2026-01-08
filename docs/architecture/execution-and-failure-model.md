# Execution and Failure Model

This document defines **how pipelines behave under failure conditions**.

No "best effort" language. Failures are handled deterministically.

## Stage Failure Behavior

### Build Stage Failure

**Trigger**: Compilation error, dependency resolution failure, artifact generation failure.

**Pipeline Action**:
- ❌ **Hard fail**: Pipeline terminates immediately
- 🚫 **No retry**: Build failures are deterministic; retries will not succeed
- 📢 **Notification**: Commit author receives immediate failure notification
- 🔒 **Blocking**: Pull request cannot be merged until build succeeds

**Rollback**: Not applicable (no deployment occurred).

**Recovery**: Developer must fix code and push new commit.

---

### Test Stage Failure

**Trigger**: Test assertion failure, timeout, test execution error.

**Pipeline Action**:
- ❌ **Hard fail**: Pipeline terminates immediately
- 🚫 **No retry**: Test failures indicate application defects, not transient issues
- 📢 **Notification**: Commit author and PR reviewers receive failure notification with test report link
- 🔒 **Blocking**: Pull request cannot be merged until tests pass

**Rollback**: Not applicable (no deployment occurred).

**Recovery**: Developer must fix failing tests or underlying code and push new commit.

**Non-Deterministic Test Failures**: Flaky tests are treated as pipeline defects and must be fixed or quarantined. Flaky tests do not justify retry logic.

---

### Scan Stage Failure

**Trigger**: Critical or high-severity CVE detected in container image or dependencies.

**Pipeline Action**:
- ❌ **Hard fail**: Pipeline terminates immediately
- 🚫 **No retry**: Vulnerabilities will not disappear on retry
- 📢 **Notification**: Commit author, security team, and application team receive vulnerability report
- 🔒 **Blocking**: Pull request cannot be merged until vulnerabilities are remediated or accepted

**Severity Thresholds**:
- **Critical vulnerabilities**: Always block deployment
- **High vulnerabilities**: Block production deployment, warn for dev/test
- **Medium/Low vulnerabilities**: Log but do not block

**Rollback**: Not applicable (no deployment occurred).

**Recovery**: Developer must update dependencies or fix vulnerabilities and push new commit.

**Exception Process**: Security team may grant temporary vulnerability acceptance with documented risk and remediation timeline.

---

### Deploy Stage Failure

**Trigger**: Infrastructure provisioning failure, deployment timeout, resource conflict.

**Pipeline Action**:
- ❌ **Fail current deployment**: Deployment is aborted
- 🔄 **Conditional retry**:
  - **Transient failures** (network timeout, API rate limit): Retry up to 3 times with exponential backoff
  - **Deterministic failures** (quota exceeded, invalid configuration): Hard fail, no retry
- 📢 **Notification**: Application team and platform on-call receive immediate notification
- 🔙 **Rollback**: Not triggered (deployment did not complete)

**Retry Logic**:
1. **Attempt 1**: Immediate
2. **Attempt 2**: After 30 seconds (if failure is retryable)
3. **Attempt 3**: After 60 seconds (if failure is retryable)
4. **Terminal failure**: After 3 failed attempts

**Rollback**: Not applicable (deployment never completed successfully).

**Recovery**:
- **Transient failures**: Retry or re-run pipeline
- **Quota/permissions failures**: Platform team resolves infrastructure issue, then re-run pipeline
- **Configuration failures**: Developer fixes configuration and pushes new commit

---

### Verify Stage Failure

**Trigger**: Health check failure, smoke test failure, post-deployment validation failure.

**Pipeline Action**:
- ❌ **Immediate rollback**: Automatically revert to previous working version
- 🔄 **No retry**: Verification failure indicates deployment issue, not transient network problem
- 📢 **Notification**: Application team, platform on-call, and SRE team receive critical alert
- 🚨 **Incident**: Production verify failures trigger incident response workflow

**Rollback Procedure**:
1. **Immediately** redeploy previous working container image version
2. **Validate** rollback succeeded via health checks
3. **Confirm** application is serving traffic correctly
4. **Log** incident with failure details

**Timeout**: Verify stage must complete within **5 minutes** or trigger automatic rollback.

**Recovery**: Developer must fix deployment issue, validate in lower environment, then retry production deployment.

---

## Transient vs Terminal Failures

### Transient Failures (Retryable)
These failures may resolve on retry:

- **Network timeouts** connecting to external services
- **API rate limits** from cloud provider or external dependencies
- **Temporary resource unavailability** (e.g., image registry momentarily unavailable)

**Retry Policy**: Up to 3 attempts with exponential backoff (30s, 60s).

---

### Terminal Failures (Not Retryable)
These failures will not resolve on retry:

- **Code compilation errors**
- **Test assertion failures**
- **Critical security vulnerabilities**
- **Quota or permission errors**
- **Invalid configuration or manifests**
- **Resource conflicts** (e.g., duplicate resource names)

**Retry Policy**: No retry. Pipeline terminates immediately.

---

## Notification Requirements

### Failure Notifications Must Include

All failure notifications contain:

- **Pipeline name and run ID**
- **Failed stage** (Build, Test, Scan, Deploy, Verify)
- **Failure reason** (error message, exit code)
- **Commit SHA and author**
- **Link to logs** for detailed troubleshooting
- **Timestamp** of failure

### Notification Targets by Stage

| Stage  | Notify On Failure |
|--------|-------------------|
| Build  | Commit author, PR reviewers |
| Test   | Commit author, PR reviewers |
| Scan   | Commit author, security team, application team lead |
| Deploy | Application team, platform on-call |
| Verify | Application team, platform on-call, SRE team (production only) |

### Notification Channels

- **GitHub**: Pull request comment with failure summary and logs link
- **Slack/Teams**: Alert to application team channel for Deploy/Verify failures
- **PagerDuty**: Critical alert for production Verify failures only

---

## Rollback Behavior

### Automatic Rollback Triggers

Rollback is **automatically triggered** when:

- **Verify stage fails** in any environment
- **Health checks fail** after deployment
- **Deployment exceeds timeout** (15 minutes for standard deployments)

### Rollback Procedure

1. **Identify previous working version**: Query deployment history for last successful deployment
2. **Redeploy previous version**: Use identical deployment procedure (Helm rollback, Terraform revert)
3. **Validate rollback success**: Execute Verify stage against rolled-back version
4. **Confirm traffic restoration**: Ensure application is serving requests
5. **Log rollback event**: Record rollback reason, timestamp, and version change

### Rollback Failure

If rollback itself fails:

- 🚨 **Escalate to platform on-call immediately**
- 🚫 **Do not retry automatically** (manual intervention required)
- 📢 **Declare incident** (production environments only)
- 🛠️ **Manual recovery** by platform team

---

## Terminal Failure Definition

A **terminal failure** is one that cannot be resolved through retry or rollback.

### Terminal Failure Scenarios

- **Rollback fails** (cannot restore previous version)
- **Infrastructure failure** prevents deployment (e.g., cluster unreachable)
- **Critical security vulnerability** with no mitigation available
- **Data corruption** during deployment

### Terminal Failure Response

1. **Halt all deployments** to affected environment
2. **Escalate to platform engineering and SRE teams**
3. **Declare incident** (Severity 1 for production, Severity 2 for staging)
4. **Manual recovery** with full incident post-mortem

---

## Timeout Policies

All stages have maximum execution time limits.

| Stage  | Timeout | Action on Timeout |
|--------|---------|-------------------|
| Build  | 30 minutes | Hard fail, no retry |
| Test   | 20 minutes | Hard fail, no retry |
| Scan   | 15 minutes | Hard fail, no retry |
| Deploy | 15 minutes | Retry once, then hard fail |
| Verify | 5 minutes  | Automatic rollback |

**Rationale**: Timeouts prevent hung pipelines from blocking other work. Long-running stages indicate pipeline inefficiency or infrastructure issues.

---

## Concurrency and Queueing Behavior

### Concurrent Deployments to Same Environment

**Rule**: Only one deployment per environment is allowed at a time.

**Enforcement**: GitHub Actions concurrency groups prevent parallel deployments.

**Behavior**: If deployment is already in progress, new pipeline run waits in queue.

**Timeout**: Queued pipelines expire after 60 minutes.

---

### Multiple Commits in Quick Succession

**Rule**: Only the latest commit is deployed. Previous queued deployments are cancelled.

**Rationale**: Deploying stale commits wastes resources and creates confusion.

---

## Failure Rate Monitoring

Platform monitors pipeline failure rates and triggers alerts when thresholds are exceeded.

### Failure Rate Thresholds

| Environment | Failure Rate Threshold | Action |
|-------------|------------------------|--------|
| Dev         | > 50% over 24 hours    | Warning to application team |
| Test        | > 30% over 24 hours    | Review by platform team |
| Production  | > 10% over 24 hours    | Incident declared |

**Rationale**: High failure rates indicate systemic issues with application code, tests, or infrastructure.

---

## Manual Intervention Policy

### When Manual Intervention Is Allowed

- **Production approval gate**: Required before production deployment
- **Terminal failure recovery**: After rollback itself fails
- **Security exception approval**: For vulnerability acceptance

### When Manual Intervention Is Prohibited

- **Bypassing failing tests** "just this once"
- **Deploying without scanning**
- **Skipping verification** to "save time"
- **Manually deploying to production** outside the pipeline

**Enforcement**: Production infrastructure access is denied to application teams. All changes flow through CI/CD.

---

## Conformance

This failure model is **mandatory** and **non-negotiable**.

Pipelines that implement different failure handling (e.g., ignoring scan failures, skipping rollback) are non-conformant and will not be certified for production use.
