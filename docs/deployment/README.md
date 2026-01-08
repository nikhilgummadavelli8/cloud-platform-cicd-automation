# Deployment

## Purpose

This folder defines **how deployments are executed and verified** in the CI/CD platform.

Deployments are not just "code pushed to a server." They are **automated, verified, repeatable operations** with deterministic success criteria.

## Core Principles

### Deployments Are Automated

No manual intervention is required for deployment execution.

- Deployments are triggered by pipelines, not humans
- Configuration is injected automatically based on environment
- No manual configuration changes post-deployment
- No SSH access required to deploy

**Manual deployments are prohibited.**

### Deployments Are Idempotent

Re-running a deployment with the same artifact produces the same result.

- Deploying the same artifact twice does not break the system
- Deployment scripts are safe to re-run (no destructive side effects)
- State convergence: deployment brings system to desired state

**Deployments can be safely retried.**

### Deployments Are Environment-Aware

Deployments automatically adapt to target environment.

- Environment configuration injected at deploy time (not build time)
- Same artifact deployed to dev, staging, production with different config
- No environment-specific builds or compilation

**One artifact, multiple environments.**

### Configuration Is Externalized from Artifacts

Artifacts contain code, not environment-specific configuration.

- Configuration stored in environment variables, config files, Key Vault
- Artifacts are environment-agnostic
- Changing configuration does not require rebuilding artifacts

**Artifacts are portable across environments.**

### Verification Is Mandatory

Deployment completion ≠ deployment success.

- Every deployment is followed by verification
- Verification checks health, readiness, functionality
- Failed verification = failed deployment

**A deployment without verification is considered failed.**

## Deployment Types

### Non-Production Deployments

**Target environments**: Development, Testing, Staging

- Automated deployment on push/merge
- Verification required but less stringent than production
- Rollback on verification failure

### Production Deployments

**Target environment**: Production

- Manual approval required
- Blue-green or canary deployment strategy
- Comprehensive verification (health, traffic, metrics)
- Automatic rollback on verification failure

*Production deployments are covered separately. This folder focuses on non-prod.*

## Deployment Documents

### [Non-Prod Deployment Model](./non-prod-deployment-model.md)

Defines:
- Supported non-prod environments
- How configuration is injected
- Idempotency expectations
- Deployment ordering and dependencies

### [Verification and Health Checks](./verification-and-health-checks.md)

Defines:
- What constitutes deployment success
- Required health checks
- Failure conditions and timeouts
- Smoke test requirements

## Deployment → Verification Separation

Deployment and verification are **separate stages** in the pipeline.

```
Deploy Stage
    ↓
Verify Stage (mandatory)
    ↓
Success (eligible for promotion) or Failure (rollback)
```

**Why separate?**

- Deployment: "Did the code get deployed?"
- Verification: "Is the deployed code actually working?"

These are distinct questions requiring distinct validation.

## Conformance

This deployment model is **mandatory** and **non-negotiable**.

Non-prod deployments that:
- Require manual intervention
- Skip verification
- Use environment-specific builds

**...are rejected by the platform.**

Deployment discipline is architectural, not optional.
