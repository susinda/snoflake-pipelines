# Snowflake Student Data Pipeline

A hands-on data engineering project for **synthetic university student enrolment and payment data**. Data is ingested into `STUDENT.RAW`, validated and cleaned in `STUDENT.CLEAN`, and transformed into `STUDENT.BIZ` for reporting on fees paid and outstanding balances. We will add incremental processing with **Snowflake Streams and Tasks**, scheduling, run history, failure monitoring, and GitHub Actions CI/CD as the project develops.

## Data model and planned layers

```text
STUDENT (database / domain)
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

## Setup and deployment

1. **One-time admin bootstrap:** In Snowflake Snowsight, execute [`sql/0_serviceuser.sql`](sql/0_serviceuser.sql) **manually** using `ACCOUNTADMIN`. It creates `STUDENT_DEPLOY_ROLE`, creates/configures `GITHUB_CICD_USER` for GitHub OIDC authentication, grants the role to the user, and provides database/warehouse creation privileges for the learning environment. The SQL emits progress messages and verification results. **Do not execute this bootstrap file from GitHub Actions.**
2. **Verify OIDC identity:** The script currently uses the branch-based GitHub subject `repo:susinda/snoflake-pipelines:ref:refs/heads/main`. Confirm that this matches your GitHub OIDC token; newer immutable subject configurations may require an ID-based value. Never store a Google password in GitHub.
3. **Deploy objects:** Configure the manually triggered GitHub Actions workflow to authenticate as `GITHUB_CICD_USER` with `STUDENT_DEPLOY_ROLE` and execute `sql/01_setup.sql`. This creates the compute warehouse, `STUDENT` database, schemas, and RAW tables. The script uses `IF NOT EXISTS`, so reruns preserve existing rows. **This deployment script does not import CSVs or clean data.**
4. **Initial data load:** Load `data/enrolments.csv` into `STUDENT.RAW.ENROLMENTS` and `data/student_payments.csv` into `STUDENT.RAW.STUDENT_PAYMENTS` using Snowsight. Verify 125 enrolments and 188 payments using `sql/02_verify.sql` when added to your repo.
5. **Later phases:** Implement SQL data cleaning, business summaries, Streams/Tasks, monitoring, failure recovery, and CI/CD deployment of subsequent scripts.

The CSVs contain fictional records. The initial files have no intentional duplicate keys or orphan payments; later exercises will introduce updates, duplicates and errors to test the pipelines.

## Security notes

- `0_serviceuser.sql` is a **privileged, one-time bootstrap script** for an isolated development account. It must not be part of the routine deployment workflow.
- Restrict who can modify or run deployment workflows; use a dedicated least-privilege role and an approved GitHub OIDC configuration for production.
- Keep the trial warehouse X-Small, use auto-suspend, and monitor credits.

**Status:** Work in progress; building and testing one stage at a time.
