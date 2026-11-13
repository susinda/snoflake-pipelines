
-- ============================================================
-- GitHub Actions -> Snowflake OIDC Configuration
-- Repository : susinda/snoflake-pipelines
-- Branch     : main
-- Environment: DEV
-- ============================================================

-- STEP 1: Select admin role
USE ROLE ACCOUNTADMIN;

SELECT 'STEP 1: ACCOUNTADMIN role selected' AS LOG,
       CURRENT_ROLE() AS ACTIVE_ROLE;


-- STEP 2: Create deployment role
CREATE ROLE IF NOT EXISTS STUDENT_DEPLOY_ROLE;

SELECT 'STEP 2: Deployment role exists' AS LOG;


-- STEP 3: Create GitHub service user
CREATE USER IF NOT EXISTS GITHUB_CICD_USER
    TYPE = SERVICE
    DEFAULT_ROLE = STUDENT_DEPLOY_ROLE
    COMMENT = 'GitHub Actions deployment user';

SELECT 'STEP 3: Service user exists' AS LOG;


-- STEP 4: Configure GitHub OIDC authentication
ALTER USER GITHUB_CICD_USER SET
    WORKLOAD_IDENTITY = (
        TYPE = OIDC
        ISSUER = 'https://token.actions.githubusercontent.com'
        SUBJECT = 'repo:susinda/snoflake-pipelines:ref:refs/heads/main'
    )
    DEFAULT_ROLE = STUDENT_DEPLOY_ROLE;

SELECT 'STEP 4: OIDC configuration applied' AS LOG;


-- STEP 5: Grant deployment role to service user
GRANT ROLE STUDENT_DEPLOY_ROLE
    TO USER GITHUB_CICD_USER;

SELECT 'STEP 5: Deployment role granted to service user'
       AS LOG;


-- STEP 6: Allow creation of student database
GRANT CREATE DATABASE ON ACCOUNT
    TO ROLE STUDENT_DEPLOY_ROLE;

SELECT 'STEP 6: CREATE DATABASE privilege granted'
       AS LOG;


-- STEP 7: Allow creation of compute warehouse
GRANT CREATE WAREHOUSE ON ACCOUNT
    TO ROLE STUDENT_DEPLOY_ROLE;

SELECT 'STEP 7: CREATE WAREHOUSE privilege granted'
       AS LOG;


-- STEP 8: Add role to SYSADMIN hierarchy
GRANT ROLE STUDENT_DEPLOY_ROLE TO ROLE SYSADMIN;

SELECT 'STEP 8: Role added to SYSADMIN hierarchy'
       AS LOG;


-- ============================================================
-- VERIFICATION
-- ============================================================

SHOW ROLES LIKE 'STUDENT_DEPLOY_ROLE';

SHOW USERS LIKE 'GITHUB_CICD_USER';

SHOW GRANTS TO ROLE STUDENT_DEPLOY_ROLE;

SHOW GRANTS TO USER GITHUB_CICD_USER;

SHOW USER WORKLOAD IDENTITY AUTHENTICATION METHODS
    FOR USER GITHUB_CICD_USER;

SELECT 'SETUP SQL COMPLETED - CHECK RESULTS ABOVE'
       AS LOG;
