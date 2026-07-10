# MoonDataDrift

Project identifier: `moondatadrift`

MoonDataDrift is a MoonBit library and CLI for comparing a baseline table with a current table and surfacing likely data drift.

It focuses on practical checks that are useful in ML monitoring:
- missing-rate changes
- numeric quantiles
- PSI
- KS-like distribution distance
- categorical frequency shift

## Why this project

This repository is meant for the 2026 MoonBit open-source competition. The scope is intentionally compact enough to be finished well, but open-ended enough to grow into:
- file-based CSV ingestion
- richer charts and HTML reports
- drift thresholds and alerting
- CI integration for model pipelines

## Current scope

The current version works on in-memory tables and ships with a runnable demo report.

### What it does

- compares two tables with the same schema
- classifies each column as numeric or categorical
- reports missing-rate movement
- computes numeric p10 / p50 / p90 summaries
- computes PSI for numeric bins and categorical distributions
- computes a KS-like cumulative distance
- emits a Markdown report from the CLI

### What it does not do yet

- it does not read files from disk yet
- it does not render HTML dashboards yet
- it does not implement advanced outlier or time-window detection yet

## Run

```bash
moon run cmd/main
```

## Test

```bash
moon test
```

## License

Apache-2.0

## Notes for competition review

- MoonBit is the primary implementation language.
- The repo includes a clear README, a license, a runnable demo, and tests.
- The project direction is aligned with monitoring and MLOps, while remaining small enough to maintain cleanly.
