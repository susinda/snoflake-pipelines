
-- File: sql/05_biz.sql
-- Silver -> Gold

USE WAREHOUSE STUDENT_WH;

CREATE TABLE IF NOT EXISTS STUDENT.BIZ.TUITION_SUMMARY (
    ENROLMENT_ID NUMBER,
    STUDENT_ID VARCHAR(20),
    COURSE_CODE VARCHAR(20),
    STUDENT_COURSE VARCHAR(100),
    TUITION_FEE NUMBER(10,2),
    AMOUNT_PAID NUMBER(18,2),
    OUTSTANDING_BALANCE NUMBER(18,2),
    PAYMENT_STATE VARCHAR(30)
);

CREATE OR REPLACE PROCEDURE STUDENT.BIZ.REFRESH_BIZ()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN

    MERGE INTO STUDENT.BIZ.TUITION_SUMMARY tgt
    USING (
        SELECT
            e.ENROLMENT_ID,
            e.STUDENT_ID,
            e.COURSE_CODE,

            CONCAT(
                e.STUDENT_ID, ' - ', e.COURSE_CODE
            ) AS STUDENT_COURSE,

            e.TUITION_FEE,

            COALESCE(
                SUM(
                    CASE
                        WHEN p.PAYMENT_STATUS = 'COMPLETED'
                        THEN p.AMOUNT
                        ELSE 0
                    END
                ), 0
            ) AS AMOUNT_PAID,

            e.TUITION_FEE - COALESCE(
                SUM(
                    CASE
                        WHEN p.PAYMENT_STATUS = 'COMPLETED'
                        THEN p.AMOUNT
                        ELSE 0
                    END
                ), 0
            ) AS OUTSTANDING_BALANCE

        FROM STUDENT.CLEAN.ENROLMENTS e
        LEFT JOIN STUDENT.CLEAN.STUDENT_PAYMENTS p
            ON e.ENROLMENT_ID = p.ENROLMENT_ID

        GROUP BY
            e.ENROLMENT_ID,
            e.STUDENT_ID,
            e.COURSE_CODE,
            e.TUITION_FEE
    ) src

    ON tgt.ENROLMENT_ID = src.ENROLMENT_ID

    WHEN MATCHED THEN UPDATE SET
        tgt.STUDENT_ID = src.STUDENT_ID,
        tgt.COURSE_CODE = src.COURSE_CODE,
        tgt.STUDENT_COURSE = src.STUDENT_COURSE,
        tgt.TUITION_FEE = src.TUITION_FEE,
        tgt.AMOUNT_PAID = src.AMOUNT_PAID,
        tgt.OUTSTANDING_BALANCE = src.OUTSTANDING_BALANCE,
        tgt.PAYMENT_STATE =
            CASE
                WHEN src.OUTSTANDING_BALANCE <= 0
                    THEN 'PAID'
                WHEN src.AMOUNT_PAID > 0
                    THEN 'PARTIALLY_PAID'
                ELSE 'UNPAID'
            END

    WHEN NOT MATCHED THEN INSERT (
        ENROLMENT_ID, STUDENT_ID, COURSE_CODE,
        STUDENT_COURSE, TUITION_FEE, AMOUNT_PAID,
        OUTSTANDING_BALANCE, PAYMENT_STATE
    )
    VALUES (
        src.ENROLMENT_ID, src.STUDENT_ID, src.COURSE_CODE,
        src.STUDENT_COURSE, src.TUITION_FEE,
        src.AMOUNT_PAID, src.OUTSTANDING_BALANCE,
        CASE
            WHEN src.OUTSTANDING_BALANCE <= 0
                THEN 'PAID'
            WHEN src.AMOUNT_PAID > 0
                THEN 'PARTIALLY_PAID'
            ELSE 'UNPAID'
        END
    );

    RETURN 'BIZ layer refreshed successfully';

END;
$$;
