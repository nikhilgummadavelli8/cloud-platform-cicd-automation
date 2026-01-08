# Architectural Assumptions

These assumptions are **non-negotiable** and guide all platform design and automation.

## Pipeline Design Assumptions

### Pipelines Are Declarative

**Assumption**: All pipelines are defined as declarative YAML configurations, not imperative scripts.

**Rationale**:
- Declarative pipelines are version-controlled, reviewable, and auditable
- Imperative scripts obscure intent and make compliance validation impossible
- Platform-provided templates enforce standardization and prevent fragmentation

**Enforcement**: GitHub Actions workflows must use reusable workflows and composite actions; inline shell scripts are limited to glue logic only.

---

### Pipelines Are Idempotent

**Assumption**: Pipeline stages can be re-executed without side effects.

**Rationale**:
- Retries and rollbacks require idempotent operations
- Non-idempotent pipelines cause state drift and unpredictable behavior
- Infrastructure-as-code and containerization inherently support idempotency

**Enforcement**: Deployment stages must use declarative tools (Terraform, Helm) that support state reconciliation.

---

### Promotion Requires Explicit Intent

**Assumption**: Artifacts are promoted between environments only through explicit pipeline triggers, not automatic progression.

**Rationale**:
- Automatic promotion bypasses validation gates and approval workflows
- Explicit promotion ensures accountability and auditability
- Production deployments require manual approval or scheduled releases

**Enforcement**: GitHub Actions environments enforce manual approval for production; no workflow can promote to production without approval gate.

---

## Authentication and Authorization Assumptions

### Authentication Is Identity-Based, Not Secret-Based

**Assumption**: Pipelines authenticate to cloud resources using OIDC and managed identities, not static credentials.

**Rationale**:
- Static credentials (API keys, passwords) create rotation and leakage risks
- Identity-based authentication is auditable and scoped to specific permissions
- OIDC tokens are short-lived and eliminate long-term secret management

**Enforcement**: GitHub Actions workflows use OIDC federation to Azure; static credentials are prohibited in pipeline code.

---

### Least Privilege by Default

**Assumption**: Pipeline identities are granted the minimum permissions required for their specific stage.

**Rationale**:
- Over-privileged pipelines increase blast radius of compromised workflows
- Stage-specific permissions limit lateral movement and unauthorized actions
- Azure RBAC enforces granular permissions per environment

**Enforcement**: Each pipeline stage uses a distinct Azure identity with scoped RBAC roles (e.g., `AcrPush` for build, `AKS Deployer` for deployment).

---

### Production Access Is Restricted by Design

**Assumption**: Direct production access is denied to application teams; all changes flow through CI/CD pipelines.

**Rationale**:
- Unrestricted production access bypasses audit logging and compliance controls
- Pipeline-enforced deployments ensure testing, scanning, and approval gates
- Incident response allows temporary break-glass access with full audit trail

**Enforcement**: Azure RBAC denies write access to production resources for application teams; CI/CD service principals have scoped deployment permissions.

---

## Environment and Deployment Assumptions

### Environments Are Immutable

**Assumption**: Infrastructure and application changes are deployed as new versions, not in-place modifications.

**Rationale**:
- Immutable infrastructure prevents configuration drift and ensures reproducibility
- Blue-green and canary deployments require immutable artifacts
- Rollbacks are accomplished by redeploying previous versions, not reverting changes

**Enforcement**: Terraform replaces resources on configuration changes; Kubernetes deployments use rolling updates with immutable container images.

---

### Environment Parity Is Enforced

**Assumption**: Development, staging, and production environments are structurally identical, differing only in scale and configuration.

**Rationale**:
- Environment-specific behavior introduces untested failure modes in production
- Parity ensures that tests in lower environments validate production readiness
- Infrastructure-as-code enforces consistency across environments

**Enforcement**: Terraform workspaces use identical module definitions; environment-specific variables control scale (node count, instance size) but not architecture.

---

### Deployments Are Zero-Downtime

**Assumption**: Application deployments must support rolling updates without service interruption.

**Rationale**:
- Downtime during deployments is unacceptable for production services
- Kubernetes rolling updates provide zero-downtime by default
- Applications must support graceful shutdown and readiness probes

**Enforcement**: Kubernetes deployments require `readinessProbe` and `livenessProbe`; pipelines validate probe configuration before deployment.

