# Snowflake Student Data Pipeline

A small university student-finance pipeline built in Snowflake using a **Bronze → Silver → Gold (Medallion) architecture**. GitHub stores version-controlled SQL and sample CSVs; GitHub Actions deploys objects and uploads source files; Snowflake executes transformations.

## Repository structure

```text
snoflake-pipelines/
├── data/                         # Sample CSV source data
│   ├── enrolments.csv            # Student enrolment details and tuition fees
│   └── student_payments.csv      # Payments associated with enrolments
├── sql/                          # SQL definitions and processing scripts
│   ├── 0_serviceuser.sql         # ONE-TIME MANUAL: GitHub OIDC service user, role and grants
│   ├── 01_setup.sql              # Warehouse, STUDENT database, schemas and RAW tables
│   ├── 02_stage.sql              # CSV file format and internal file stage (landing zone)
│   ├── 03_load.sql               # COPY INTO from staged CSV files to RAW tables
│   ├── 04_clean.sql              # CLEAN tables, RAW streams and REFRESH_CLEAN procedure
│   ├── 05_biz.sql                # BIZ summary table and REFRESH_BIZ procedure
│   └── 06_pipeline_tasks.sql     # Scheduled task graph to invoke CLEAN then BIZ (when ready)
└── .github/
    └── workflows/
        ├── deploy.yml           # Deploy Snowflake SQL objects through OIDC
        └── ingest.yml           # Upload CSV files from data/ and execute COPY INTO
```

> **Naming:** `snoflake-pipelines` is the current repository name. `STUDENT` is the Snowflake database; `RAW`, `CLEAN`, `BIZ`, and `OPS` are schemas. A Snowflake *virtual warehouse* (`STUDENT_WH`) provides compute; it does not contain the database or tables.

## Architecture

```text
GitHub data/*.csv
       |
       | GitHub Actions + Snowflake CLI (snow stage copy)
       v
STUDENT.RAW.CSV_STAGE          Landing zone: original CSV files
       |
       | 03_load.sql: COPY INTO
       v
STUDENT.RAW                    BRONZE: ingested source tables
       |
       | RAW Streams capture changes
       | 04_clean.sql defines REFRESH_CLEAN()
       v
STUDENT.CLEAN                  SILVER: validated, standardised, deduplicated tables
       |
       | 05_biz.sql defines REFRESH_BIZ()
       v
STUDENT.BIZ                    GOLD: reporting-ready tuition summary

STUDENT.OPS                    Operational objects, including scheduled Tasks
```

The internal **stage is a file-based landing zone**, not a fourth Medallion layer. The three Medallion layers are `RAW` (Bronze), `CLEAN` (Silver), and `BIZ` (Gold). The tables are queried with SQL and stored in Snowflake-managed storage.

## What each script does

| File | Responsibility | How it runs |
|---|---|---|
| `0_serviceuser.sql` | Creates `STUDENT_DEPLOY_ROLE` and `GITHUB_CICD_USER`, configures trust for GitHub Actions OIDC, and grants required account-level creation privileges. | **Manually once** in Snowsight using an administrator role; **never** from GitHub Actions. |
| `01_setup.sql` | Creates `STUDENT_WH`, the `STUDENT` database, `RAW`, `CLEAN`, `BIZ`, `OPS` schemas, and initial RAW tables. | GitHub Actions deployment. |
| `02_stage.sql` | Defines CSV parsing rules (`CSV_FORMAT`) and Snowflake internal storage (`CSV_STAGE`). | GitHub Actions deployment or initial manual setup. |
| `03_load.sql` | Reads staged files with `COPY INTO` and populates `STUDENT.RAW.ENROLMENTS` and `STUDENT.RAW.STUDENT_PAYMENTS`. | Ingestion workflow, after file upload. |
| `04_clean.sql` | Creates SILVER tables, RAW Streams, and the `REFRESH_CLEAN()` stored procedure to clean/upsert rows. | GitHub Actions **deploys definitions**; the procedure must be called or triggered separately. |
| `05_biz.sql` | Creates GOLD `TUITION_SUMMARY` and `REFRESH_BIZ()` to join enrolments with payments, calculate paid and outstanding balances, and derive reporting columns. | GitHub Actions **deploys definitions**; the procedure must be called or triggered separately. |
| `06_pipeline_tasks.sql` | Defines Snowflake Tasks that call the CLEAN procedure on a schedule/stream condition and the BIZ procedure after CLEAN succeeds. | Deploy and activate **after manual transformation testing**; requires Snowflake task privileges. |
| `deploy.yml` | Uses GitHub Actions and Snowflake CLI to deploy SQL objects. | Run manually (`workflow_dispatch`) or according to the workflow configuration. |
| `ingest.yml` | Checks out `data/*.csv`, uploads files to `CSV_STAGE` with `snow stage copy`, and runs `03_load.sql`. | Run as an ingestion workflow; separate from deployment is preferred. |

## One-time bootstrap: why `0_serviceuser.sql` must be run manually

