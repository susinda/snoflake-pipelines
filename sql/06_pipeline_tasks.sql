
-- ============================================================
-- Project : Snowflake Student Data Pipeline
-- File    : sql/06_pipeline_tasks.sql
-- Purpose : Orchestrate Bronze -> Silver -> Gold
-- ============================================================

USE WAREHOUSE STUDENT_WH;

-- STEP 1: Create the root task
-- Checks RAW streams every 15 minutes.
-- Only runs the cleaning procedure if RAW data has changed.

CREATE TASK IF NOT EXISTS STUDENT.OPS.CLEAN_TASK
    WAREHOUSE = STUDENT_WH
    SCHEDULE = '15 MINUTES'
    WHEN
        SYSTEM$STREAM_HAS_DATA(
            'STUDENT.RAW.ENROLMENTS_STREAM'
        )
        OR
        SYSTEM$STREAM_HAS_DATA(
            'STUDENT.RAW.PAYMENTS_STREAM'
        )
AS
    CALL STUDENT.CLEAN.REFRESH_CLEAN();


-- STEP 2: Create downstream task
-- Runs after CLEAN_TASK completes successfully.
-- Recalculates the Gold business summary.

CREATE TASK IF NOT EXISTS STUDENT.OPS.BIZ_TASK
    WAREHOUSE = STUDENT_WH
    AFTER STUDENT.OPS.CLEAN_TASK
AS
    CALL STUDENT.BIZ.REFRESH_BIZ();


-- STEP 3: Enable tasks
-- Resume the child task first, then the root task.

ALTER TASK STUDENT.OPS.BIZ_TASK RESUME;
ALTER TASK STUDENT.OPS.CLEAN_TASK RESUME;


-- STEP 4: Verify task definitions
SHOW TASKS IN SCHEMA STUDENT.OPS;
