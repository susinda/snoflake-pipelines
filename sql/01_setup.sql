
-- ============================================================
-- Project : University Student Data Pipeline
-- Script  : 01_setup.sql
-- Purpose : Initialise Snowflake database objects
-- Domain  : STUDENT
-- Version : 1.0
--
-- Safe to rerun:
--   - Creates missing objects
--   - Preserves existing tables and records
--   - Does not load or transform data
--
-- Prerequisite:
--   Run using a role with privileges to create
--   warehouses, databases, schemas and tables.
-- ============================================================


-- ============================================================
-- 1. COMPUTE WAREHOUSE
-- ============================================================

CREATE WAREHOUSE IF NOT EXISTS STUDENT_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE;

USE WAREHOUSE STUDENT_WH;


-- ============================================================
-- 2. DOMAIN DATABASE
-- ============================================================

CREATE DATABASE IF NOT EXISTS STUDENT;

USE DATABASE STUDENT;


-- ============================================================
-- 3. PROCESSING LAYERS
-- ============================================================

-- Raw source data
CREATE SCHEMA IF NOT EXISTS RAW;

-- Validated and cleaned data
CREATE SCHEMA IF NOT EXISTS CLEAN;

-- Business-ready data
CREATE SCHEMA IF NOT EXISTS BIZ;

-- Pipeline operations and monitoring
CREATE SCHEMA IF NOT EXISTS OPS;


-- ============================================================
-- 4. RAW TABLES
-- ============================================================

USE SCHEMA RAW;


-- 4.1 Student enrolments
CREATE TABLE IF NOT EXISTS ENROLMENTS (
    ENROLMENT_ID     NUMBER(10,0),
    STUDENT_ID       VARCHAR(20),
    COURSE_CODE      VARCHAR(20),
    ENROLMENT_DATE   DATE,
    STATUS           VARCHAR(20),
    TUITION_FEE      NUMBER(10,2),
    UPDATED_AT       TIMESTAMP_NTZ
);


-- 4.2 Student payments
CREATE TABLE IF NOT EXISTS STUDENT_PAYMENTS (
    PAYMENT_ID       VARCHAR(20),
    ENROLMENT_ID     NUMBER(10,0),
    PAYMENT_DATE     DATE,
    AMOUNT           NUMBER(10,2),
    PAYMENT_STATUS   VARCHAR(20),
    UPDATED_AT       TIMESTAMP_NTZ
);


-- ============================================================
-- 5. VERIFY SETUP
-- ============================================================

SHOW SCHEMAS IN DATABASE STUDENT;

SHOW TABLES IN SCHEMA STUDENT.RAW;

-- ============================================================
-- END OF SCRIPT
-- ============================================================
