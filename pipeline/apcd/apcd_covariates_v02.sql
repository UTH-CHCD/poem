/*
 * Covariate Index 
 */

-- Drop and create a table linking diagnosis codes with covariates
DROP TABLE IF EXISTS research_dev.poem_cohort_dx_cov_dx;

CREATE TABLE research_dev.poem_cohort_dx_cov_dx as
SELECT distinct a.apcd_id, 
       a.dos,
       b.condition, 
       b.smm_weight, 
       b.no_transfusion_weight
FROM research_dev.med_dx_poem a 
JOIN research_dev.poem_comorbid_index b 
    ON a.dx = b.dx
  join research_dev.poem_cohort c 
    on a.apcd_id = c.apcd_id
; 

-- Extract covariates occurring within 280 days prior to the anchor date
DROP TABLE IF EXISTS research_dev.poem_cohort_cov_280;

CREATE TABLE research_dev.poem_cohort_cov_280 AS
SELECT DISTINCT 
    a.apcd_id, 
    a.ep_num, 
    a.anchor_date,
    b.condition, 
    b.smm_weight, 
    b.no_transfusion_weight
FROM research_dev.poem_cohort a 
JOIN research_dev.poem_cohort_dx_cov_dx b 
    ON a.apcd_id = b.apcd_id 
    AND b.dos <= a.anchor_date 
    AND (a.anchor_date - b.dos) BETWEEN 0 AND 280;

-- sum all (still excludes age from weight, so need to add that)
DROP TABLE IF EXISTS research_dev.poem_cohort_cov_weights;

CREATE TABLE research_dev.poem_cohort_cov_weights AS
SELECT apcd_id, 
       ep_num, 
       sum(smm_weight) as smm_weight, 
       sum(no_transfusion_weight) as no_transfusion_weight
FROM research_dev.poem_cohort_cov_280
GROUP BY apcd_id, ep_num;

-- add weight based on age to get final weights 
DROP TABLE IF EXISTS research_dev.poem_cohort_weights;

CREATE TABLE research_dev.poem_cohort_weights AS
WITH pre_age AS (
    SELECT a.apcd_id, 
           a.ep_num, 
           age, 
           COALESCE(b.smm_weight, 0) as smm_weight,
           COALESCE(b.no_transfusion_weight, 0) as no_transfusion_weight
    FROM research_dev.poem_cohort a 
    LEFT JOIN research_dev.poem_cohort_cov_weights b 
        ON a.apcd_id = b.apcd_id
       AND a.ep_num = b.ep_num
)
SELECT apcd_id, 
       ep_num, 
       CASE WHEN age >= 35 THEN smm_weight + 2 ELSE smm_weight END as smm_weight,
       CASE WHEN age >= 35 THEN no_transfusion_weight + 1 ELSE no_transfusion_weight END as no_transfusion_weight
FROM pre_age;



/*
 * Subgroup-Group Identification
 */

------------------
--- Diabetes -----
------------------
 
DROP TABLE IF EXISTS research_dev.poem_covariates_dx_dm;
    
CREATE TABLE research_dev.poem_covariates_dx_dm AS
SELECT * 
FROM research_dev.poem_covariates_dx 
WHERE variable_name LIKE '%dm%';
  
-- Get all diabetes DX
DROP TABLE IF EXISTS research_dev.poem_cohort_subgroup_dm1;

CREATE TABLE research_dev.poem_cohort_subgroup_dm1 AS
SELECT DISTINCT a.apcd_id, a.dos, b.variable_name
FROM research_dev.med_dx_poem a 
JOIN research_dev.poem_covariates_dx_dm b 
    ON a.dx LIKE b.cd_value_sql
where a.apcd_id in (select apcd_id from  research_dev.poem_cohort); 
    
-- Link diabetes DX to anchor dates 
DROP TABLE IF EXISTS research_dev.poem_cohort_diab_sample;

CREATE TABLE research_dev.poem_cohort_diab_sample AS
SELECT 
    a.apcd_id, 
    a.ep_num,
    CASE 
        WHEN COUNT(b.dos) > 0 THEN 1 
        ELSE 0 
    END AS diab_sample,
    CASE 
        WHEN MAX(CASE WHEN b.variable_name LIKE '%pre%' THEN 1 ELSE 0 END) = 1 
        THEN 1 ELSE 0 
    END AS pre_existing_diab
