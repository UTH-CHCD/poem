/*
 * Covariate Index 
 * 
 * 
 * 
 * 
 * 
 */

-- Drop and create a table linking diagnosis codes with covariates
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_cohort_dx_cov_dx;

SELECT * 
INTO CHCDWORK.dbo.poem_cohort_dx_cov_dx
FROM CHCDWORK.dbo.poem_cohort_dx a 
JOIN CHCDWORK.dbo.poem_comorbid_index b 
    ON a.dx_cd = b.dx; 

-- Verify the newly created table
SELECT * FROM CHCDWORK.dbo.poem_cohort_dx_cov_dx;


-- Extract covariates occurring within 280 days prior to the anchor date
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_cohort_cov_280;

SELECT DISTINCT 
    a.client_nbr, 
    a.ep_num, 
    a.anchor_date,
    b.condition, b.smm_weight, b.no_transfusion_weight
INTO CHCDWORK.dbo.poem_cohort_cov_280
FROM CHCDWORK.dbo.poem_cohort a 
JOIN CHCDWORK.dbo.poem_cohort_dx_cov_dx b 
    ON a.client_nbr = b.client_nbr 
    AND b.clm_from_date <= a.anchor_date 
    AND DATEDIFF(day, b.clm_from_date, a.anchor_date) BETWEEN 0 AND 280;

-- Verify the extracted covariate data
SELECT * FROM CHCDWORK.dbo.poem_cohort_cov_280 order by client_nbr;

-- sum all (still excludes age from weight, so need to add that)
drop table if exists CHCDWORK.dbo.poem_cohort_cov_weights ;

SELECT client_nbr, ep_num, 
       sum(smm_weight) as smm_weight, 
       sum(no_transfusion_weight) as no_transfusion_weight
  into CHCDWORK.dbo.poem_cohort_cov_weights 
  FROM CHCDWORK.dbo.poem_cohort_cov_280
  group by client_nbr, ep_num;

--add weight based on age to get final weights 
 drop table if exists CHCDWORK.dbo.poem_cohort_weights;

 with pre_age as (
 SELECT a.client_nbr, a.ep_num, age, 
        COALESCE(b.smm_weight,0) as smm_weight,
        COALESCE(b.no_transfusion_weight,0) as no_transfusion_weight
   FROM CHCDWORK.dbo.poem_cohort a 
   left join CHCDWORK.dbo.poem_cohort_cov_weights b 
   on a.client_nbr = b.client_nbr
   and a.ep_num = b.ep_num
   )
   select client_nbr, ep_num, 
        case when age >= 35 then smm_weight + 2 else smm_weight end as smm_weight,
        case when age >= 35 then no_transfusion_weight + 1 else no_transfusion_weight end as no_transfusion_weight
     into CHCDWORK.dbo.poem_cohort_weights
     from pre_age;
     
    
/*
 * Subgroup-Group Identification
 * 
 * 
 * 
 * 
 * 
 */

------------------
--- Diabetes -----
------------------
 
drop table if exists CHCDWORK.dbo.poem_covariates_dx_dm ;
    
select * 
  into CHCDWORK.dbo.poem_covariates_dx_dm 
  from CHCDWORK.dbo.poem_covariates_dx 
  where variable_name like '%dm%';
  
-- Get all diabetes DX
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_cohort_subgroup_dm1;

SELECT distinct a.client_nbr, a.clm_from_date, b.variable_name
INTO CHCDWORK.dbo.poem_cohort_subgroup_dm1
FROM CHCDWORK.dbo.poem_cohort_dx a 
JOIN CHCDWORK.dbo.poem_covariates_dx_dm b 
    ON a.dx_cd LIKE b.cd_value_sql; 
    
-- Link diabetes DX to anchor dates 
drop table if exists CHCDWORK.dbo.poem_cohort_diab_sample;

SELECT 
    a.client_nbr, 
    a.ep_num,
    CASE 
        WHEN COUNT(b.clm_from_date) > 0 THEN 1 
        ELSE 0 
    END AS diab_sample,
    CASE 
        WHEN MAX(CASE WHEN b.variable_name LIKE '%pre%' THEN 1 ELSE 0 END) = 1 
        THEN 1 ELSE 0 
    END AS pre_existing_diab
INTO CHCDWORK.dbo.poem_cohort_diab_sample
FROM CHCDWORK.dbo.poem_cohort a
LEFT JOIN CHCDWORK.dbo.poem_cohort_subgroup_dm1 b 
    ON a.client_nbr = b.client_nbr 
    AND b.clm_from_date <= a.anchor_date 
    AND DATEDIFF(day, b.clm_from_date, a.anchor_date) BETWEEN 0 AND 280
GROUP BY 
    a.client_nbr, 
    a.ep_num;
 
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_cohort_subgroup_dm1;

------------------
--- HTN -----
------------------
 
drop table if exists CHCDWORK.dbo.poem_covariates_dx_htn ;
    
select * 
  into CHCDWORK.dbo.poem_covariates_dx_htn 
  from CHCDWORK.dbo.poem_covariates_dx 
  where variable_name like '%htn%';
  
-- Get all HTN DX
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_cohort_subgroup_htn1;

SELECT distinct a.client_nbr, a.clm_from_date
INTO CHCDWORK.dbo.poem_cohort_subgroup_htn1
FROM CHCDWORK.dbo.poem_cohort_dx a 
JOIN CHCDWORK.dbo.poem_covariates_dx_htn b 
    ON a.dx_cd LIKE b.cd_value_sql; 
    
-- Link diabetes DX to anchor dates 
drop table if exists CHCDWORK.dbo.poem_cohort_htn_sample;

SELECT 
    a.client_nbr, 
    a.ep_num,
    CASE 
        WHEN COUNT(b.clm_from_date) > 0 THEN 1 
        ELSE 0 
    END AS htn_sample
into CHCDWORK.dbo.poem_cohort_htn_sample
FROM CHCDWORK.dbo.poem_cohort a
LEFT JOIN CHCDWORK.dbo.poem_cohort_subgroup_htn1 b 
    ON a.client_nbr = b.client_nbr 
    AND b.clm_from_date <= a.anchor_date 
    AND DATEDIFF(day, b.clm_from_date, a.anchor_date) BETWEEN 0 AND 280
GROUP BY 
    a.client_nbr, 
    a.ep_num;  
 
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_cohort_subgroup_htn1;
 