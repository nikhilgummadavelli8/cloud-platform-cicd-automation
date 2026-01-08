# Pipeline Skeleton

## Purpose

The pipeline skeleton (`../.github/workflows/pipeline-skeleton.yml`) is the **canonical implementation** of the CI/CD architecture defined in this folder.

This file exists to:

1. **Prove the architecture is implementable**: The skeleton translates architectural rules into executable code
2. **Serve as the platform contract**: All application pipelines must conform to this structure
3. **Provide enforcement hooks**: The skeleton contains validation logic that prevents architectural violations
4. **Act as a reference implementation**: Application teams extend this skeleton, they do not replace it

## What the Skeleton Enforces

### Mandatory Stages

The skeleton implements all 5 required stages from [pipeline-structure.md](./pipeline-structure.md):

1. **Build**: Generates versioned artifacts and container images
2. **Test**: Executes automated tests (unit, integration)
3. **Scan**: Performs security vulnerability scanning and SBOM generation
4. **Deploy**: Deploys to target environment (dev, staging, or production)
5. **Verify**: Validates deployment success and triggers rollback on failure

**All stages are present. None can be skipped.**

### Stage Ordering

The skeleton enforces the execution order defined in [pipeline-structure.md](./pipeline-structure.md):

```
Validate (branch/environment checks)
         ↓
     Build
         ↓
    ┌────┴────┐
    ↓         ↓
  Test      Scan
    └────┬────┘
         ↓
      Deploy
         ↓
      Verify
```

- **Sequential**: Build → Deploy → Verify
- **Parallel**: Test and Scan run concurrently after Build
- **Blocking**: Each stage must succeed before dependent stages execute

### Branch → Environment Mapping

The skeleton implements the branch and environment rules from [branch-and-promotion-model.md](./branch-and-promotion-model.md):

| Branch Pattern   | Development | Staging | Production |
|------------------|-------------|---------|------------|
| `feature/*`      | ✅ Auto     | ❌      | ❌         |
| `bugfix/*`       | ✅ Auto     | ❌      | ❌         |
| `main`           | ❌          | ✅ Auto | ✅ Manual  |
| `release/v*`     | ❌          | ✅ Auto | ✅ Manual  |
| `hotfix/*`       | ✅ Auto     | ✅ Auto | ✅ Manual  |

**Enforcement mechanism**: The `validate` job checks branch patterns and sets deployment targets. Invalid branches fail immediately.

### Approval Gates

Production deployments require:

- **Manual trigger** via `workflow_dispatch`
- **GitHub environment protection** (configured separately in repository settings)
- **Branch authorization** (only main, release, hotfix allowed)

**Enforcement mechanism**: Production deploy job only runs on manual workflow dispatch, and GitHub environment protection enforces approval.

### Failure Handling

The skeleton implements failure behavior from [execution-and-failure-model.md](./execution-and-failure-model.md):

- **Build/Test/Scan failures**: Hard fail, no retry (deterministic failures)
- **Deploy failures**: Conditional retry for transient errors (not yet implemented in skeleton)
- **Verify failures**: Trigger automatic rollback (placeholder implemented)
- **Timeouts**: Verify stage has 5-minute timeout

## What the Skeleton Intentionally Does Not Do

The skeleton is a **platform contract**, not a working application pipeline.

### Not Included (By Design)

❌ **Real build commands**: No actual compilation, containerization, or artifact generation  
❌ **Actual test execution**: No test framework invocation or coverage reporting  
❌ **Live security scanning**: No integration with Microsoft Defender, Dependabot, or SonarQube  
❌ **Terraform or Helm**: No infrastructure provisioning or Kubernetes deployment  
❌ **OIDC authentication**: No Azure credentials or cloud authentication  
❌ **Secrets management**: No Key Vault integration or secret injection  
❌ **Reusable workflows**: No composite actions or shared workflow templates  

### Why Placeholders?

The skeleton uses **placeholder steps** because:

1. **Architecture before implementation**: We prove the structure is sound before adding complexity
2. **Application-agnostic**: The skeleton applies to Node.js, Python, Java, .NET, or Go applications
3. **Minimal dependencies**: The skeleton runs without external services (ACR, AKS, Key Vault)
4. **Clear separation**: Platform contract (skeleton) vs application logic (future work)

## How Future Pipelines Must Extend the Skeleton

Application teams will create pipelines that:

1. **Import the skeleton structure**: Copy or reference the skeleton as a template
2. **Replace placeholders with real commands**: Add actual build, test, scan, deploy logic
3. **Preserve enforcement hooks**: Keep validation, branch checks, and approval gates intact
4. **Add application-specific stages** (optional): Performance testing, DAST, chaos engineering (in non-blocking positions)

### What Cannot Change

Application pipelines **must not**:

- Remove or reorder mandatory stages
- Skip stages under any circumstances
- Bypass branch validation or environment mapping
- Deploy to production without approval
- Modify failure handling to be less strict

### What Can Be Customized

Application pipelines **may**:

- Replace placeholder build commands with real build logic
- Add application-specific tests or scanning tools
- Customize deployment strategies (blue-green, canary)
- Add optional stages that do not interfere with mandatory stages
- Adjust timeouts within documented limits

## Skeleton Validation

To validate conformance, application pipelines must:

1. **Include all 5 stages**: Build, Test, Scan, Deploy, Verify
2. **Enforce stage ordering**: Same dependency graph as skeleton
3. **Implement branch validation**: Reject unauthorized branches for production
4. **Require approval for production**: Manual trigger + environment protection
5. **Handle failures deterministically**: No "best effort" exception handling

Non-conformant pipelines will not be certified for production use.

## Relationship to Architecture Documents

The skeleton directly implements:

- [pipeline-structure.md](./pipeline-structure.md): Stage definitions and ordering
- [execution-and-failure-model.md](./execution-and-failure-model.md): Failure behavior, retries, rollbacks
- [branch-and-promotion-model.md](./branch-and-promotion-model.md): Branch types, environment mapping, approval gates

**If the skeleton contradicts the architecture documents, the architecture documents are authoritative.**  
The skeleton must be updated to match the architecture, not the other way around.

## Testing the Skeleton

The skeleton can be tested immediately:

1. **Push a feature branch**: Validates development deployment path
2. **Merge to main**: Validates staging deployment path
3. **Manually trigger production**: Validates approval and production deployment path

Expected behavior:

- Feature branches → Build, Test, Scan, Deploy (dev), Verify (dev)
- Main branch → Build, Test, Scan, Deploy (staging), Verify (staging)
- Production trigger → Requires approval, deploys to production, verifies

## Next Steps

After the skeleton is validated:

1. **Day 4**: Replace build placeholders with real Dockerfile and containerization
2. **Day 5**: Integrate Terraform for infrastructure deployment
3. **Day 6**: Add OIDC authentication and Azure integration
4. **Day 7**: Convert skeleton to reusable workflow template
5. **Day 8+**: Application teams create pipelines based on skeleton

The skeleton is the foundation. All future work extends it.
