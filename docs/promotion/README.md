# Promotion

## Purpose

This folder defines **how artifacts are promoted across environments** and what makes production deployments different.

Promotion is not deployment. This distinction is fundamental.

## Core Principles

### Promotion Is Moving the Same Artifact

Promotion does not rebuild or modify artifacts.

- Same artifact deployed to dev is promoted to staging
- Same artifact validated in staging is promoted to production
- Artifact integrity maintained across all environments

**Promotion is artifact progression, not recreation.**

### Production Is Not "Just Another Environment"

Production has unique constraints and protections.

- **Manual approval required** (no automatic prod deployments)
- **Enhanced verification** (more comprehensive than staging)
- **Deployment windows** (scheduled, not ad-hoc)
- **Rollback readiness** (previous version always available)
- **Audit logging** (every prod change tracked)

**Production is protected by design, not discipline.**

### Promotion Is Explicit, Gated, and Auditable

No artifact reaches production by accident.

- **Explicit**: Manual approval required, not automatic progression
- **Gated**: Preconditions validated before promotion allowed
- **Auditable**: Every promotion logged with approver identity, timestamp, artifact version

**Implicit promotion is architecturally impossible.**

## Promotion vs Deployment

These are distinct operations with different purposes:

| Aspect | Deployment | Promotion |
|--------|------------|-----------|
| **What** | Install artifact in environment | Move artifact between environments |
| **When** | Automatic on push/merge | Manual approval required (for prod) |
| **Who** | Pipeline (automated) | Approver (human) |
| **Preconditions** | Build + test + scan passed | Deployment + verification passed |
| **Artifact** | Newly built | Previously deployed and verified |
| **Risk** | Lower (non-prod) | Higher (production) |

**Key distinction**: Deployment executes installation; promotion validates readiness.

## Platform Ownership

Promotion controls are **platform-owned**, not application-owned.

Application teams:
- Cannot bypass approval gates
- Cannot skip environments (dev → prod directly)
- Cannot modify promotion criteria
- Cannot override promotion controls

Platform team:
- Defines promotion rules
- Enforces approval requirements
- Audits all production promotions
- Rejects non-compliant promotion attempts

**Promotion governance is non-negotiable.**

## Documents

### [Promotion Model](./promotion-model.md)

Defines:
- What qualifies an artifact for promotion
- Promotion flow and preconditions
- Disallowed promotion behaviors
- Promotion vs deployment distinction

### [Production Readiness](./production-readiness.md)

Defines:
- Mandatory checks before production
- Approval requirements (who, when, how)
- Deployment windows and schedules
- Rollback expectations and procedures

## Conformance

These promotion controls are **mandatory** and **non-negotiable**.

Production deployments that:
- Skip approval gates
- Bypass environment progression
- Use artifacts not validated in staging

**...are rejected by the platform.**

Production is protected architecturally, not procedurally.
