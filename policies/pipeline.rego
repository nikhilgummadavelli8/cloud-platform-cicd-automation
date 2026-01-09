package pipeline

# Pipeline Policy: Enforce 5 mandatory stages
# This policy validates that all CI/CD workflows contain the required stages
# based on the platform standards defined in the reusable workflow.

# REQUIRED STAGES (from cicd-platform.yml):
# 1. validate (branch and environment validation)
# 2. build (artifact creation with immutable versioning)
# 3. test (automated testing)
# 4. security-scan (security validation)
# 5. deploy (deployment orchestration)

# Define mandatory stages
mandatory_stages := {
    "validate",
    "build",
    "test",
    "security-scan",
    "deploy"
}

# Alternative stage names that should be accepted
stage_aliases := {
    "validate": ["validate", "validation", "validate-inputs"],
    "build": ["build", "build-artifact"],
    "test": ["test", "testing", "unit-test", "integration-test"],
    "security-scan": ["security-scan", "security", "scan", "security-scanning"],
    "deploy": ["deploy", "deployment", "deploy-dev", "deploy-staging", "deploy-prod"]
}

# Extract job names from workflow
job_names[job_name] {
    input.jobs[job_name]
}

# Check if a required stage exists (by exact match or alias)
stage_exists(stage_type) {
    job_names[job_name]
    # Exact match
    lower(job_name) == stage_type
}

stage_exists(stage_type) {
    job_names[job_name]
    # Alias match
    alias := stage_aliases[stage_type][_]
    contains(lower(job_name), alias)
}

stage_exists(stage_type) {
    job_names[job_name]
    # Name contains the stage type
    contains(lower(job_name), stage_type)
}

# DENY: Missing mandatory stages
deny[msg] {
    stage := mandatory_stages[_]
    not stage_exists(stage)
    msg := sprintf("POLICY VIOLATION: Missing mandatory stage '%s'. All workflows must include: %v", [stage, mandatory_stages])
}

# WARN: Workflow has no jobs defined
warn[msg] {
    count(input.jobs) == 0
    msg := "WARNING: Workflow has no jobs defined"
}

# SUCCESS: All mandatory stages present
allow {
    count(deny) == 0
}

# Helper: Extract all stages for reporting
present_stages[stage] {
    job_names[stage]
}
