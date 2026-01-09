package artifacts

# Artifacts Policy: Enforce immutable tagging and artifact standards
# This policy validates that workflows follow artifact best practices
# including immutable versioning, metadata generation, and proper registry usage.

# ARTIFACT REQUIREMENTS (from docs/artifacts/artifact-standards.md):
# 1. No mutable tags (latest, dev, staging, prod, main, master)
# 2. Tags must be immutable and traceable (commit SHA or semantic version)
# 3. Artifact metadata must be generated for traceability
# 4. Container registry must be configured properly

# Prohibited mutable tags
prohibited_tags := {
    "latest",
    "dev",
    "development",
    "staging",
    "stage",
    "prod",
    "production",
    "main",
    "master"
}

# Check if workflow generates artifact version
generates_artifact_version {
    input.jobs[_].steps[_].id == "version"
}

generates_artifact_version {
    input.jobs[_].steps[_].name
    contains(lower(input.jobs[_].steps[_].name), "version")
}

# Check if workflow generates artifact metadata
generates_artifact_metadata {
    input.jobs[_].steps[_].name
    contains(lower(input.jobs[_].steps[_].name), "metadata")
}

generates_artifact_metadata {
    input.jobs[_].steps[_].name
    contains(lower(input.jobs[_].steps[_].name), "traceability")
}

# Check for prohibited tags in environment variables
uses_prohibited_tag[tag] {
    tag := prohibited_tags[_]
    env_value := input.env[_]
    contains(lower(env_value), tag)
    # Only flag if it looks like a tag (contains "tag" or "version")
    contains(lower(env_value), "tag")
}

uses_prohibited_tag[tag] {
    tag := prohibited_tags[_]
    env_value := input.jobs[_].env[_]
    contains(lower(env_value), tag)
    contains(lower(env_value), "tag")
}

uses_prohibited_tag[tag] {
    tag := prohibited_tags[_]
    step := input.jobs[_].steps[_]
    step_content := sprintf("%v", [step])
    contains(lower(step_content), tag)
    # Only flag if it's being used as a tag
    contains(lower(step_content), "image_tag")
}

# Check if workflow enforces immutability
enforces_immutability {
    input.jobs[_].steps[_].name
    contains(lower(input.jobs[_].steps[_].name), "immutability")
}

enforces_immutability {
    input.jobs[_].steps[_].name
    contains(lower(input.jobs[_].steps[_].name), "enforce")
    contains(lower(input.jobs[_].steps[_].name), "tag")
}

# Check if workflow uses commit SHA for versioning
uses_commit_sha_versioning {
    step := input.jobs[_].steps[_]
    step_run := step.run
    contains(step_run, "github.sha")
    contains(lower(step_run), "tag")
}

# DENY: Uses prohibited mutable tags
deny[msg] {
    tag := uses_prohibited_tag[_]
    msg := sprintf("POLICY VIOLATION: Prohibited mutable tag '%s' detected. Use immutable tags (commit SHA or semantic version) for traceability.", [tag])
}

# WARN: No artifact versioning detected
warn[msg] {
    not generates_artifact_version
    msg := "WARNING: No artifact versioning step detected. Artifacts should be versioned with immutable identifiers."
}

# WARN: No artifact metadata generation
warn[msg] {
    not generates_artifact_metadata
    msg := "WARNING: No artifact metadata generation detected. Metadata is required for traceability and compliance."
}

# INFO: Immutability enforcement detected
info[msg] {
    enforces_immutability
    msg := "INFO: Immutability enforcement detected. Good practice!"
}

# INFO: Commit SHA versioning detected
info[msg] {
    uses_commit_sha_versioning
    msg := "INFO: Commit SHA-based versioning detected. This ensures immutability and traceability."
}

# SUCCESS: All artifact checks pass
allow {
    count(deny) == 0
}
