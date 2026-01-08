# Observability

**Status**: Active  
**Owner**: Platform Team  
**Last Updated**: 2026-01-08

## Purpose

This directory defines the observability strategy for CI/CD pipelines. Observability transforms pipelines from "black boxes that sometimes fail" into platforms that emit structured, queryable signals for debugging, compliance, and operational insight.

## Why Observability Matters

### Platform Credibility

A platform that can't explain itself is not production-ready. Observability enables:

- **Post-mortem analysis** without re-running pipelines
- **Audit compliance** with immutable run records
- **Performance optimization** through timing metrics
- **Failure diagnosis** with structured error categorization
- **Trend analysis** for platform health monitoring

### The Shift from Logs to Signals

Traditional logs are unstructured and hard to query. Observability replaces this with:

| Traditional Approach | Observability Approach |
|---------------------|------------------------|
| Console logs only | Structured JSON artifacts |
| Manual log inspection | Automated metric aggregation |
| Lost after 90 days | Permanent audit artifacts |
| Hard to correlate | Traceable via artifact IDs |
| Requires re-runs to debug | Post-mortem analysis enabled |

## Signal Categories

### 1. Pipeline Metrics

Quantitative measurements of pipeline execution:

- **Duration**: Total pipeline runtime, per-stage timing
- **Success rate**: Pass/fail ratio over time
- **Failure categorization**: Build vs test vs scan vs deploy failures
- **Promotion metrics**: Approval rates, blocks, rejections

See: [pipeline-metrics.md](pipeline-metrics.md)

### 2. Audit Artifacts

Immutable records of every pipeline run:

- **Run summaries**: Complete execution records (JSON)
- **Artifact metadata**: Build traceability snapshots
- **Promotion decisions**: What deployed where, what was blocked
- **Approval records**: Who approved production, when

See: [audit-and-run-artifacts.md](audit-and-run-artifacts.md)

### 3. Structured Logs

Console output organized for readability:

- **GitHub Actions groups**: Collapsible log sections
- **Stage separation**: Clear boundaries between stages
- **Contextual metadata**: Commit SHA, branch, artifact tag in every log

## Integration with Existing Architecture

Observability complements existing platform components:

- **Artifacts** ([docs/artifacts/](../artifacts/)): Observability adds metadata capture and traceability records
- **Promotion** ([docs/promotion/](../promotion/)): Observability records promotion decisions and approvals
- **Deployment** ([docs/deployment/](../deployment/)): Observability captures verification results
- **Security** ([docs/security/](../security/)): Observability enables audit compliance

## Future Tooling Integration

While the current implementation focuses on GitHub Actions artifacts and logs, the structured outputs are designed for integration with:

- **Prometheus**: Pipeline duration, stage timing, failure rates
- **Grafana**: Dashboards for pipeline trends and SLOs
- **Elasticsearch/Splunk**: Centralized log aggregation and search
- **Audit systems**: Compliance reporting from run artifacts

The principle: **Emit structured data now, wire dashboards later.**

## Non-Negotiable Requirements

Every pipeline run MUST:

1. **Emit timing data** for all stages
2. **Generate run summary** (JSON format)
3. **Upload audit artifacts** (stored permanently)
4. **Categorize failures** (if any occur)
5. **Record promotion decisions** (what deployed where)

A pipeline run without these signals is considered **incomplete**.

## Documents in This Section

- [pipeline-metrics.md](pipeline-metrics.md) - Metrics that must be measured
- [audit-and-run-artifacts.md](audit-and-run-artifacts.md) - Artifacts that must be generated

## Related Documentation

- [Architecture](../architecture/) - Overall platform design
- [Artifacts](../artifacts/) - Artifact standards and traceability
- [Promotion](../promotion/) - Promotion model and gates
- [Deployment](../deployment/) - Deployment verification
