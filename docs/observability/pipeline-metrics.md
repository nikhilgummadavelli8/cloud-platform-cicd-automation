# Pipeline Metrics

**Status**: Mandatory  
**Enforcement**: All pipelines must emit these metrics  
**Last Updated**: 2026-01-08

## Purpose

This document defines the **non-negotiable metrics** that every CI/CD pipeline must measure and emit. These metrics enable:

- Performance monitoring and optimization
- Failure trend analysis
- SLO/SLA tracking
- Capacity planning
- Platform health visibility

## Metric Categories

### 1. Pipeline-Level Metrics

Metrics that describe the overall pipeline execution.

#### Pipeline Duration

**Metric**: `pipeline_duration_seconds`  
**Type**: Gauge  
**Description**: Total time from pipeline start to completion

**Labels**:
- `branch`: Branch that triggered the pipeline
- `trigger`: Event type (push, pull_request, workflow_dispatch)
- `result`: Pipeline outcome (success, failure, cancelled)

**Example values**:
- Feature branch build: 180-300 seconds
- Main branch deployment: 600-900 seconds
- Production deployment: 900-1200 seconds

**Why it matters**: Identifies bottlenecks, tracks optimization efforts, enables capacity planning.

---

#### Pipeline Success Rate

**Metric**: `pipeline_executions_total`  
**Type**: Counter  
**Description**: Total number of pipeline executions