---

## Security and Compliance Assumptions

### All Artifacts Are Scanned Before Deployment

**Assumption**: Container images and dependencies are scanned for vulnerabilities before promotion to production.

**Rationale**:
- Unscanned artifacts introduce known vulnerabilities into production
- Compliance frameworks (PCI-DSS, SOC 2) require vulnerability management
- Scanning results inform fix-or-accept decisions before deployment

**Enforcement**: GitHub Actions workflows include scanning stages; production promotion blocked if critical vulnerabilities are detected.

---

### Secrets Are Never Committed to Source Control

**Assumption**: Secrets, credentials, and API keys are stored in Azure Key Vault and injected at runtime.

**Rationale**:
- Committed secrets are exposed in version history and difficult to rotate
- Key Vault provides centralized secret management with access logging
- OIDC eliminates the need for static pipeline credentials

**Enforcement**: GitHub secret scanning detects committed credentials; pipelines fail if secrets are found in code.

---

### Audit Logging Is Mandatory

**Assumption**: All pipeline executions, deployments, and access to production resources are logged and retained.

**Rationale**:
- Audit logs provide accountability for changes and support incident investigation
- Compliance requires tamper-proof logs for production access
- Centralized logging enables security monitoring and anomaly detection

**Enforcement**: GitHub Actions logs are retained for 90 days; Azure Activity Logs and AKS audit logs are forwarded to Log Analytics.

---

## Scalability and Reliability Assumptions

### Pipelines Scale Horizontally

**Assumption**: Pipeline execution capacity scales by adding GitHub-hosted runners or self-hosted runner pools, not by optimizing individual pipeline performance.

**Rationale**:
- Horizontal scaling is simpler and more predictable than micro-optimizations
- Runner pools provide isolation and dedicated capacity for critical pipelines
- GitHub-hosted runners provide elastic capacity without infrastructure management

**Enforcement**: Self-hosted runner pools are provisioned for high-throughput teams; individual pipelines do not optimize for execution time at the expense of clarity.

---

### Failures Are Expected and Automated

**Assumption**: Pipeline failures are expected; retry logic and automated rollbacks handle transient failures without manual intervention.

**Rationale**:
- Transient failures (network timeouts, API rate limits) are normal in distributed systems
- Automated retries reduce manual toil and improve reliability
- Failed deployments must roll back automatically to maintain service availability

**Enforcement**: Deployment stages include rollback triggers; GitHub Actions supports retry logic for flaky external dependencies.

---

### Observability Is Built In

**Assumption**: Pipeline metrics, logs, and traces are collected and queryable without additional instrumentation.

**Rationale**:
- Platform reliability requires visibility into pipeline execution and failure modes
- Metrics inform capacity planning and SLA tracking
- Debugging requires correlation between pipeline stages and downstream deployments

**Enforcement**: GitHub Actions provides execution metrics; custom workflows export metrics to Azure Monitor for centralized dashboards.

---

## Future-Proofing Assumptions

### Platform Standards Evolve, Not Fragment

**Assumption**: Changes to platform tooling or standards are centrally managed and rolled out uniformly, not adopted piecemeal by individual teams.

**Rationale**:
- Fragmented tooling creates support burden and reduces enforcement consistency
- Centralized evolution ensures that all teams benefit from improvements
- Deprecation of legacy tools requires migration planning and support

**Enforcement**: Platform team controls reusable workflows and templates; teams cannot bypass platform standards without exception approval.

---

### Automation Replaces Manual Processes

**Assumption**: Repeated manual operations are automated; manual intervention is reserved for exception handling only.

**Rationale**:
- Manual processes do not scale and introduce human error
- Automation ensures consistency and auditability
- Platform engineering invests in automation that reduces application team toil

**Enforcement**: Deployment, testing, and scanning stages are fully automated; manual approvals are limited to production promotion gates.

---

### Compliance Is Continuous, Not Periodic

**Assumption**: Compliance validation occurs on every pipeline execution, not as a separate audit process.

**Rationale**:
- Periodic compliance checks allow drift between audits
- Continuous validation ensures that non-compliant changes are rejected before deployment
- Shift-left security reduces remediation costs and time-to-fix

**Enforcement**: Pipelines enforce compliance policies (scanning, SBOM generation, signed commits) as required stages; non-compliant builds do not promote.