Before a GitHub workflow can connect to Snowflake, Snowflake must know **which external identity to trust** and **what that identity is allowed to do**. This is a *bootstrap problem*: the deployment workflow cannot securely create its own initial account identity and permissions before it has authenticated.

Run `sql/0_serviceuser.sql` **once, manually in Snowsight with a sufficiently privileged administrator role**. It establishes:

1. **Service identity:** `GITHUB_CICD_USER` is a Snowflake `TYPE=SERVICE` user for automation, separate from a personal login.
2. **Least-privilege role:** `STUDENT_DEPLOY_ROLE` carries the permissions the deployment needs. Additional object-level privileges, such as stage access, depend on object ownership and grants.
3. **GitHub OIDC trust:** Snowflake trusts tokens issued by `https://token.actions.githubusercontent.com` only when the token subject matches this repository and allowed branch. Our working configuration uses the **exact subject** observed from GitHub for this repository; do not replace it with a guessed or generic subject.
4. **Short-lived authentication:** With GitHub Actions OIDC, the workflow obtains a temporary identity token; we do **not** store a Snowflake account password or long-lived private key in GitHub.
5. **Authorisation:** Authentication proves *who* the workflow is; the Snowflake role determines *what* it can create, read, upload, or execute.

**Security note:** Keep the bootstrap script out of automatic deployment. Re-run or adjust it only when deliberately changing the service identity, GitHub trust configuration, or grants. Account-level `CREATE DATABASE` and `CREATE WAREHOUSE` are broad permissions: tighten the deployment permissions as the project matures. A personal Snowsight user and the CI service user are different principals and may have different role grants.

## Deployment vs execution

**Deploying SQL definitions is not the same as processing data.**

```text
01_setup.sql                 Create warehouse, database, schemas and RAW tables
     |
02_stage.sql                 Create the internal stage and CSV file format
     |
GitHub ingest.yml            Upload data/*.csv to the Snowflake stage
     |
03_load.sql                  COPY INTO -> RAW (Bronze) tables
     |
04_clean.sql                 CREATE CLEAN tables + RAW Streams + REFRESH_CLEAN()
     |
05_biz.sql                   CREATE BIZ table + REFRESH_BIZ()
     |
CALL REFRESH_CLEAN()          ACTUALLY transform RAW -> CLEAN
     |
CALL REFRESH_BIZ()            ACTUALLY transform CLEAN -> BIZ
     |
06_pipeline_tasks.sql        Later automate those procedure calls in Snowflake
```

At present, `04_clean.sql` and `05_biz.sql` **define** the target objects and stored procedures. They do **not** automatically populate `CLEAN` or `BIZ`. For an initial manual test, execute:

```sql
USE ROLE STUDENT_DEPLOY_ROLE;
USE WAREHOUSE STUDENT_WH;

CALL STUDENT.CLEAN.REFRESH_CLEAN();
CALL STUDENT.BIZ.REFRESH_BIZ();

SELECT COUNT(*) AS ENROLMENTS FROM STUDENT.CLEAN.ENROLMENTS;
SELECT COUNT(*) AS PAYMENTS FROM STUDENT.CLEAN.STUDENT_PAYMENTS;
SELECT * FROM STUDENT.BIZ.TUITION_SUMMARY LIMIT 20;
```

> If executing from your personal Snowsight account, the role must be assigned to that user. `GITHUB_CICD_USER` uses its own service role. Also, creating RAW Streams **after** initial data is loaded only includes historical rows if they are created with `SHOW_INITIAL_ROWS = TRUE`, as in the initial project script.

## Future automation: Streams and Tasks

- **Streams** track table changes; they are **not** file upload tools.
- **Tasks** execute SQL or call stored procedures on schedules or after upstream tasks succeed.
- The intended task graph is `CLEAN_TASK → BIZ_TASK`; the root task checks whether RAW Streams have data, calls `REFRESH_CLEAN()`, then triggers `REFRESH_BIZ()` when the first task succeeds.
- GitHub Actions should **deploy** task definitions, not act as the long-term transformation scheduler.
- Avoid recreating Streams on every deployment because their consumption positions matter. Test procedures manually before resuming tasks. Suspend scheduled tasks when not needed to control compute costs.

## Current workflow responsibilities

| System | Responsibility |
|---|---|
| GitHub repository | Version-controlled SQL, sample CSVs, workflows |
| GitHub Actions `deploy.yml` | Apply infrastructure and transformation definitions |
| GitHub Actions `ingest.yml` | Upload files from `data/` and run `03_load.sql` |
| Snowflake internal stage | Store CSVs awaiting ingestion |
| Snowflake RAW tables | Preserve ingested records |
| Snowflake CLEAN tables | Store validated and deduplicated records |
| Snowflake BIZ table | Provide useful financial/reporting fields |
| Snowflake Streams and Tasks | Detect changes and run in-platform transformations automatically |

**Current development note:** If `04_clean.sql` and `05_biz.sql` are appended to `ingest.yml`, the setup will work for initial deployment, but it mixes object deployment with ingestion. Once tested, move those steps to `deploy.yml` and leave `ingest.yml` to upload/load files.
