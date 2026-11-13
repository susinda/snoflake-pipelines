# Snowflake Student Data Pipeline

A small university student-finance pipeline built in Snowflake using a **Bronze → Silver → Gold (Medallion) architecture**. GitHub stores version-controlled SQL and sample CSVs; **one GitHub Actions workflow** deploys objects and loads RAW data; **Snowflake Streams and Tasks** orchestrate transformations from RAW to CLEAN to BIZ.

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
│   └── 06_pipeline_tasks.sql     # Snowflake Task graph: CLEAN_TASK -> BIZ_TASK
└── .github/
    └── workflows/
        └── pipeline.yml         # ONE GitHub Actions workflow: deploy + stage/upload + RAW ingest + task setup
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

GitHub Actions handles deployment and ingestion, while **Snowflake Tasks—not GitHub Actions—execute recurring CLEAN and BIZ refreshes**.

The internal **stage is a file-based landing zone**, not a fourth Medallion layer. The three Medallion layers are `RAW` (Bronze), `CLEAN` (Silver), and `BIZ` (Gold). The tables are queried with SQL and stored in Snowflake-managed storage.

## What each script does

| File | Responsibility | How it runs |
|---|---|---|
| `0_serviceuser.sql` | Creates `STUDENT_DEPLOY_ROLE` and `GITHUB_CICD_USER`, configures trust for GitHub Actions OIDC, and grants required account-level creation privileges. | **Manually once** in Snowsight using an administrator role; **never** from GitHub Actions. |
| `01_setup.sql` | Creates `STUDENT_WH`, the `STUDENT` database, `RAW`, `CLEAN`, `BIZ`, `OPS` schemas, and initial RAW tables. | GitHub Actions deployment. |
| `02_stage.sql` | Defines CSV parsing rules (`CSV_FORMAT`) and Snowflake internal storage (`CSV_STAGE`). | GitHub Actions deployment or initial manual setup. |
| `03_load.sql` | Reads staged files with `COPY INTO` and populates `STUDENT.RAW.ENROLMENTS` and `STUDENT.RAW.STUDENT_PAYMENTS`. | One GitHub Actions workflow, after file upload. |
| `04_clean.sql` | Creates SILVER tables, RAW Streams, and the `REFRESH_CLEAN()` stored procedure to clean/upsert rows. | GitHub Actions **deploys definitions**; the procedure must be called or triggered separately. |
| `05_biz.sql` | Creates GOLD `TUITION_SUMMARY` and `REFRESH_BIZ()` to join enrolments with payments, calculate paid and outstanding balances, and derive reporting columns. | GitHub Actions **deploys definitions**; the procedure must be called or triggered separately. |
| `06_pipeline_tasks.sql` | Creates a Snowflake task graph: scheduled `CLEAN_TASK` checks RAW Streams and invokes `REFRESH_CLEAN()`; successful completion triggers `BIZ_TASK` to invoke `REFRESH_BIZ()`. | GitHub Actions **deploys** it after procedures exist; Snowflake **runs** it when activated. |
| `pipeline.yml` | The **single GitHub Actions workflow**: authenticates with OIDC, sets up objects, uploads both CSVs, loads RAW data, and deploys the task graph. | Manual GitHub `workflow_dispatch` for deployment/ingestion, not the recurring CLEAN/BIZ scheduler. |

## One-time bootstrap: why `0_serviceuser.sql` must be run manually

Before a GitHub workflow can connect to Snowflake, Snowflake must know **which external identity to trust** and **what that identity is allowed to do**. This is a *bootstrap problem*: the deployment workflow cannot securely create its own initial account identity and permissions before it has authenticated.

Run `sql/0_serviceuser.sql` **once, manually in Snowsight with a sufficiently privileged administrator role**. It establishes:

