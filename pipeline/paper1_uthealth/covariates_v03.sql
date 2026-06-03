-- ============================================================
-- Covariate Index
-- Converted from SQL Server to Greenplum/PostgreSQL
-- Schema: dev (replaces CHCDWORK.dbo)
--
-- Key conversions:
--   SELECT * INTO            → CREATE TABLE AS
--   DATEDIFF(day, d1, d2)    → (d2 - d1)  [integer days between dates]
--   LIKE b.dx + '%'          → dx_cd LIKE (b.dx || '%')
-- ============================================================

/* -------------------------------------------------
 * Comorbidity index: DX-to-condition linkage
 * ------------------------------------------------ */

DROP TABLE IF EXISTS dev.poem_cohort_dx_cov_dx;

CREATE TABLE dev.poem_cohort_dx_cov_dx AS
SELECT a.*, b.*
FROM dev.poem_cohort_dx a
JOIN dev.poem_comorbid_index b
    ON a.dx_cd LIKE (b.dx || '%');


/* -------------------------------------------------
 * Covariates within 280 days before anchor date
 * ------------------------------------------------ */

DROP TABLE IF EXISTS dev.poem_cohort_cov_280;

CREATE TABLE dev.poem_cohort_cov_280 AS
SELECT DISTINCT
    a.client_nbr,
    a.ep_num,
    a.anchor_date,
    b.condition,
    b.smm_weight,
    b.no_transfusion_weight
FROM dev.poem_cohort a
JOIN dev.poem_cohort_dx_cov_dx b
    ON a.client_nbr = b.client_nbr
   AND b.clm_from_date <= a.anchor_date
   AND (a.anchor_date - b.clm_from_date) BETWEEN 0 AND 280;


/* -------------------------------------------------
 * Sum weights (age weight added below)
 * ------------------------------------------------ */

DROP TABLE IF EXISTS dev.poem_cohort_cov_weights;

CREATE TABLE dev.poem_cohort_cov_weights AS
SELECT
    client_nbr,
    ep_num,
    SUM(smm_weight)            AS smm_weight,
    SUM(no_transfusion_weight) AS no_transfusion_weight
FROM dev.poem_cohort_cov_280
GROUP BY client_nbr, ep_num;


-- Add age-based weight to get final weights
DROP TABLE IF EXISTS dev.poem_cohort_weights;

CREATE TABLE dev.poem_cohort_weights AS
WITH pre_age AS (
    SELECT
        a.client_nbr,
        a.ep_num,
        a.age,
        COALESCE(b.smm_weight,            0) AS smm_weight,
        COALESCE(b.no_transfusion_weight, 0) AS no_transfusion_weight
    FROM dev.poem_cohort a
    LEFT JOIN dev.poem_cohort_cov_weights b
        ON a.client_nbr = b.client_nbr
       AND a.ep_num     = b.ep_num
)
SELECT
    client_nbr,
    ep_num,
    CASE WHEN age >= 35 THEN smm_weight            + 2 ELSE smm_weight            END AS smm_weight,
    CASE WHEN age >= 35 THEN no_transfusion_weight + 1 ELSE no_transfusion_weight END AS no_transfusion_weight
FROM pre_age;


/* ==========================================================
 * Subgroup Identification
 * ========================================================== */

------------------
-- Diabetes
------------------

DROP TABLE IF EXISTS dev.poem_covariates_dx_dm;

CREATE TABLE dev.poem_covariates_dx_dm AS
SELECT *
FROM dev.poem_covariates_dx
WHERE variable_name LIKE '%dm%';

-- All diabetes DX codes
DROP TABLE IF EXISTS dev.poem_cohort_subgroup_dm1;

CREATE TABLE dev.poem_cohort_subgroup_dm1 AS
SELECT DISTINCT a.client_nbr, a.clm_from_date, b.variable_name
FROM dev.poem_cohort_dx a
JOIN dev.poem_covariates_dx_dm b ON a.dx_cd LIKE b.cd_value_sql;

-- Link to anchor dates
DROP TABLE IF EXISTS dev.poem_cohort_diab_sample;

CREATE TABLE dev.poem_cohort_diab_sample AS
SELECT
    a.client_nbr,
    a.ep_num,
    CASE WHEN COUNT(b.clm_from_date) > 0 THEN 1 ELSE 0 END AS diab_sample,
    MAX(CASE WHEN b.variable_name LIKE '%pre%'  THEN 1 ELSE 0 END) AS pre_existing_diab,
    MAX(CASE WHEN b.variable_name LIKE '%gest%' THEN 1 ELSE 0 END) AS gest_diab
FROM dev.poem_cohort a
LEFT JOIN dev.poem_cohort_subgroup_dm1 b
    ON a.client_nbr = b.client_nbr
   AND b.clm_from_date <= a.anchor_date
   AND (a.anchor_date - b.clm_from_date) BETWEEN 0 AND 280
GROUP BY a.client_nbr, a.ep_num;

DROP TABLE IF EXISTS dev.poem_cohort_subgroup_dm1;


------------------
-- Hypertension
------------------

DROP TABLE IF EXISTS dev.poem_covariates_dx_htn;