**Labels**:
- `branch_pattern`: main, feature/*, release/*, hotfix/*
- `result`: success, failure
- `failure_stage`: (if failed) validate, build, test, scan, deploy, verify

**Calculation**:
```
success_rate = count(result=success) / count(total)
```

**Target SLO**: >95% success rate for main branch over 7 days

**Why it matters**: Platform reliability indicator, helps identify chronic issues.

---

#### Trigger Source Distribution

**Metric**: `pipeline_triggers_total`  
**Type**: Counter  
**Description**: Count of pipeline runs by trigger type

**Labels**:
- `event`: push, pull_request, workflow_dispatch, schedule

**Why it matters**: Understand pipeline usage patterns, detect unexpected triggers.

---

### 2. Stage-Level Metrics

Metrics for each pipeline stage (validate, build, test, scan, deploy, verify).

#### Stage Duration

**Metric**: `stage_duration_seconds`  
**Type**: Gauge  
**Description**: Execution time for each stage

**Labels**:
- `stage`: validate, build, test, scan, deploy-dev, deploy-staging, deploy-production, verify-dev, verify-staging, verify-production
- `result`: success, failure, skipped

**Example values by stage**:
- Validate: 5-15 seconds
- Build: 60-180 seconds
- Test: 30-120 seconds
- Scan: 45-90 seconds
- Deploy: 30-60 seconds per environment
- Verify: 60-180 seconds (includes wait time)

**Why it matters**: Identifies slow stages, tracks optimization impact, enables parallel execution decisions.

---

#### Stage Execution Count

**Metric**: `stage_executions_total`  
**Type**: Counter  
**Description**: Number of times each stage executed

**Labels**:
- `stage`: (same as above)
- `result`: success, failure, skipped

**Why it matters**: Confirms stage execution frequency, identifies skip patterns.

---

### 3. Failure Categorization Metrics

Metrics that classify pipeline failures for root cause analysis.

#### Failure by Stage

**Metric**: `pipeline_failures_by_stage_total`  
**Type**: Counter  
**Description**: Count of failures categorized by the stage that failed

**Labels**:
- `stage`: validate, build, test, scan, deploy, verify
- `environment`: (for deploy/verify) dev, staging, production

**Example use cases**:
- High `test` failures → Test stability issues
- High `scan` failures → Security vulnerabilities in dependencies
- High `verify-production` failures → Deployment quality issues

**Why it matters**: Enables targeted improvement efforts, identifies systemic issues.

---

#### Test Failure Details

**Metric**: `test_failures_total`  
**Type**: Counter  
**Description**: Count of test failures (when tests run)

**Labels**:
- `test_type`: unit, integration, smoke
- `exit_code`: (numeric exit code if available)

**Why it matters**: Distinguishes between test infrastructure failures vs actual test failures.

---

#### Security Scan Blocks

**Metric**: `scan_blocks_total`  
**Type**: Counter  
**Description**: Count of pipelines blocked due to security scan failures

**Labels**:
- `severity`: critical, high, medium, low
- `block_reason`: critical_vuln, policy_violation, license_issue

**Why it matters**: Security posture visibility, tracks vulnerability introduction rate.

---

### 4. Promotion and Deployment Metrics

Metrics related to artifact promotion and environment deployments.

#### Promotion Decisions

**Metric**: `promotion_decisions_total`  
**Type**: Counter  
**Description**: Count of promotion attempts and outcomes

**Labels**:
- `from_env`: dev, staging (or "build" for initial deployment)
- `to_env`: dev, staging, production
- `decision`: allowed, blocked, rejected, skipped
- `block_reason`: (if blocked) immutability_check_failed, staging_not_verified, critical_vuln, manual_rejection

**Example scenarios**:
- `from_env=build, to_env=dev, decision=allowed` → Feature branch deployed to dev
- `from_env=staging, to_env=production, decision=blocked, block_reason=staging_not_verified` → Prod deployment blocked
- `from_env=staging, to_env=production, decision=allowed` → Prod deployment approved

**Why it matters**: Tracks promotion gate effectiveness, identifies common block reasons.

---

#### Deployment Success Rate by Environment

**Metric**: `deployments_total`  
**Type**: Counter  
**Description**: Count of deployment attempts per environment

**Labels**:
- `environment`: dev, staging, production
- `result`: success, failure

**Calculation**:
```
deployment_success_rate(env) = count(env, success) / count(env, total)
```

**Target SLOs**:
- Development: >90%
- Staging: >95%
- Production: >99%

**Why it matters**: Environment-specific reliability tracking, identifies environmental issues.

---

#### Production Approval Timing

**Metric**: `production_approval_duration_seconds`  
**Type**: Gauge  
**Description**: Time between production deployment request and approval

**Labels**:
- `approver_type`: individual, team, automated

**Why it matters**: Measures human gate latency, identifies approval bottlenecks.

---

### 5. Artifact Metrics

Metrics related to build artifacts.

#### Artifact Build Time

**Metric**: `artifact_build_duration_seconds`  
**Type**: Gauge  
**Description**: Time to build the artifact (subset of build stage)

**Labels**:
- `artifact_type`: docker_image, helm_chart, binary, package

**Why it matters**: Tracks build performance independent of other build stage activities.

---

#### Artifact Size

**Metric**: `artifact_size_bytes`  
**Type**: Gauge  
**Description**: Size of the built artifact

**Labels**:
- `artifact_type`: docker_image, helm_chart, binary, package

**Why it matters**: Tracks artifact bloat, storage cost optimization.

---

#### Artifact Immutability Check Failures

**Metric**: `artifact_immutability_violations_total`  
**Type**: Counter  
**Description**: Count of attempts to use mutable tags (e.g., "latest", "prod")

**Labels**:
- `tag`: The prohibited tag that was attempted
- `blocked`: true/false (whether the pipeline blocked it)

**Target**: Zero violations

**Why it matters**: Enforces artifact immutability principle, detects misconfigurations.

---

## Metric Collection Implementation

### Current State (Day 8)

Metrics are **calculated and logged** within the pipeline but not yet exported to a metrics backend. Implementation:

1. **Timing capture**: Each stage records start/end time, calculates duration
2. **Structured output**: Metrics are included in the run summary JSON artifact
3. **Console logging**: Metrics are printed to job output for visibility

**Example output in logs**:
```bash
[METRICS] stage=build duration=145s result=success
[METRICS] stage=test duration=62s result=success
[METRICS] pipeline duration=847s result=success
```

**Example in run summary JSON**:
```json
{
  "pipeline_duration_seconds": 847,
  "stages": {
    "build": {"duration_seconds": 145, "result": "success"},
    "test": {"duration_seconds": 62, "result": "success"}
  }
}
```

### Future State (Metrics Export)

When integrating with observability platforms:

1. **Prometheus**: Use GitHub Actions exporter or custom webhook to push metrics
2. **Grafana**: Dashboard for pipeline visualization
3. **Datadog/New Relic**: APM integration for pipeline monitoring
4. **CloudWatch/Azure Monitor**: Native cloud platform metrics

The structured JSON artifacts make future integration straightforward.

---

## SLO Definitions

### Pipeline Performance SLOs

| Metric | Target | Measurement Period |
|--------|--------|-------------------|
| Pipeline success rate (main branch) | >95% | 7 days rolling |
| Pipeline duration (feature branch) | <5 minutes | p95 |
| Pipeline duration (main → staging) | <15 minutes | p95 |
| Production deployment duration | <20 minutes | p95 |
| Deployment success rate (production) | >99% | 30 days rolling |

### Failure Recovery SLOs

| Metric | Target | Measurement Period |
|--------|--------|-------------------|
| Time to detect failure | <2 minutes | p99 |
| Rollback duration (production) | <5 minutes | p95 |
| Re-run after transient failure | <10 minutes | p95 |

---

## Non-Negotiable Requirements

Every pipeline execution MUST:

1. **Record pipeline start and end time**
2. **Measure duration for every executed stage**
3. **Categorize failures by stage** (if failure occurs)
4. **Record promotion decisions** (allowed/blocked/skipped)
5. **Log deployment outcomes** (per environment)

These metrics are not optional. They are **foundational signals** for platform operations.

---

## Related Documentation

- [audit-and-run-artifacts.md](audit-and-run-artifacts.md) - Artifact requirements
- [README.md](README.md) - Observability overview
- [../architecture/execution-and-failure-model.md](../architecture/execution-and-failure-model.md) - Failure handling