1. **Service identity:** `GITHUB_CICD_USER` is a Snowflake `TYPE=SERVICE` user for automation, separate from a personal login.
2. **Least-privilege role:** `STUDENT_DEPLOY_ROLE` carries the permissions the deployment needs. Additional object-level privileges, such as stage access, depend on object ownership and grants.
3. **GitHub OIDC trust:** Snowflake trusts tokens issued by `https://token.actions.githubusercontent.com` only when the token subject matches this repository and allowed branch. Our working configuration uses the **exact subject** observed from GitHub for this repository; do not replace it with a guessed or generic subject.
4. **Short-lived authentication:** With GitHub Actions OIDC, the workflow obtains a temporary identity token; we do **not** store a Snowflake account password or long-lived private key in GitHub.
5. **Authorisation:** Authentication proves *who* the workflow is; the Snowflake role determines *what* it can create, read, upload, or execute.

**Security note:** Keep the bootstrap script out of automatic deployment. Re-run or adjust it only when deliberately changing the service identity, GitHub trust configuration, or grants. Account-level `CREATE DATABASE` and `CREATE WAREHOUSE` are broad permissions: tighten the deployment permissions as the project matures. A personal Snowsight user and the CI service user are different principals and may have different role grants.

## One GitHub Actions workflow: deployment + RAW ingestion

We use **one** file: `.github/workflows/pipeline.yml`. The GitHub run sets up the Snowflake resources and ingests source files into the Bronze layer. It also **deploys** the CLEAN and BIZ procedures and Task graph; it does **not** call `REFRESH_CLEAN()` or `REFRESH_BIZ()` directly on each run.

```text
pipeline.yml (GitHub Actions, manual workflow_dispatch)
    |
    +-- 01_setup.sql          Create warehouse, database, schemas, RAW tables
    +-- 02_stage.sql          Create CSV_FORMAT and CSV_STAGE
    +-- 04_clean.sql          Create CLEAN tables, RAW Streams, CLEAN procedure
    +-- 05_biz.sql            Create BIZ table, BIZ procedure
    +-- Upload data/*.csv     snow stage copy -> CSV_STAGE
    +-- 03_load.sql           COPY INTO -> RAW (Bronze) tables
    +-- 06_pipeline_tasks.sql Create/resume Snowflake Task graph (when ready)
                                  |
                                  v
                         Snowflake scheduler / Tasks
                                  |
                   CLEAN_TASK checks RAW Streams
                                  |
                       CALL REFRESH_CLEAN()
                                  |
                         CLEAN (Silver) tables
                                  |
                         BIZ_TASK (AFTER CLEAN_TASK)
                                  |
                        CALL REFRESH_BIZ()
                                  |
                          BIZ (Gold) table
```

**Important distinction:** The `04_clean.sql` and `05_biz.sql` scripts **create definitions**, not a data refresh. After `06_pipeline_tasks.sql` has been deployed and the tasks are **resumed**, Snowflake schedules/executes the refresh calls internally. If the root task is scheduled every 15 minutes, there can be a delay after `COPY INTO` until the next check. A separate manual test can execute the procedures or root task before turning scheduling on.

### Suggested workflow steps (inside the single file)

```yaml
# After checkout and Snowflake CLI OIDC setup:
- name: Deploy infrastructure
  run: snow sql -x -f sql/01_setup.sql
- name: Deploy stage
  run: snow sql -x -f sql/02_stage.sql
- name: Deploy CLEAN definitions
  run: snow sql -x -f sql/04_clean.sql
- name: Deploy BIZ definitions
  run: snow sql -x -f sql/05_biz.sql
# Upload both CSVs from data/ using snow stage copy ... -x
- name: Load RAW
  run: snow sql -x -f sql/03_load.sql
- name: Deploy Snowflake task graph
  run: snow sql -x -f sql/06_pipeline_tasks.sql
```

Keep the existing CSV-upload steps in `pipeline.yml` between stage deployment and `03_load.sql`. Do **not** add direct `CALL STUDENT.CLEAN.REFRESH_CLEAN()` or `CALL STUDENT.BIZ.REFRESH_BIZ()` steps to GitHub Actions when using Task orchestration.

