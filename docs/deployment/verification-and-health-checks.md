# Verification and Health Checks

This document defines **what constitutes deployment success**.

**A deployment without verification is considered failed.**

---

## What Is Verification?

Verification answers the question: **"Is the deployed code actually working?"**

Deployment completion is not enough:

- ❌ **Deployment finished** = Code was deployed (process completed)
- ✅ **Verification passed** = Code is working (system is functional)

**These are distinct states.** A deployment can finish successfully but the application can be broken.

---

## Verification ≠ Deployment

Verification is a **separate stage** that runs after deployment.

### Deployment Stage

**Purpose**: Get artifact into target environment.

**Success criteria**:
- Container images pulled from registry
- Kubernetes manifests applied
- Pods started

**Failure modes**:
- Artifact not found in registry
- Insufficient resources to schedule pods
- Image pull errors

---

### Verification Stage

**Purpose**: Confirm deployed artifact is functional.

**Success criteria**:
- Health endpoints return 200 OK
- Dependencies are reachable
- Basic functionality works (smoke tests)

**Failure modes**:
- Application crashes on startup
- Health checks timeout or return errors
- Dependencies unavailable

---

## Required Health Checks

All non-prod deployments must implement **standardized health checks**.

### 1. Liveness Check

**Purpose**: Is the application process running?

**Endpoint**: `/health/live` or `/healthz`

**Success criteria**: HTTP 200 OK

**Failure action**: Kubernetes restarts the pod

**Example response**:
```json
{
  "status": "UP",
  "timestamp": "2024-01-08T14:30:00Z"
}
```

**Check frequency**: Every 10 seconds

**Timeout**: 5 seconds

**Failure threshold**: 3 consecutive failures

---

### 2. Readiness Check

**Purpose**: Is the application ready to serve traffic?

**Endpoint**: `/health/ready`

**Success criteria**: HTTP 200 OK

**Failure action**: Kubernetes removes pod from service load balancer (no traffic routed)

**Example response**:
```json
{
  "status": "UP",
  "checks": {
    "database": "UP",
    "cache": "UP",
    "message_queue": "UP"
  },
  "timestamp": "2024-01-08T14:30:00Z"
}
```

**Check frequency**: Every 5 seconds

**Timeout**: 5 seconds

**Failure threshold**: 3 consecutive failures

---

### 3. Startup Check (Optional)

**Purpose**: Did the application initialize successfully?

**Endpoint**: `/health/startup`

**Success criteria**: HTTP 200 OK

**Use case**: Applications with slow startup (batch processing, ML models)

**Failure action**: Kubernetes restarts the pod if startup fails

**Timeout**: 60 seconds (longer for slow starts)

---

## Dependency Readiness Checks

Applications must verify their dependencies are available.

### Database Connectivity

**Check**: Can application connect to database?

```python
# Python example
def check_database():
    try:
        db.execute("SELECT 1")
        return {"status": "UP"}
    except Exception as e:
        return {"status": "DOWN", "error": str(e)}
```

**Success criteria**: Query executes successfully

**Failure**: Readiness check fails, pod not ready

---

### Cache Availability

**Check**: Can application connect to Redis/Memcached?

```python
def check_cache():
    try:
        cache.ping()
        return {"status": "UP"}
    except Exception as e:
        return {"status": "DOWN", "error": str(e)}
```

**Success criteria**: Ping returns PONG

---

### Downstream API Availability

**Check**: Can application reach dependent APIs?

```python
def check_downstream_api():
    try:
        response = requests.get("https://api-gateway/health", timeout=2)
        if response.status_code == 200:
            return {"status": "UP"}
        return {"status": "DOWN", "http_code": response.status_code}
    except Exception as e:
        return {"status": "DOWN", "error": str(e)}
```

**Success criteria**: Downstream API health check returns 200 OK

---

## Smoke Tests

Smoke tests verify **basic functionality** after deployment.

### What Are Smoke Tests?

**Smoke tests** are lightweight, fast functional tests that verify critical paths.

