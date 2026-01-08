# Artifact Management

## Purpose

This folder defines **how artifacts are built, versioned, stored, and deployed** in the CI/CD platform.

Artifacts are the foundation of deployment traceability and supply chain security.

## Core Principles

### Artifacts Are Immutable

Once an artifact is published, it **cannot be modified**.

- Container images are tagged with immutable identifiers (commit SHA, not `latest`)
- Published artifacts cannot be overwritten
- Redeployment uses the same artifact, not a rebuild

**Immutability ensures reproducibility.**

### Environments Consume Artifacts, Not Source Code

Deployments pull **pre-built artifacts**, not source code.

- Source code is compiled during the Build stage
- Artifacts are published to registries (ACR, GitHub Packages)
- Deploy stage retrieves artifacts from registries

**No compilation in production environments.**

### Rebuilding Artifacts for Production Is Prohibited

Production deployments use artifacts that were **tested in lower environments**.

- Dev/staging/production deploy the **same artifact**
- Rebuilding in production bypasses testing and introduces risk
- Artifacts are promoted, not rebuilt

**What is tested is what is deployed.**

## Artifact Standards

Artifacts must conform to platform standards:

- **Type**: Container images, Helm charts, compiled binaries
- **Naming**: Consistent naming conventions
- **Versioning**: Semantic versioning or SHA-based tags (no `latest`)
- **Metadata**: Required metadata embedded in artifact or manifest

Non-conforming artifacts are rejected by the platform.

## Traceability

Every deployment must be traceable:

- **Forward trace**: Commit SHA → Artifact → Environment
- **Reverse trace**: Environment → Artifact → Commit SHA
- **Audit trail**: Pipeline run ID, build timestamp, approver identity

Traceability is **mandatory**, not optional.

## Documents

### [Artifact Standards](./artifact-standards.md)

Defines:
- What qualifies as a valid artifact
- Naming conventions and versioning rules
- Required metadata
- Immutability enforcement

### [Traceability Model](./traceability-model.md)

Defines:
- How artifacts link to commits and pipelines
- How environments trace back to source
- How rollbacks identify the correct artifact
- Audit and compliance requirements

## Enforcement

The platform enforces artifact discipline:

- **No mutable tags**: Tags like `latest` or `dev` are prohibited
- **Metadata validation**: Artifacts without required metadata cannot be deployed
- **Registry scanning**: Only approved registries are permitted
- **Immutability checks**: Overwriting published artifacts is blocked

Non-compliant artifacts do not reach production.

## Artifact Lifecycle

```
Source Code
    ↓
Build Stage (creates artifact)
    ↓
Publish to Registry (immutable)
    ↓
Deploy to Dev (consume artifact)
    ↓
Deploy to Staging (same artifact)
    ↓
Deploy to Production (same artifact)
```

**One artifact, multiple environments.**
