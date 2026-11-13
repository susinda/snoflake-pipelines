
-- ============================================================
-- Project : Snowflake Student Data Pipeline
-- File    : sql/0_serviceuser.sql
-- Purpose : Bootstrap GitHub Actions deployment access
--
-- Repository: susinda/snoflake-pipelines
-- Branch    : main
--
-- IMPORTANT:
-- Run manually in Snowsight using ACCOUNTADMIN.
-- Do not execute from GitHub Actions.
-- ============================================================


-- ============================================================
-- STEP 1: Select administrator role
-- ============================================================

USE ROLE ACCOUNTADMIN;

SELECT
    'STEP 1: Administrator selected' AS LOG,
    CURRENT_ROLE() AS ACTIVE_ROLE,
    CURRENT_ACCOUNT() AS ACCOUNT_LOCATOR;


-- ============================================================
-- STEP 2: Create deployment role
-- ============================================================

CREATE ROLE IF NOT EXISTS STUDENT_DEPLOY_ROLE
    COMMENT = 'Deployment role for student data pipeline';

SELECT 'STEP 2: Deployment role ready' AS LOG;


-- ============================================================
-- STEP 3: Create service user if missing
-- ============================================================

CREATE USER IF NOT EXISTS GITHUB_CICD_USER
    TYPE = SERVICE
    DEFAULT_ROLE = STUDENT_DEPLOY_ROLE
    COMMENT = 'GitHub Actions OIDC deployment identity';

SELECT 'STEP 3: Service user ready' AS LOG;


-- ============================================================
-- STEP 4: Configure GitHub OIDC
-- Verified subject from GitHub Actions authentication log
-- ============================================================

ALTER USER GITHUB_CICD_USER SET
    WORKLOAD_IDENTITY = (
        TYPE = OIDC
        ISSUER = 'https://token.actions.githubusercontent.com'
        SUBJECT = 'repo:susinda@4962136/snoflake-pipelines@1455980966:ref:refs/heads/main'
    )
    DEFAULT_ROLE = STUDENT_DEPLOY_ROLE;

SELECT 'STEP 4: GitHub OIDC configured' AS LOG;


-- ============================================================
-- STEP 5: Grant deployment role to service user
-- ============================================================

GRANT ROLE STUDENT_DEPLOY_ROLE
    TO USER GITHUB_CICD_USER;

SELECT 'STEP 5: Service user role granted' AS LOG;


-- ============================================================
-- STEP 6: Allow creation of database and warehouse
-- ============================================================

GRANT CREATE DATABASE ON ACCOUNT
    TO ROLE STUDENT_DEPLOY_ROLE;

SELECT 'STEP 6: CREATE DATABASE privilege granted' AS LOG;

GRANT CREATE WAREHOUSE ON ACCOUNT
    TO ROLE STUDENT_DEPLOY_ROLE;

SELECT 'STEP 7: CREATE WAREHOUSE privilege granted' AS LOG;


-- ============================================================
-- STEP 7: Configure role hierarchy
-- ============================================================

GRANT ROLE STUDENT_DEPLOY_ROLE
    TO ROLE SYSADMIN;

SELECT 'STEP 8: Role hierarchy configured' AS LOG;


-- ============================================================
-- STEP 8: Verify role, user and privileges
-- ============================================================

SHOW ROLES LIKE 'STUDENT_DEPLOY_ROLE';

SHOW USERS LIKE 'GITHUB_CICD_USER';

SHOW GRANTS TO ROLE STUDENT_DEPLOY_ROLE;

SHOW GRANTS TO USER GITHUB_CICD_USER;

SHOW USER WORKLOAD IDENTITY AUTHENTICATION METHODS
    FOR USER GITHUB_CICD_USER;


-- ============================================================
-- STEP 9: Final status
-- ============================================================

SELECT
    'Bootstrap statements finished; inspect grants above'
    AS LOG;

-- ============================================================
-- END
-- ============================================================
