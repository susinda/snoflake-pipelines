
-- =========================================================
-- Project : Snowflake Student Data Pipeline
-- Script  : 03_load.sql
-- Purpose : Load CSV data from stage into RAW tables
-- =========================================================

USE WAREHOUSE STUDENT_WH;

-- Load student enrolments
COPY INTO STUDENT.RAW.ENROLMENTS
FROM @STUDENT.RAW.CSV_STAGE/enrolments/
FILE_FORMAT = (
    FORMAT_NAME = STUDENT.RAW.CSV_FORMAT
)
ON_ERROR = ABORT_STATEMENT;

-- Load student payments
COPY INTO STUDENT.RAW.STUDENT_PAYMENTS
FROM @STUDENT.RAW.CSV_STAGE/payments/
FILE_FORMAT = (
    FORMAT_NAME = STUDENT.RAW.CSV_FORMAT
)
ON_ERROR = ABORT_STATEMENT;

-- Verify loaded records
SELECT
    'ENROLMENTS' AS TABLE_NAME,
    COUNT(*) AS ROW_COUNT
FROM STUDENT.RAW.ENROLMENTS

UNION ALL

SELECT
    'STUDENT_PAYMENTS',
    COUNT(*)
FROM STUDENT.RAW.STUDENT_PAYMENTS;
