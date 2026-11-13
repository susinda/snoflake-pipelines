# Snowflake Student Data Pipeline

A hands-on data engineering project that ingests **student enrolment** and **payment** data from simulated university student and finance systems into Snowflake.

The pipeline will:

1. **Ingest** source data into the `STUDENT.RAW` schema.
2. **Clean and validate** records in `STUDENT.CLEAN`, including handling duplicates, updates and invalid data.
3. **Transform** the cleaned data into `STUDENT.BIZ` for reporting, such as tuition fees paid and outstanding balances.
4. Use **Snowflake Streams and Tasks** to process incremental changes and schedule pipeline execution.
5. Include **monitoring, execution history, error handling and data-quality checks** to investigate failures and verify results.

The project will also store SQL and pipeline definitions in **Git** and progressively introduce **CI/CD** for controlled deployment.

## Planned Snowflake structure

```text
STUDENT
├── RAW
│   ├── ENROLMENTS
│   └── STUDENT_PAYMENTS
├── CLEAN
│   ├── ENROLMENTS
│   └── STUDENT_PAYMENTS
├── BIZ
│   └── TUITION_FEE_SUMMARY
└── OPS
    └── PIPELINE_RUNS
```

**Status:** Work in progress. We'll build and test each stage incrementally, starting with table creation and sample data ingestion.