**Purpose**: Ensure deployment didn't break core functionality

**Scope**: Happy path only (not exhaustive testing)

**Duration**: < 1 minute

---

### Example Smoke Tests

#### API Service

```bash
# Test 1: Health endpoint
curl -f https://dev.example.com/health/ready || exit 1

# Test 2: Basic API call (unauthenticated)
curl -f https://dev.example.com/api/v1/status || exit 1

# Test 3: Authenticated API call
TOKEN=$(get_test_token)
curl -f -H "Authorization: Bearer $TOKEN" https://dev.example.com/api/v1/users || exit 1
```

**Expected duration**: ~10 seconds

**Failure action**: Deployment verification fails, rollback triggered

---

#### Web Application

```bash
# Test 1: Homepage loads
curl -f https://dev.example.com/ || exit 1

# Test 2: Login page accessible
curl -f https://dev.example.com/login || exit 1

# Test 3: Static assets load
curl -f https://dev.example.com/static/app.js || exit 1
```

---

#### Background Worker

```bash
# Test 1: Worker process is running
kubectl get pods -l app=worker -n development | grep Running || exit 1

# Test 2: Worker can process test job
enqueue_test_job()
wait_for_job_completion()
verify_job_result() || exit 1
```

---

## Failure Conditions

Verification fails if **any** of the following occur:

### 1. Health Check Failure

- Liveness check returns non-200 status code
- Readiness check returns non-200 status code
- Health check times out (no response within timeout)

**Example**:
```bash
$ curl https://dev.example.com/health/ready
HTTP/1.1 503 Service Unavailable
{"status": "DOWN", "checks": {"database": "DOWN"}}
```

**Action**: Verification fails, rollback triggered

---

### 2. Dependency Unavailability

- Database connection fails
- Cache unreachable
- Downstream API unavailable

**Example**:
```
ERROR: Cannot connect to database at postgres-dev.example.com:5432
```

**Action**: Verification fails, rollback triggered

---

### 3. Smoke Test Failure

- API call returns 4xx or 5xx error
- Expected data not returned
- Functional test assertion fails

**Example**:
```bash
$ curl https://dev.example.com/api/v1/users
HTTP/1.1 500 Internal Server Error
```

**Action**: Verification fails, rollback triggered

---

### 4. Timeout

- Verification does not complete within timeout period
- Pods do not reach Ready state within timeout

**Timeout**: 5 minutes (configurable per service)

**Action**: Verification fails, rollback triggered

---

## Timeouts and Retries

### Verification Timeout

**Total verification timeout**: 5 minutes

**Rationale**: Services should be ready within 5 minutes; longer indicates deployment issue.

**Configurable per service**: Services with slow startup can override (max 10 minutes)

---

### Health Check Timeout

**Individual health check timeout**: 5 seconds

**Rationale**: Health checks should be fast; slow checks indicate performance issue.

---

### Retry Logic

**Health checks**: Retry 3 times before failing

**Smoke tests**: No retries (fail fast)

**Rationale**:
- Health checks may have transient failures (network blip)
- Smoke test failures indicate real problems (no retry needed)

---

## Verification Execution Flow

Every non-prod deployment follows this verification sequence:

### Step 1: Wait for Deployment Rollout

```bash
kubectl rollout status deployment/my-app -n development --timeout=5m
```

**Success**: All pods reach Running state

**Failure**: Timeout (pods not ready within 5 minutes)

---

### Step 2: Wait for Readiness

```bash
kubectl wait --for=condition=ready pod -l app=my-app -n development --timeout=3m
```

**Success**: All pods pass readiness probe

**Failure**: Readiness probe fails or times out

---

### Step 3: Check Health Endpoints

```bash
# Retrieve service endpoint
ENDPOINT=$(kubectl get svc my-app -n development -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Check liveness
curl -f http://$ENDPOINT/health/live || exit 1

# Check readiness
curl -f http://$ENDPOINT/health/ready || exit 1
```

**Success**: Both endpoints return 200 OK

**Failure**: Non-200 status or timeout

---

