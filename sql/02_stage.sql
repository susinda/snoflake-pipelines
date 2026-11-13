
-- =========================================================
-- Project : Snowflake Student Data Pipeline
-- Script  : 02_stage.sql
-- Purpose : Create CSV format and internal stage
-- =========================================================

USE WAREHOUSE STUDENT_WH;

CREATE FILE FORMAT IF NOT EXISTS STUDENT.RAW.CSV_FORMAT
    TYPE = CSV
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    EMPTY_FIELD_AS_NULL = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = TRUE;

CREATE STAGE IF NOT EXISTS STUDENT.RAW.CSV_STAGE
    FILE_FORMAT = STUDENT.RAW.CSV_FORMAT;

-- Verify
SHOW STAGES IN SCHEMA STUDENT.RAW;
