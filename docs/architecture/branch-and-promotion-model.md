# Branch and Promotion Model

This document defines **branch types, environment mapping, and promotion rules**.

Accidental production deployments are **architecturally impossible** under this model.

## Branch Types

The platform recognizes the following branch types:

### Feature Branches

**Pattern**: `feature/*`, `bugfix/*`, `hotfix/*`

**Purpose**: Short-lived branches for development work.

**Deployment Target**: Development environment only.

**Pipeline Behavior**:
- All pipeline stages execute (Build, Test, Scan, Deploy, Verify)
- Deploy to dedicated preview environment or shared dev environment
- Automatic deployment on every push
- No approval required

**Merge Requirements**:
- All pipeline stages must pass
- Minimum 1 code review approval
- Up-to-date with target branch (main)

**Lifecycle**: Deleted immediately after merge.

---

### Main Branch

**Pattern**: `main`

**Purpose**: Primary integration branch representing production-ready code.

**Deployment Target**: Test (staging) environment automatically, Production with approval.

**Pipeline Behavior**:
- All pipeline stages execute on every commit
- **Automatic deployment to test/staging** after all stages pass
- **Manual approval required** before production deployment
- Commits to main typically come from merged pull requests

**Protection Rules**:
- Direct commits to main are **prohibited** (via branch protection)
- All changes must arrive via pull request
- Required status checks: Build, Test, Scan must pass
- Minimum 1 approval required
- Enforce linear history (no merge commits)

**Production Promotion**: Requires explicit manual trigger with approval.

---

### Release Branches (Optional)

**Pattern**: `release/v*` (e.g., `release/v1.2.0`)

**Purpose**: Stabilization branch for coordinated releases.

**Deployment Target**: Staging and production.

**Pipeline Behavior**:
- All pipeline stages execute
- Deploy to staging automatically
- Production deployment requires manual approval
- Only bug fixes allowed (no new features)

**Lifecycle**: Maintained for release support window, then archived.

**Note**: Release branches are optional. Most applications promote directly from main.

---

### Hotfix Branches

**Pattern**: `hotfix/*`

**Purpose**: Emergency fixes for production issues.

**Deployment Target**: All environments (fast-tracked).

**Pipeline Behavior**:
- All pipeline stages execute (no stage skipping)
- Deploy to dev and staging automatically
- Production deployment requires manual approval **and** incident ticket reference

**Merge Requirements**:
- Same as feature branches (tests, scans, approval)
- Must reference active incident or ticket
- Post-merge: hotfix must be back-merged to main

**Prohibited**: Skipping stages "because it's urgent". Hotfixes follow the same pipeline structure.

---

## Branch → Environment Mapping

This table defines which branches deploy to which environments:

| Branch Pattern   | Development | Test/Staging | Production |
|------------------|-------------|--------------|------------|
| `feature/*`      | ✅ Automatic | ❌ No        | ❌ No      |
| `bugfix/*`       | ✅ Automatic | ❌ No        | ❌ No      |
| `main`           | ❌ No        | ✅ Automatic | ✅ Manual  |
| `release/v*`     | ❌ No        | ✅ Automatic | ✅ Manual  |
| `hotfix/*`       | ✅ Automatic | ✅ Automatic | ✅ Manual  |

### Key Rules

- **Development**: Only feature, bugfix, and hotfix branches deploy here
- **Test/Staging**: Only main, release, and hotfix branches deploy here
- **Production**: Only main, release, and hotfix branches deploy here, **with approval**

---

## Environment Promotion Rules

### Development → Test/Staging

**Trigger**: Pull request merged to main.

**Requirements**:
- All pipeline stages passed in development (on feature branch)
- Code review approval
- No failing tests or critical vulnerabilities

**Approval**: Not required (automatic).

**Deployment**: Automatic after merge to main.

---

### Test/Staging → Production

**Trigger**: Manual promotion workflow.

**Requirements**:
- All pipeline stages passed in staging environment
- Manual approval from authorized approver
- Deployment window (production deployments allowed only during approved hours)
- Change ticket reference (for audit trail)

**Approval**: **Always required**. No exceptions.

**Approvers**: Application team lead, platform engineering, SRE on-call (minimum 1 approval).

**Deployment**: Manual trigger after approval granted.

---

## Production Deployment Rules

### Prerequisites for Production Deployment

All of the following must be true:

1. ✅ **All stages passed in staging** (Build, Test, Scan, Deploy, Verify)
2. ✅ **Manual approval granted** by authorized approver
3. ✅ **Deployment window**: Within approved hours (default: weekday business hours, excluding holidays)
4. ✅ **Change ticket exists** (references change management system)
5. ✅ **No active production incidents** (deployments paused during incidents)

If any prerequisite is not met, production deployment is **blocked**.

---

### Deployment Window

**Allowed Times** (default, configurable per application):
- **Weekdays**: 10:00 AM - 4:00 PM (local timezone)
- **Weekends**: Not allowed (requires exception)
- **Holidays**: Not allowed (requires exception)

**Rationale**: Deployments during business hours ensure engineers are available to respond to issues.

**Exceptions**: Emergency hotfixes may deploy outside window with incident ticket and exec approval.

---

### Approval Requirements

**Approvers** (minimum 1 required):
- Application team lead
- Platform engineering representative
- SRE on-call (for high-risk deployments)