### Step 4: Run Smoke Tests

```bash
# Run smoke test suite
./scripts/smoke-tests.sh development

# Example tests:
# - API endpoints respond
# - Database connectivity works
# - Cache is accessible
```

**Success**: All smoke tests pass

**Failure**: Any smoke test fails

---

### Step 5: Record Verification Result

```json
{
  "environment": "development",
  "artifact": "myregistry.azurecr.io/my-app:7a3f9c2",
  "verification_status": "PASSED",
  "verification_duration_seconds": 45,
  "health_checks": {
    "liveness": "PASSED",
    "readiness": "PASSED"
  },
  "smoke_tests": {
    "api_health": "PASSED",
    "database_connectivity": "PASSED",
    "cache_connectivity": "PASSED"
  },
  "verified_at": "2024-01-08T14:31:00Z"
}
```

**Verification result determines promotion eligibility.**

---

## Rollback on Verification Failure

If verification fails, deployment is **automatically rolled back**.

### Rollback Trigger

Verification failure triggers immediate rollback:

```bash
if verification_failed; then
  echo "Verification FAILED - Triggering rollback"
  kubectl rollout undo deployment/my-app -n development
  verify_rollback_success || alert_team
fi
```

---

### Rollback Verification

After rollback, verify that previous version is working:

1. Wait for rollback rollout completion
2. Check health endpoints
3. Confirm application serving traffic

**If rollback verification fails, escalate to on-call team.**

---

## Verification vs Testing

Verification and testing are distinct:

| Aspect | Verification | Testing |
|--------|--------------|---------|
| **When** | After deployment | Before deployment (in Test stage) |
| **Purpose** | Confirm deployment worked | Confirm code is correct |
| **Scope** | Health checks, smoke tests | Unit, integration, E2E tests |
| **Duration** | < 5 minutes | Variable (can be hours) |
| **Failure action** | Rollback deployment | Block deployment |

**Verification assumes code is tested.** Verification checks deployment success, not code correctness.

---

## Environment-Specific Verification

Different environments have different verification requirements:

### Development

**Verification**:
- Basic health checks (liveness, readiness)
- Minimal smoke tests (1-2 critical endpoints)

**Rationale**: Dev is for rapid iteration; verification is lightweight

---

### Staging

**Verification**:
- Comprehensive health checks (liveness, readiness, startup)
- Extensive smoke tests (all critical paths)
- Dependency connectivity checks
- Performance validation (optional)

**Rationale**: Staging is pre-production; must match production quality

---

## Monitoring During Verification

During verification, monitor:

- **Pod status**: Are pods running and ready?
- **Logs**: Are there errors or warnings?
- **Metrics**: Is CPU/memory usage normal?
- **Network**: Are dependencies reachable?

**Anomalies during verification may indicate deployment issues even if health checks pass.**

---

## Verification Observability

All verification results are logged and auditable:

### Verification Logs

```
[2024-01-08 14:30:00] Deployment rollout started (dev)
[2024-01-08 14:30:15] Pods running: 3/3
[2024-01-08 14:30:20] Readiness checks: PASSED
[2024-01-08 14:30:25] Health endpoint /health/ready: 200 OK
[2024-01-08 14:30:30] Smoke tests: PASSED (3/3)
[2024-01-08 14:30:35] Verification: SUCCESS
```

**Logs retained for**: 30 days (dev), 90 days (staging)

---

### Verification Metrics

Track verification health:

- **Verification success rate**: Percentage of deployments passing verification
- **Verification duration**: Time from deployment complete to verification success
- **Rollback frequency**: How often verifications fail and trigger rollbacks

**Targets**:
- Success rate: > 95% (high-quality deployments)
- Duration: < 2 minutes (fast feedback)
- Rollback frequency: < 5% (stable deployments)

---

## Conformance

Verification requirements are **mandatory** and **non-negotiable**.

Deployments that:
- Skip verification
- Ignore failed health checks
- Proceed after smoke test failures

**...are rejected by the platform.**

Verification is what makes deployments safe and repeatable.