CREATE TABLE dev.poem_covariates_dx_htn AS
SELECT *
FROM dev.poem_covariates_dx
WHERE variable_name LIKE '%htn%';

-- All HTN DX codes
DROP TABLE IF EXISTS dev.poem_cohort_subgroup_htn1;

CREATE TABLE dev.poem_cohort_subgroup_htn1 AS
SELECT DISTINCT a.client_nbr, a.clm_from_date, b.variable_name
FROM dev.poem_cohort_dx a
JOIN dev.poem_covariates_dx_htn b ON a.dx_cd LIKE b.cd_value_sql;

-- Link to anchor dates
DROP TABLE IF EXISTS dev.poem_cohort_htn_sample;

CREATE TABLE dev.poem_cohort_htn_sample AS
SELECT
    a.client_nbr,
    a.ep_num,
    CASE WHEN COUNT(b.clm_from_date) > 0 THEN 1 ELSE 0 END AS htn_sample,
    MAX(CASE WHEN b.variable_name = 'com_pre_htn'            THEN 1 ELSE 0 END) AS htn_chronic,
    MAX(CASE WHEN b.variable_name = 'com_gest_htn'           THEN 1 ELSE 0 END) AS htn_gestational,
    MAX(CASE WHEN b.variable_name = 'com_pre_htn_superimposed' THEN 1 ELSE 0 END) AS htn_preeclampsia,
    MAX(CASE WHEN b.variable_name = 'com_pulm_htn'           THEN 1 ELSE 0 END) AS htn_pulmonary
FROM dev.poem_cohort a
LEFT JOIN dev.poem_cohort_subgroup_htn1 b
    ON a.client_nbr = b.client_nbr
   AND b.clm_from_date <= a.anchor_date
   AND (a.anchor_date - b.clm_from_date) BETWEEN 0 AND 280
GROUP BY a.client_nbr, a.ep_num;

DROP TABLE IF EXISTS dev.poem_cohort_subgroup_htn1;


------------------
-- Mental Health
------------------

-- All MH DX with categories
DROP TABLE IF EXISTS dev.poem_cohort_subgroup_mh1;

CREATE TABLE dev.poem_cohort_subgroup_mh1 AS
SELECT DISTINCT
    a.client_nbr,
    a.clm_from_date,
    b.mh_category
FROM dev.poem_cohort_dx a
JOIN dev.poem_mh_dx b ON a.dx_cd = b.icd_dx;

-- MH DX linked to anchor dates
DROP TABLE IF EXISTS dev.poem_cohort_mh_sample_detail;

CREATE TABLE dev.poem_cohort_mh_sample_detail AS
SELECT
    a.client_nbr,
    a.ep_num,
    b.mh_category,
    COUNT(b.clm_from_date) AS dx_count
FROM dev.poem_cohort a
INNER JOIN dev.poem_cohort_subgroup_mh1 b
    ON a.client_nbr = b.client_nbr
   AND b.clm_from_date <= a.anchor_date
   AND (a.anchor_date - b.clm_from_date) BETWEEN 0 AND 280
GROUP BY a.client_nbr, a.ep_num, b.mh_category;

-- One row per client+episode
DROP TABLE IF EXISTS dev.poem_cohort_mh_sample;

CREATE TABLE dev.poem_cohort_mh_sample AS
SELECT
    a.client_nbr,
    a.ep_num,
    CASE WHEN COUNT(b.clm_from_date) > 0 THEN 1 ELSE 0 END AS mh_sample,
    MAX(CASE WHEN b.mh_category = 'Anxiety and fear-related disorders'               THEN 1 ELSE 0 END) AS mh_anxiety,
    MAX(CASE WHEN b.mh_category = 'Depressive disorders'                              THEN 1 ELSE 0 END) AS mh_depression,
    MAX(CASE WHEN b.mh_category = 'Suicidal ideation/attempt/intentional self-harm'  THEN 1 ELSE 0 END) AS mh_suicidal,
    MAX(CASE WHEN b.mh_category = 'Schizophrenia spectrum/other pyschotic disorders' THEN 1 ELSE 0 END) AS mh_schizophrenia,
    MAX(CASE WHEN b.mh_category = 'Trauma- and stressor-related disorders'           THEN 1 ELSE 0 END) AS mh_trauma,
    MAX(CASE WHEN b.mh_category = 'Bipolar and related disorders'                    THEN 1 ELSE 0 END) AS mh_bipolar,
    MAX(CASE WHEN b.mh_category = 'Other - neurodevelopmental disorders'             THEN 1 ELSE 0 END) AS mh_neurodevelopmental,
    MAX(CASE WHEN b.mh_category = 'Other - other disorders'                          THEN 1 ELSE 0 END) AS mh_other
FROM dev.poem_cohort a
LEFT JOIN dev.poem_cohort_subgroup_mh1 b
    ON a.client_nbr = b.client_nbr
   AND b.clm_from_date <= a.anchor_date
   AND (a.anchor_date - b.clm_from_date) BETWEEN 0 AND 280
GROUP BY a.client_nbr, a.ep_num;

DROP TABLE IF EXISTS dev.poem_cohort_subgroup_mh1;