**Approval Expiration**: Approvals expire after 24 hours. Re-approval required if deployment is delayed.

**Approval Cannot Be Bypassed**: No override mechanism exists. Production deployments without approval are architecturally prevented.

---

## Explicitly Disallowed Behaviors

The following behaviors are **prohibited** and prevented by platform enforcement:

### ❌ Direct Commits to Main

**Prohibited**: Committing directly to main branch without pull request.

**Enforcement**: Branch protection rules reject direct pushes.

**Rationale**: All changes must be reviewed and tested in development environment first.

---

### ❌ Production Deployments from Feature Branches

**Prohibited**: Deploying feature branches to production.

**Enforcement**: GitHub Actions environments restrict production deployments to main, release, and hotfix branches only.

**Rationale**: Production receives only thoroughly tested, reviewed code from main branch.

---

### ❌ Bypassing Approval Gates

**Prohibited**: Deploying to production without manual approval.

**Enforcement**: GitHub Actions environment protection rules require approval; no override.

**Rationale**: Human review prevents accidental or malicious production deployments.

---

### ❌ Skipping Staging Environment

**Prohibited**: Deploying directly to production without staging validation.

**Enforcement**: Production pipelines verify that staging deployment succeeded first.

**Rationale**: Staging validates changes in production-like environment before production risk.

---

### ❌ Deploying Unscanned Artifacts

**Prohibited**: Deploying container images that have not passed vulnerability scanning.

**Enforcement**: Deploy stage requires scan stage completion; hard dependency.

**Rationale**: Vulnerabilities must be identified before production deployment.

---

### ❌ Rollback Without Pipeline

**Prohibited**: Manually rolling back deployments outside CI/CD pipeline.

**Enforcement**: Application teams do not have write access to production infrastructure.

**Rationale**: Rollbacks must be tracked, audited, and versioned.

---

## Environment-Specific Behavior

### Development Environment

- **Auto-deploy**: Yes
- **Approval required**: No
- **Rollback**: Manual (via re-deployment)
- **Deployment window**: 24/7
- **Failure impact**: Low (isolated environment)

**Purpose**: Rapid iteration and testing.

---

### Test/Staging Environment

- **Auto-deploy**: Yes (from main, release, hotfix branches)
- **Approval required**: No
- **Rollback**: Automatic on verify failure
- **Deployment window**: 24/7
- **Failure impact**: Medium (blocks production promotion)

**Purpose**: Validate production-readiness in production-like environment.

---

### Production Environment

- **Auto-deploy**: No (manual trigger only)
- **Approval required**: Yes (always)
- **Rollback**: Automatic on verify failure
- **Deployment window**: Restricted (business hours)
- **Failure impact**: High (customer-facing)

**Purpose**: Serve customer traffic with maximum stability.

---

## Promotion Workflow

### Standard Promotion Flow

```
Developer Branch (feature/*)
         ↓
    Pull Request
         ↓
   Code Review + CI
         ↓
    Merge to Main
         ↓
Deploy to Staging (automatic)
         ↓
  Verify in Staging
         ↓
Manual Approval Gate
         ↓
Deploy to Production (manual trigger)
         ↓
  Verify in Production
         ↓
   Monitor and Close
```

### Hotfix Promotion Flow

```
  Hotfix Branch (hotfix/*)
         ↓
Deploy to Dev (automatic)
         ↓
Deploy to Staging (automatic)
         ↓
    Verify Hotfix
         ↓
Incident Ticket + Manual Approval
         ↓
Deploy to Production (manual trigger)
         ↓
  Verify in Production
         ↓
  Back-Merge to Main
```

---

## Concurrency Rules

### Per-Environment Concurrency

**Rule**: Only one deployment per environment at a time.

**Enforcement**: GitHub Actions concurrency groups.

**Behavior**:
- New deployment to same environment cancels previous in-progress deployment (dev/staging)
- Production deployments queue (do not cancel in-progress deployment)

---

### Cross-Environment Concurrency

**Rule**: Deployments to different environments can run in parallel.

**Example**: Dev and staging can deploy simultaneously, but staging and production cannot.

**Rationale**: Lower environments do not block production deployments, but production requires staging success.

---

## Audit and Compliance

All deployments are logged with:

- **Timestamp** of deployment
- **Deployer identity** (GitHub user for manual approvals, bot for automatic)
- **Branch and commit SHA** deployed
- **Environment** targeted
- **Approval records** (who approved, when)
- **Deployment outcome** (success, failure, rollback)

**Retention**: Deployment audit logs retained for 2 years (compliance requirement).

---

## Exception Process

### Deployment Outside Window

**Requires**:
1. Active incident ticket
2. Approval from application team lead **and** executive sponsor
3. Documented business justification
4. Post-deployment review

**Granted for**: Emergency hotfixes, critical security patches.

---

### Bypass Staging Environment

**Requires**:
1. Written justification (why staging validation is not applicable)
2. Approval from platform engineering lead
3. Additional manual approval from SRE team
4. Expiration date (exception is time-limited)

**Granted for**: Extremely rare (e.g., infrastructure migrations).

---

## Conformance

This branch and promotion model is **mandatory**.

Non-conformant behaviors (deploying feature branches to production, bypassing approvals) are prevented through:

- Branch protection rules
- Environment protection rules
- RBAC on cloud infrastructure
- Pipeline validation checks

**Platform team does not rely on developer discipline. Enforcement is architectural.**
