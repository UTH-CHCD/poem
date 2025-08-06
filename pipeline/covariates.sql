
/*
 * Covariate Index 
 */

-- Drop and create a table linking diagnosis codes with covariates
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_cohort_dx_cov_dx;

SELECT * 
INTO CHCDWORK.dbo.poem_cohort_dx_cov_dx
FROM CHCDWORK.dbo.poem_cohort_dx a 
JOIN CHCDWORK.dbo.poem_covariates_dx b 
    ON a.dx_cd LIKE b.cd_value_sql; 

-- Verify the newly created table
SELECT * FROM CHCDWORK.dbo.poem_cohort_dx_cov_dx;

-- Remove diagnosis exclusions
DELETE FROM CHCDWORK.dbo.poem_cohort_dx_cov_dx 
WHERE dx_cd LIKE 'D688%' OR dx_cd LIKE 'D689%';

-- Drop and create a table linking ICD codes with covariates
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_cohort_dx_cov_icd;

SELECT * 
INTO CHCDWORK.dbo.poem_cohort_dx_cov_icd
FROM CHCDWORK.dbo.poem_cohort_icd a 
JOIN CHCDWORK.dbo.poem_covariates_icd b 
    ON a.icd_cd LIKE b.cd_value_sql; 

-- Create a shell table containing all possible client-episode and covariate name combinations
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_cohort_cov_shell;

WITH ids AS (
    SELECT DISTINCT client_nbr, episode_id 
    FROM CHCDWORK.dbo.poem_cohort
),
var_names AS (
    SELECT DISTINCT variable_name 
    FROM CHCDWORK.dbo.poem_covariates_dx
    UNION
    SELECT DISTINCT variable_name 
    FROM CHCDWORK.dbo.poem_covariates_icd
)
SELECT * 
INTO CHCDWORK.dbo.poem_cohort_cov_shell
FROM ids, var_names
ORDER BY client_nbr, episode_id;

-- Extract covariates occurring within 280 days prior to the anchor date
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_cohort_cov_280;

SELECT DISTINCT 
    a.client_nbr, 
    a.episode_id, 
    a.ep_num, 
    a.anchor_date,
    DATEDIFF(day, b.clm_from_date, a.anchor_date) AS days_prior,
    b.clm_from_date, 
    b.category,  
    b.variable_name, 
    b.cd_value, 
    b.cd_type
INTO CHCDWORK.dbo.poem_cohort_cov_280
FROM CHCDWORK.dbo.poem_cohort a 
JOIN CHCDWORK.dbo.poem_cohort_cov b 
    ON a.client_nbr = b.client_nbr 
    AND b.clm_from_date <= a.anchor_date 
    AND DATEDIFF(day, b.clm_from_date, a.anchor_date) BETWEEN 0 AND 280;

-- Verify the extracted covariate data
SELECT * FROM CHCDWORK.dbo.poem_cohort_cov_280;

-- Create a shell table containing all possible client-episode and covariate name combinations
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_cohort_cov_shell;

WITH ids AS (
    SELECT DISTINCT client_nbr, episode_id FROM CHCDWORK.dbo.poem_cohort
),
var_names AS (
    SELECT DISTINCT variable_name FROM CHCDWORK.dbo.poem_covariates
)
SELECT * 
INTO CHCDWORK.dbo.poem_cohort_cov_shell
FROM ids, var_names
ORDER BY client_nbr, episode_id;

-- Collapse covariate data into a binary presence indicator (0/1)
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_cohort_cov_collapse;

SELECT 
    a.*, 
    MAX(CASE WHEN b.client_nbr IS NULL THEN 0 ELSE 1 END) AS cov_yes
INTO CHCDWORK.dbo.poem_cohort_cov_collapse
FROM CHCDWORK.dbo.poem_cohort_cov_shell a 
LEFT JOIN CHCDWORK.dbo.poem_cohort_cov_280 b 
    ON a.client_nbr = b.client_nbr
    AND a.episode_id = b.episode_id 
    AND a.variable_name = b.variable_name
GROUP BY a.client_nbr, a.episode_id, a.variable_name;

-- Verify the collapsed covariate data
SELECT * FROM CHCDWORK.dbo.poem_cohort_cov_collapse;