# Supported Tooling

This document defines **finalized tooling decisions**, not future options.

## CI/CD Orchestration

### Primary Platform
- **System**: GitHub Actions
- **Version**: GitHub-hosted runners (latest stable)
- **Rationale**: Native integration with source control, declarative workflow definitions, scalable runner infrastructure
- **Supported Features**:
  - Reusable workflows for standardized pipeline stages
  - Matrix builds for multi-environment testing
  - OIDC integration for cloud authentication
  - Artifact and cache management

### Alternative CI Systems
- **None supported**: All pipelines must use GitHub Actions
- **Exception process**: Requires architectural review and explicit approval from platform team

## Cloud Platform

### Primary Provider
- **Provider**: Azure
- **Supported Services**:
  - Azure Kubernetes Service (AKS) for container orchestration
  - Azure Container Registry (ACR) for container image storage
  - Azure DevOps Artifacts (optional, for universal package storage)
  - Azure Key Vault for secret management
- **Rationale**: Enterprise cloud provider with compliance certifications and native integration with CI/CD tooling

### Supported Environments
- **Development**: Dev subscriptions for rapid iteration and testing
- **Test/Staging**: Pre-production subscriptions mirroring production configuration
- **Production**: Production subscriptions with restricted access and change controls

### Multi-Cloud Support
- **Not supported**: Platform is Azure-only
- **Rationale**: Multi-cloud fragmentation increases complexity and reduces enforcement consistency

## Artifact and Container Registries

### Container Registry
- **System**: Azure Container Registry (ACR)
- **Configuration**: Geo-replicated for production, single-region for dev/test
- **Scanning**: Integrated vulnerability scanning with Microsoft Defender
- **Retention**: Tag-based retention policies per environment

### Artifact Registry
- **System**: GitHub Packages
- **Supported Formats**: npm, Maven, NuGet, Docker
- **Rationale**: Co-located with source control for simplified authentication and access control

### Unsupported Registries
- Docker Hub (public images allowed in dev only, production requires ACR mirroring)
- Third-party registries (JFrog Artifactory, Nexus) not supported without exception

## Infrastructure as Code

### Primary Tool
- **Tool**: Terraform
- **Version**: >= 1.6.0
- **State Management**: Azure Storage with state locking
- **Rationale**: Declarative, cloud-agnostic syntax (Azure provider), mature ecosystem
- **Supported Features**:
  - Workspace-based environment isolation
  - Remote backend for state management
  - Terraform Cloud/Enterprise for policy enforcement (future consideration)

### Unsupported IaC Tools
- ARM templates (deprecated in favor of Terraform)
- Pulumi (not supported without architectural review)
- CloudFormation (not applicable for Azure)

## Container Orchestration

### Platform
- **System**: Azure Kubernetes Service (AKS)
- **Supported Versions**: Latest stable and N-1 (rolling upgrades required)
- **Networking**: Azure CNI with network policies
- **Ingress**: NGINX ingress controller with Azure Application Gateway integration

### Deployment Tooling
- **Helm**: Supported for application deployment (Helm 3 only)
- **Kubectl**: Supported for imperative operations (discouraged in pipelines)
- **Kustomize**: Not supported (use Helm for templating)

### Unsupported Orchestrators
- Docker Swarm
- Nomad
- ECS (AWS-specific)

## Security and Compliance

### Secret Management
- **System**: Azure Key Vault
- **Integration**: GitHub Actions OIDC for keyless authentication
- **Rotation**: Automated rotation enforced via platform policies
- **Unsupported**: Hard-coded secrets, environment variables in source control

### Vulnerability Scanning
- **Container Scanning**: Microsoft Defender for Containers
- **Dependency Scanning**: GitHub Dependabot
- **Static Analysis**: SonarQube (self-hosted) or SonarCloud
- **License Compliance**: GitHub Dependency Review

### Policy Enforcement
- **OPA/Gatekeeper**: Kubernetes admission control for runtime policies
- **Azure Policy**: Cloud resource compliance enforcement
- **GitHub Actions Required Workflows**: Enforces pipeline standards across repositories

## Monitoring and Observability

### Pipeline Observability
- **Metrics**: GitHub Actions built-in metrics and workflow insights
- **Logging**: GitHub Actions log retention (90 days standard, extended for compliance)
- **Alerting**: GitHub Notifications for workflow failures

### Application Observability (Platform Scope)
- **Not owned by platform**: Application runtime monitoring is application team responsibility
- **Platform provides**: Infrastructure metrics for AKS clusters and ACR

## Version Control

### Platform
- **System**: GitHub Enterprise
- **Branching Strategy**: Trunk-based development with short-lived feature branches
- **Branch Protection**: Required for `main` branch (pull request reviews, status checks, CODEOWNERS enforcement)
- **Code Review**: Minimum 1 approval required for production-bound changes

### Repository Standards
- **Monorepo**: Not enforced; applications decide structure
- **Repository Templates**: Platform provides CI/CD templates via `.github` repository
- **Commit Signing**: Required for production deployments (verified commits only)

## Language and Build Tooling

### Supported Languages
Platform supports pipelines for:
- **Node.js**: npm, pnpm, yarn
- **Python**: pip, poetry
- **Java**: Maven, Gradle
- **.NET**: dotnet CLI
- **Go**: go build

### Build Tool Constraints
- Application teams select build tools within supported languages
- Custom build tooling requires containerization (platform does not install arbitrary dependencies on runners)

## Unsupported Tools

The following tools are **not supported** without explicit exception:

### CI/CD Systems
- Jenkins (legacy, requires migration to GitHub Actions)
- CircleCI, Travis CI, GitLab CI (external SaaS not approved)

### Cloud Providers
- AWS, GCP (multi-cloud not supported)

### Container Registries
- Docker Hub for production images (dev/test only, with mirroring required)
- Public registries without vulnerability scanning

### Build Tools
- Make (discouraged; use language-native build tools)
- Custom shell scripts for build orchestration (must be containerized or use supported tools)

### Secret Management
- HashiCorp Vault (Azure Key Vault is the standard)
- AWS Secrets Manager (not applicable for Azure)

## Exception Process

Tools not listed as supported require:

1. Architectural review by platform team
2. Security and compliance validation
3. Documented rationale for exception
4. Explicit approval from platform leadership

Exceptions are granted only when:
- No supported alternative exists
- Business criticality justifies additional complexity
- Long-term support and maintenance are committed