FROM research_dev.poem_cohort a
LEFT JOIN research_dev.poem_cohort_subgroup_dm1 b 
    ON a.apcd_id = b.apcd_id 
    AND b.dos <= a.anchor_date 
    AND (a.anchor_date - b.dos) BETWEEN 0 AND 280
GROUP BY 
    a.apcd_id, 
    a.ep_num;
 
DROP TABLE IF EXISTS research_dev.poem_cohort_subgroup_dm1;

------------------
--- HTN -----
------------------
 
DROP TABLE IF EXISTS research_dev.poem_covariates_dx_htn;
    
CREATE TABLE research_dev.poem_covariates_dx_htn AS
SELECT * 
FROM research_dev.poem_covariates_dx 
WHERE variable_name LIKE '%htn%';
  
-- Get all HTN DX
DROP TABLE IF EXISTS research_dev.poem_cohort_subgroup_htn1;

CREATE TABLE research_dev.poem_cohort_subgroup_htn1 AS
SELECT DISTINCT a.apcd_id, a.dos
FROM research_dev.med_dx_poem a 
JOIN research_dev.poem_covariates_dx_htn b 
    ON a.dx LIKE b.cd_value_sql
 where a.apcd_id in (select apcd_id from  research_dev.poem_cohort); 
    
-- Link HTN DX to anchor dates 
DROP TABLE IF EXISTS research_dev.poem_cohort_htn_sample;

CREATE TABLE research_dev.poem_cohort_htn_sample AS
SELECT 
    a.apcd_id, 
    a.ep_num,
    CASE 
        WHEN COUNT(b.dos) > 0 THEN 1 
        ELSE 0 
    END AS htn_sample
FROM research_dev.poem_cohort a
LEFT JOIN research_dev.poem_cohort_subgroup_htn1 b 
    ON a.apcd_id = b.apcd_id 
    AND b.dos <= a.anchor_date 
    AND (a.anchor_date - b.dos) BETWEEN 0 AND 280
GROUP BY 
    a.apcd_id, 
    a.ep_num;  
 
DROP TABLE IF EXISTS research_dev.poem_cohort_subgroup_htn1;


------------------
--- Mental Health -----
------------------
 
-- all mh DX with categories
DROP TABLE IF EXISTS research_dev.poem_cohort_subgroup_mh1;

CREATE TABLE research_dev.poem_cohort_subgroup_mh1 AS
SELECT DISTINCT 
    a.apcd_id, 
    a.dos,
    b.mh_category
FROM research_dev.med_dx_poem a 
JOIN research_dev.poem_mh_dx b 
    ON a.dx = b.icd_dx
  where a.apcd_id in (select apcd_id from  research_dev.poem_cohort);

-- mental health DX to anchor dates with categories
DROP TABLE IF EXISTS research_dev.poem_cohort_mh_sample_detail;

CREATE TABLE research_dev.poem_cohort_mh_sample_detail AS
SELECT 
    a.apcd_id, 
    a.ep_num,
    b.mh_category,
    COUNT(b.dos) AS dx_count
FROM research_dev.poem_cohort a
INNER JOIN research_dev.poem_cohort_subgroup_mh1 b 
    ON a.apcd_id = b.apcd_id 
    AND b.dos <= a.anchor_date 
    AND (a.anchor_date - b.dos) BETWEEN 0 AND 280
GROUP BY 
    a.apcd_id, 
    a.ep_num,
    b.mh_category;

-- one row per apcd_id and ep_num if they had any mh dx
DROP TABLE IF EXISTS research_dev.poem_cohort_mh_sample;

CREATE TABLE research_dev.poem_cohort_mh_sample AS
SELECT 
    a.apcd_id, 
    a.ep_num,
    CASE 
        WHEN COUNT(b.dos) > 0 THEN 1 
        ELSE 0 
    END AS mh_sample
FROM research_dev.poem_cohort a
LEFT JOIN research_dev.poem_cohort_subgroup_mh1 b 
    ON a.apcd_id = b.apcd_id 
    AND b.dos <= a.anchor_date 
    AND (a.anchor_date - b.dos) BETWEEN 0 AND 280
GROUP BY 
    a.apcd_id, 
    a.ep_num;  
 
DROP TABLE IF EXISTS research_dev.poem_cohort_subgroup_mh1;