**One-time manual setup:** `0_serviceuser.sql` remains outside the GitHub workflow. Use `ACCOUNTADMIN` to create the service principal and grant its role the required privileges. Snowflake task execution also requires `EXECUTE TASK` on the account for the task owner role, plus suitable warehouse and object privileges. Grant only what the deployment role needs.

**Initial data already loaded:** If Streams were first created with `SHOW_INITIAL_ROWS = TRUE`, they can initially expose existing RAW records. Avoid dropping/replacing Streams on redeployment because that loses or resets their offsets. `CREATE ... IF NOT EXISTS` protects these particular Streams from being replaced. For production deployments, also plan safe updates to existing task definitions: `CREATE TASK IF NOT EXISTS` does not update a task whose definition has changed, and a task graph must be managed carefully when changing tasks while active.

## Future automation: Streams and Tasks

- **Streams** track table changes; they are **not** file upload tools.
- **Tasks** execute SQL or call stored procedures on schedules or after upstream tasks succeed.
- The intended task graph is `CLEAN_TASK → BIZ_TASK`; the root task checks whether RAW Streams have data, calls `REFRESH_CLEAN()`, then triggers `REFRESH_BIZ()` when the first task succeeds.
- GitHub Actions should **deploy** task definitions, not act as the long-term transformation scheduler.
- Avoid recreating Streams on every deployment because their consumption positions matter. Test procedures manually before resuming tasks. Suspend scheduled tasks when not needed to control compute costs.

## Workflow responsibilities (single GitHub Actions file)

| System | Responsibility |
|---|---|
| GitHub repository | Version-controlled SQL, sample CSVs, and `pipeline.yml` |
| GitHub Actions `pipeline.yml` | Deploy Snowflake definitions, upload `data/*.csv`, run `03_load.sql`, deploy Task definitions |
| `0_serviceuser.sql` | **Manual one-time administrator bootstrap**, never called by GitHub Actions |
| Snowflake internal `CSV_STAGE` | Store uploaded CSVs before RAW ingestion |
| Snowflake RAW tables | Bronze, preserve ingested source records |
| Snowflake RAW Streams | Track newly committed changes for downstream processing |
| Snowflake `CLEAN_TASK` | On its schedule, check Streams and run `REFRESH_CLEAN()` |
| Snowflake CLEAN tables | Silver, validated/deduplicated records |
| Snowflake `BIZ_TASK` | Run `REFRESH_BIZ()` after `CLEAN_TASK` succeeds |
| Snowflake BIZ table | Gold, reporting-ready tuition and payment metrics |

## Operational checks

Preview results after the tasks have run:

```sql
SELECT COUNT(*) AS RAW_ENROLMENTS FROM STUDENT.RAW.ENROLMENTS;
SELECT COUNT(*) AS CLEAN_ENROLMENTS FROM STUDENT.CLEAN.ENROLMENTS;
SELECT COUNT(*) AS CLEAN_PAYMENTS FROM STUDENT.CLEAN.STUDENT_PAYMENTS;
SELECT * FROM STUDENT.BIZ.TUITION_SUMMARY LIMIT 20;
```

See task states:

```sql
SHOW TASKS IN SCHEMA STUDENT.OPS;
```

To avoid ongoing scheduled compute charges in a learning account, suspend the root task when not testing:

```sql
ALTER TASK STUDENT.OPS.CLEAN_TASK SUSPEND;
```

> **Note:** Tasks are planned as the next automation step. The README describes the target architecture; it does not mean `06_pipeline_tasks.sql` is already deployed or the procedures have already succeeded. Confirm the procedures and task privileges before enabling the schedule.


Documentation
https://medium.com/@susindaperera/exploring-snowflake-architecture-through-production-oriented-data-engineering-practices-cb4afa66b6cc