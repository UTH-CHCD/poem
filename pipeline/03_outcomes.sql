
/*
 * Outcomes for POEM Project 
 * 
 * Enrollment
 * Outpatient Contact 
 * 
 */


/*
 * See who had any healthcare 3 to 12 months after anchor date
 */
drop table if exists CHCDWORK.dbo.poem_cohort_all_dates_3_12;
-- Create temp table with filtered dates (3-12 months after anchor_date)
WITH get_all AS (
    SELECT pcn AS client_nbr, to_dos AS service_date
    FROM CHCDWORK.dbo.clm_detail a 
    JOIN CHCDWORK.dbo.clm_proc b 
        ON b.icn = a.icn
    UNION ALL  
    SELECT mem_id AS client_nbr, to_date AS service_date
    FROM CHCDWORK.dbo.enc_detail a 
    JOIN CHCDWORK.dbo.enc_proc b 
        ON b.derv_enc = a.derv_enc
)
SELECT DISTINCT a.*
INTO CHCDWORK.dbo.poem_cohort_all_dates_3_12
FROM get_all a 
JOIN CHCDWORK.dbo.poem_cohort b 
    ON a.client_nbr = b.client_nbr
WHERE a.service_date >= DATEADD(MONTH, 3, b.anchor_date)  -- At least 3 months after
  AND a.service_date <= DATEADD(MONTH, 12, b.anchor_date); -- Within 12 months after
  
-- Final query to get all client_nbr/ep_num combinations with 0/1 flag for claims in target window
drop table if exists CHCDWORK.dbo.poem_outcomes_3_12_months; 
SELECT 
    a.client_nbr, 
    a.ep_num,
    MAX(CASE WHEN b.client_nbr IS NOT NULL THEN 1 ELSE 0 END) AS had_claims_3_12_months
into CHCDWORK.dbo.poem_outcomes_3_12_months
FROM CHCDWORK.dbo.poem_cohort a
LEFT JOIN CHCDWORK.dbo.poem_cohort_all_dates_3_12 b 
    ON a.client_nbr = b.client_nbr
GROUP BY a.client_nbr, a.ep_num;

/*
 * See who had any healthcare 0 to 12 months after anchor date
 */
drop table if exists CHCDWORK.dbo.poem_cohort_all_dates_0_12;

-- Create temp table with filtered dates (0-12 months after anchor_date)
WITH get_all AS (
    SELECT pcn AS client_nbr, to_dos AS service_date
    FROM CHCDWORK.dbo.clm_detail a 
    JOIN CHCDWORK.dbo.clm_proc b 
        ON b.icn = a.icn
    UNION ALL  
    SELECT mem_id AS client_nbr, to_date AS service_date
    FROM CHCDWORK.dbo.enc_detail a 
    JOIN CHCDWORK.dbo.enc_proc b 
        ON b.derv_enc = a.derv_enc
)
SELECT DISTINCT a.*
INTO CHCDWORK.dbo.poem_cohort_all_dates_0_12
FROM get_all a 
JOIN CHCDWORK.dbo.poem_cohort b 
    ON a.client_nbr = b.client_nbr
WHERE a.service_date > b.anchor_date  -- From anchor date (0 months after)
  AND a.service_date <= DATEADD(MONTH, 12, b.anchor_date); -- Within 12 months after
  
-- Final query to get all client_nbr/ep_num combinations with 0/1 flag for claims in target window
drop table if exists CHCDWORK.dbo.poem_outcomes_0_12_months; 
SELECT 
    a.client_nbr, 
    a.ep_num,
    MAX(CASE WHEN b.client_nbr IS NOT NULL THEN 1 ELSE 0 END) AS had_claims_0_12_months
into CHCDWORK.dbo.poem_outcomes_0_12_months
FROM CHCDWORK.dbo.poem_cohort a
LEFT JOIN CHCDWORK.dbo.poem_cohort_all_dates_0_12 b 
    ON a.client_nbr = b.client_nbr
GROUP BY a.client_nbr, a.ep_num;

/* ------------------------------------------------------
 * Enrollment
 * 
 * Check to see if that person is enrolled 90 days later 
 * 90 Days begins the day AFTER the anchor day
 */ -----------------------------------------------------

DROP TABLE IF EXISTS CHCDWORK.dbo.poem_outcomes_enrollment;

SELECT  distinct 
    c.client_nbr,
    c.ep_num,
    CASE WHEN d90.client_nbr IS NOT NULL THEN 1 ELSE 0 END AS out_enroll_90,
    CASE WHEN d12.client_nbr IS NOT NULL THEN 1 ELSE 0 END AS out_enroll_12
INTO CHCDWORK.dbo.poem_outcomes_enrollment
FROM chcdwork.dbo.poem_cohort c
LEFT JOIN chcdwork.dbo.poem_demographics AS d90
    ON d90.client_nbr = c.client_nbr
   AND YEAR(d90.elig_month)  = YEAR(DATEADD(DAY, 91, c.anchor_date))
   AND MONTH(d90.elig_month) = MONTH(DATEADD(DAY, 91, c.anchor_date))
LEFT JOIN chcdwork.dbo.poem_demographics AS d12
    ON d12.client_nbr = c.client_nbr
   AND YEAR(d12.elig_month)  = YEAR(DATEADD(YEAR, 1, DATEADD(DAY, 1, c.anchor_date)))
   AND MONTH(d12.elig_month) = MONTH(DATEADD(YEAR, 1, DATEADD(DAY, 1, c.anchor_date)));
   
/* ----------------------------------
 * Preventitive/E&M Visits 
 * -----------------------------------*/

DROP TABLE IF EXISTS CHCDWORK.dbo.poem_outcomes_prev_em;

-- Create the new outcome table
SELECT
    c.client_nbr,
    c.ep_num,
    c.anchor_date,
    CASE WHEN COUNT(p.proc_cd) > 0 THEN 1 ELSE 0 END AS out_prev_em
INTO CHCDWORK.dbo.poem_outcomes_prev_em
FROM
    chcdwork.dbo.poem_cohort c
LEFT JOIN
    chcdwork.dbo.poem_cohort_cpt p
    ON c.client_nbr = p.client_nbr
    AND (
        (p.proc_cd BETWEEN '99202' AND '99215') OR
        (p.proc_cd BETWEEN '99381' AND '99429') OR
        p.proc_cd IN ('99441', '99442', '99443')
    )
    AND p.to_dos BETWEEN DATEADD(day, 7, c.anchor_date) AND DATEADD(day, 84, c.anchor_date)
GROUP BY
    c.client_nbr,
    c.ep_num,
    c.anchor_date;

select * from CHCDWORK.dbo.poem_outcomes_prev_em;


/* --------------------------------------
 * Postpartum Visits
 * --------------------------------------
 */

/* Drop the temporary table if it exists */
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_outcomes_postpartum_temp;

/* Create the temporary table with code type and code */
SELECT DISTINCT
    p.client_nbr,
    p.to_dos,
    'CPT' AS code_type,
    p.proc_cd AS code
INTO CHCDWORK.dbo.poem_outcomes_postpartum_temp
FROM CHCDWORK.dbo.poem_cohort_cpt p
WHERE p.proc_cd IN ('59430', '57170', '58300', '88141', '88142', '88143', '88147', '88148', '88150', '88152', '88153', '88164', '88165', '88166', '88167', '88174', '88175')
UNION ALL
SELECT
    p.client_nbr,
    p.to_dos,
    'HCPCS' AS code_type,
    p.proc_cd AS code
FROM CHCDWORK.dbo.poem_cohort_cpt p
WHERE p.proc_cd IN ('0503F', '99501', 'G0101', 'G0123', 'G0124', 'G0141', 'G0143', 'G0144', 'G0145', 'G0147', 'G0148', 'P3000', 'P3001', 'Q0091')
UNION ALL
SELECT
    p.client_nbr,
    p.to_dos,
    'Bundled CPT' AS code_type,
    p.proc_cd AS code
FROM CHCDWORK.dbo.poem_cohort_cpt p
WHERE p.proc_cd IN ('59400', '59410', '59510', '59515', '59610', '59614', '59618', '59622')
UNION ALL
SELECT
    d.client_nbr,
    d.clm_from_date,
    'ICD' AS code_type,
    d.dx_cd AS code
FROM CHCDWORK.dbo.poem_cohort_dx d
WHERE d.dx_cd IN ('Z01411', 'Z01419', 'Z0142', 'Z30430', 'Z391', 'Z392');

/* 
 * Create the outcome table with breakdown by code type 
 * Just to see if there are bundled codes
 * Then you can take the max for each person+episode 
 * */

DROP TABLE IF EXISTS CHCDWORK.dbo.poem_outcomes_out_postpartum1;

SELECT
    c.client_nbr,
    c.ep_num,
    p.code_type,
    CASE WHEN COUNT(p.client_nbr) > 0 THEN 1 ELSE 0 END AS out_postpartum,
    COUNT(DISTINCT p.code) AS code_count
INTO CHCDWORK.dbo.poem_outcomes_out_postpartum1
FROM chcdwork.dbo.poem_cohort c
LEFT JOIN CHCDWORK.dbo.poem_outcomes_postpartum_temp p
    ON c.client_nbr = p.client_nbr
    AND p.to_dos BETWEEN DATEADD(day, 7, c.anchor_date) AND DATEADD(day, 84, c.anchor_date)
GROUP BY
    c.client_nbr,
    c.ep_num,
    p.code_type;
   
-- 6-month version
   
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_outcomes_out_postpartum6;
  
SELECT
    c.client_nbr,
    c.ep_num,
    p.code_type,
    CASE WHEN COUNT(p.client_nbr) > 0 THEN 1 ELSE 0 END AS out_postpartum_6,
    COUNT(DISTINCT p.code) AS code_count_6
INTO CHCDWORK.dbo.poem_outcomes_out_postpartum6
FROM chcdwork.dbo.poem_cohort c
LEFT JOIN CHCDWORK.dbo.poem_outcomes_postpartum_temp p
    ON c.client_nbr = p.client_nbr
    AND p.to_dos BETWEEN c.anchor_date AND DATEADD(day, 182, c.anchor_date)
GROUP BY
    c.client_nbr,
    c.ep_num,
    p.code_type;

-- 12-month version
   
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_outcomes_out_postpartum12;

SELECT
    c.client_nbr,
    c.ep_num,
    p.code_type,
    CASE WHEN COUNT(p.client_nbr) > 0 THEN 1 ELSE 0 END AS out_postpartum_12,
    COUNT(DISTINCT p.code) AS code_count_12
INTO CHCDWORK.dbo.poem_outcomes_out_postpartum12
FROM chcdwork.dbo.poem_cohort c
LEFT JOIN CHCDWORK.dbo.poem_outcomes_postpartum_temp p
    ON c.client_nbr = p.client_nbr
    AND p.to_dos BETWEEN c.anchor_date AND DATEADD(day, 365, c.anchor_date)
GROUP BY
    c.client_nbr,
    c.ep_num,
    p.code_type;   
   
   
  --- make final postpartum outcome table 
 DROP TABLE IF EXISTS CHCDWORK.dbo.poem_outcomes_out_postpartum;

select a.client_nbr, a.ep_num, 
       max(out_postpartum) as out_postpartum, 
       max(b.out_postpartum_6) as out_postpartum_6,
       max(c.out_postpartum_12) as out_postpartum_12
  into CHCDWORK.dbo.poem_outcomes_out_postpartum 
  from CHCDWORK.dbo.poem_outcomes_out_postpartum1 a
  left join CHCDWORK.dbo.poem_outcomes_out_postpartum6 b
   on a.client_nbr = b.client_nbr and a.ep_num = b.ep_num
  left join CHCDWORK.dbo.poem_outcomes_out_postpartum12 c
   on a.client_nbr = c.client_nbr and a.ep_num = c.ep_num
 group by a.client_nbr, a.ep_num;
   
select * from CHCDWORK.dbo.poem_outcomes_out_postpartum;  

-- Drop the temporary table
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_outcomes_postpartum_temp;
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_outcomes_out_postpartum12;
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_outcomes_out_postpartum6;
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_outcomes_out_postpartum1;
 
 
/* -------------------------------
 * Diabetes Test Screen
 * -------------------------------
 */

/* Create a lookup table for test types */
DROP TABLE IF EXISTS CHCDWORK.dbo.test_type_lookup;

CREATE TABLE CHCDWORK.dbo.test_type_lookup (
    code_type NVARCHAR(10),
    code NVARCHAR(10),
    test_type NVARCHAR(50)
);

INSERT INTO CHCDWORK.dbo.test_type_lookup (code_type, code, test_type)
VALUES
    ('CPT', '83036', 'HbA1c'),
    ('CPT', '83037', 'HbA1c'),
    ('CPT', '80047', 'GTT'),
    ('CPT', '80048', 'GTT'),
    ('CPT', '80050', 'GTT'),
    ('CPT', '80053', 'GTT'),
    ('CPT', '80069', 'GTT'),
    ('CPT', '82947', 'GTT'),
    ('CPT', '82950', 'GTT'),
    ('CPT', '82951', 'GTT');

/* Drop the temporary table if it exists */
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_diab_screen_temp;

/* Create the temporary table by joining with the lookup table */
SELECT DISTINCT
    p.client_nbr,
    p.to_dos,
    t.code_type,
    t.code,
    t.test_type
INTO CHCDWORK.dbo.poem_diab_screen_temp
FROM CHCDWORK.dbo.poem_cohort_cpt p
JOIN CHCDWORK.dbo.test_type_lookup t
    ON p.proc_cd = t.code;

/* 6-month version */
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_outcomes_out_diab_screen6;

SELECT
    c.client_nbr,
    c.ep_num,
    p.test_type,
    CASE WHEN COUNT(p.client_nbr) > 0 THEN 1 ELSE 0 END AS out_diab_screen_6,
    COUNT(DISTINCT p.code) AS code_count_6
INTO CHCDWORK.dbo.poem_outcomes_out_diab_screen6
FROM chcdwork.dbo.poem_cohort c
LEFT JOIN CHCDWORK.dbo.poem_diab_screen_temp p
    ON c.client_nbr = p.client_nbr
    AND p.to_dos BETWEEN c.anchor_date AND DATEADD(day, 182, c.anchor_date)
GROUP BY
    c.client_nbr,
    c.ep_num,
    p.test_type;

/* 12-month version */
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_outcomes_out_diab_screen12;

SELECT
    c.client_nbr,
    c.ep_num,
    p.test_type,
    CASE WHEN COUNT(p.client_nbr) > 0 THEN 1 ELSE 0 END AS out_diab_screen_12,
    COUNT(DISTINCT p.code) AS code_count_12
INTO CHCDWORK.dbo.poem_outcomes_out_diab_screen12
FROM chcdwork.dbo.poem_cohort c
LEFT JOIN CHCDWORK.dbo.poem_diab_screen_temp p
    ON c.client_nbr = p.client_nbr
    AND p.to_dos BETWEEN c.anchor_date AND DATEADD(day, 365, c.anchor_date)
GROUP BY
    c.client_nbr,
    c.ep_num,
    p.test_type;

--create table with both test types 
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_outcomes_out_diab_screen_detail;

WITH DistinctCombos AS (
    SELECT DISTINCT
        client_nbr,
        ep_num,
        test_type
    FROM (
        SELECT client_nbr, ep_num, test_type FROM CHCDWORK.dbo.poem_outcomes_out_diab_screen6
        UNION
        SELECT client_nbr, ep_num, test_type FROM CHCDWORK.dbo.poem_outcomes_out_diab_screen12
    ) AS Combined
)
SELECT
    d.client_nbr,
    d.ep_num,
    d.test_type,
    COALESCE(b.out_diab_screen_6, 0) AS out_diab_screen_6,
    COALESCE(c.out_diab_screen_12, 0) AS out_diab_screen_12
INTO CHCDWORK.dbo.poem_outcomes_out_diab_screen_detail
FROM DistinctCombos d
LEFT JOIN CHCDWORK.dbo.poem_outcomes_out_diab_screen6 b
    ON d.client_nbr = b.client_nbr 
    AND d.ep_num = b.ep_num 
    AND d.test_type = b.test_type
LEFT JOIN CHCDWORK.dbo.poem_outcomes_out_diab_screen12 c
    ON d.client_nbr = c.client_nbr 
    AND d.ep_num = c.ep_num 
    AND d.test_type = c.test_type;

   
--- simplified table 
   -- this is all that is needed for the actual outcomes
   -- the details are for the breakdown by test type 
   -- use this table for the main outcome 
drop table if exists CHCDWORK.dbo.poem_outcomes_out_diab_screen;

select client_nbr, ep_num,
       max(out_diab_screen_6) as out_diab_screen_6,
       max(out_diab_screen_12) as out_diab_screen_12
  into CHCDWORK.dbo.poem_outcomes_out_diab_screen
  from CHCDWORK.dbo.poem_outcomes_out_diab_screen_detail
  group by client_nbr, ep_num;

/* Cleanup */
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_outcomes_out_diab_screen12;
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_outcomes_out_diab_screen6; 
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_diab_screen_temp;



/* --------------
Hypertension 
-----------------
*/

-- Hypertension medications 

-- make list of ndc codes 
drop table if exists CHCDWORK.dbo.poem_htn_medications;

select distinct *
into CHCDWORK.dbo.poem_htn_medications
from [REF].dbo.NDC_TIER_MAP ntm 
where tier_1_category 
IN (
    'ACE inhibitors with calcium channel blocking agents',
    'ACE inhibitors with thiazides',
    'angiotensin converting enzyme (ACE) inhibitors',
    'angiotensin II inhibitors',
    'angiotensin II inhibitors with calcium channel blockers',
    'angiotensin II inhibitors with thiazides',
    'angiotensin receptor blockers and neprilysin inhibitors',
    'beta blockers with thiazides',
    'beta blockers, cardioselective',
    'beta blockers, non-cardioselective',
    'calcium channel blocking agents',
    'loop diuretics',
    'miscellaneous diuretics',
    'potassium sparing diuretics with thiazides',
    'potassium-sparing diuretics',
    'renin inhibitors',
    'vasodilators',
    'peripheral vasodilators'
) or drug_name = 'magnesium sulfate' ; 

--select * from CHCDWORK.dbo.poem_htn_medications where drug_name = 'magnesium sulfate';


/*SELECT *
--INTO CHCDWORK.dbo.poem_htn_med_temp
FROM CHCDWORK.dbo.poem_rx p
JOIN CHCDWORK.dbo.poem_htn_medications h
    ON p.ndc = h.ndc_code
  where drug_name = 'magnesium sulfate';*/

/* Drop the temporary table if it exists */
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_htn_med_temp;

/* Create the temporary table by joining with the lookup table */
SELECT DISTINCT
    p.client_nbr,
    p.fill_dt,
    case when drug_name = 'magnesium sulfate' then drug_name else h.tier_1_category end as htn_category
INTO CHCDWORK.dbo.poem_htn_med_temp
FROM CHCDWORK.dbo.poem_rx p
JOIN CHCDWORK.dbo.poem_htn_medications h
    ON p.ndc = h.ndc_code;
   

/* 6-month version */
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_outcomes_out_htn_med6;

SELECT
    c.client_nbr,
    c.ep_num,
    p.htn_category,
    CASE WHEN COUNT(p.client_nbr) > 0 THEN 1 ELSE 0 END AS out_htn_med_6,
    COUNT(DISTINCT p.fill_dt) AS fill_count_6
INTO CHCDWORK.dbo.poem_outcomes_out_htn_med6
FROM chcdwork.dbo.poem_cohort c
LEFT JOIN CHCDWORK.dbo.poem_htn_med_temp p
    ON c.client_nbr = p.client_nbr
    AND p.fill_dt BETWEEN c.anchor_date AND DATEADD(day, 182, c.anchor_date)
GROUP BY
    c.client_nbr,
    c.ep_num,
    p.htn_category;

/* 12-month version */
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_outcomes_out_htn_med12;

SELECT
    c.client_nbr,
    c.ep_num,
    p.htn_category,
    CASE WHEN COUNT(p.client_nbr) > 0 THEN 1 ELSE 0 END AS out_htn_med_12,
    COUNT(DISTINCT p.fill_dt) AS fill_count_12
INTO CHCDWORK.dbo.poem_outcomes_out_htn_med12
FROM chcdwork.dbo.poem_cohort c
LEFT JOIN CHCDWORK.dbo.poem_htn_med_temp p
    ON c.client_nbr = p.client_nbr
    AND p.fill_dt BETWEEN c.anchor_date AND DATEADD(day, 365, c.anchor_date)
GROUP BY
    c.client_nbr,
    c.ep_num,
    p.htn_category;

/* Create detail table */
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_outcomes_out_htn_med_detail;

WITH DistinctCombos AS (
    SELECT DISTINCT
        client_nbr,
        ep_num,
        htn_category
    FROM (
        SELECT client_nbr, ep_num, htn_category FROM CHCDWORK.dbo.poem_outcomes_out_htn_med6
        UNION
        SELECT client_nbr, ep_num, htn_category FROM CHCDWORK.dbo.poem_outcomes_out_htn_med12
    ) AS Combined
)
SELECT
    d.client_nbr,
    d.ep_num,
    d.htn_category,
    COALESCE(m6.out_htn_med_6, 0) AS out_htn_med_6,
    COALESCE(m6.fill_count_6, 0) AS fill_count_6,
    COALESCE(m12.out_htn_med_12, 0) AS out_htn_med_12,
    COALESCE(m12.fill_count_12, 0) AS fill_count_12
INTO CHCDWORK.dbo.poem_outcomes_out_htn_med_detail
FROM DistinctCombos d
LEFT JOIN CHCDWORK.dbo.poem_outcomes_out_htn_med6 m6
    ON d.client_nbr = m6.client_nbr 
    AND d.ep_num = m6.ep_num 
    AND d.htn_category = m6.htn_category
LEFT JOIN CHCDWORK.dbo.poem_outcomes_out_htn_med12 m12
    ON d.client_nbr = m12.client_nbr 
    AND d.ep_num = m12.ep_num 
    AND d.htn_category = m12.htn_category;
   

/* Create simplified outcomes table */
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_outcomes_out_htn_med;

SELECT 
    client_nbr,
    ep_num,
    MAX(out_htn_med_6) AS out_htn_med_6,
    MAX(out_htn_med_12) AS out_htn_med_12
INTO CHCDWORK.dbo.poem_outcomes_out_htn_med
FROM CHCDWORK.dbo.poem_outcomes_out_htn_med_detail
GROUP BY client_nbr, ep_num;


--- Create a simplified table with 0/1 outcomes for each test type (6-month version only)
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_outcomes_out_diab_screen_by_type_6_12mo;

-- Pivot the data to have HbA1c and GTT as separate columns for both 6- and 12-month outcomes
SELECT 
    client_nbr,
    ep_num,
    MAX(CASE WHEN test_type = 'HbA1c' THEN out_diab_screen_6 ELSE 0 END) AS out_diab_screen_hba1c_6,
    MAX(CASE WHEN test_type = 'GTT'  THEN out_diab_screen_6 ELSE 0 END) AS out_diab_screen_gtt_6,
    MAX(CASE WHEN test_type = 'HbA1c' THEN out_diab_screen_12 ELSE 0 END) AS out_diab_screen_hba1c_12,
    MAX(CASE WHEN test_type = 'GTT'  THEN out_diab_screen_12 ELSE 0 END) AS out_diab_screen_gtt_12
INTO CHCDWORK.dbo.poem_outcomes_out_diab_screen_by_type_6_12mo
FROM CHCDWORK.dbo.poem_outcomes_out_diab_screen_detail
GROUP BY 
    client_nbr,
    ep_num;

/* Cleanup */
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_outcomes_out_htn_med12;
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_outcomes_out_htn_med6;
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_htn_med_temp;


/*
 * Outpatient Visits
 * 
 * 
 * 
 */

-- get the base table of all outpatient claims before classifying them 

drop table if exists CHCDWORK.dbo.poem_outcomes_outpatient_all;

with get_all as (
select a.client_nbr, clm_id, to_dos
  from CHCDWORK.dbo.poem_cohort_cpt a 
  join CHCDWORK.dbo.poem_codes_any_out b 
    on a.proc_cd = b.code 
   and code_type in ('cpt','hcpcs')
 union all
 select a.client_nbr, clm_id, to_dos
  from CHCDWORK.dbo.poem_cohort_cpt a 
  join CHCDWORK.dbo.poem_codes_any_out b 
    on a.rev_cd = b.code 
   and code_type = 'revenue_code'
union all
 select a.client_nbr, clm_id, to_dos
  from CHCDWORK.dbo.poem_cohort_cpt a 
  where pos = '02'
union all 
 select a.client_nbr, clm_id, to_dos
  from CHCDWORK.dbo.poem_cohort_cpt a 
  where proc_mod_1 in ('GT','95')
     or proc_mod_2 in ('GT','95')
     or proc_mod_3 in ('GT','95')
     or proc_mod_4 in ('GT','95')
     or proc_mod_5 in ('GT','95') 
union all
 select a.client_nbr, clm_id, clm_from_date
  from CHCDWORK.dbo.poem_cohort_dx a 
  join CHCDWORK.dbo.poem_codes_any_out b 
    on a.dx_cd = b.code 
   and code_type = 'icd10'   
   )
   select client_nbr, clm_id, 
          min(to_dos) as date_
    into CHCDWORK.dbo.poem_outcomes_outpatient_all
    from get_all 
   group by client_nbr, clm_id;

-----------------------
---- get type 
-----------------------
  
-- evaluation
drop table if exists CHCDWORK.dbo.poem_outcomes_outpatient_pe;  
  
select distinct client_nbr, clm_id, 'postpartum_evaluation' as visit_type
  into CHCDWORK.dbo.poem_outcomes_outpatient_pe
  from CHCDWORK.dbo.poem_cohort_dx where substring(dx_cd,1,3) = 'Z39' ; 

-- preventive 
drop table if exists CHCDWORK.dbo.poem_outcomes_outpatient_prev;  

select distinct *, 'preventive' as visit_type
into CHCDWORK.dbo.poem_outcomes_outpatient_prev
from (
select client_nbr , clm_id  
from 
 CHCDWORK.dbo.poem_cohort_cpt where 
  (proc_cd between '99384' and '99387' or
   proc_cd between '99394' and '99397' or
   proc_cd in ('99381', '99382', '99383', '99391', '99392', '99393',
               '99401', '99402', '99403', '99404', '99411', '99412', '99429'))
union all
select distinct client_nbr, clm_id
  from CHCDWORK.dbo.poem_cohort_dx where dx_cd in ('Z0000', 'Z0001', 'Z00121', 'Z00129')
 ) a ; 

-- contraceptive management
drop table if exists CHCDWORK.dbo.poem_outcomes_outpatient_contr;

select distinct client_nbr, clm_id, 'contraceptive' as visit_type
  into CHCDWORK.dbo.poem_outcomes_outpatient_contr
  from CHCDWORK.dbo.poem_cohort_dx where substring(dx_cd,1,3) = 'Z30' ; 


-- mental

drop table if exists CHCDWORK.dbo.poem_outcomes_outpatient_mental;

select distinct 
    client_nbr,
    clm_id,
    'mental' as visit_type
into CHCDWORK.dbo.poem_outcomes_outpatient_mental
from (
    select client_nbr, clm_id
    from chcdwork.dbo.poem_cohort_cpt
    where proc_cd in (
        '90804', '90805', '90806', '90807', '90808', '90809', '90810', '90811', '90812', '90813',
        '90814', '90815', '90816', '90817', '90818', '90819', '90821', '90822', '90823', '90824',
        '90826', '90827', '90828', '90829', '90832', '90833', '90834', '90836', '90837', '90838',
        '90839', '90840', '90845', '90846', '90847', '90849', '90853', '90857', '90862', '90875',
        '90876', '90820', '90841', '90842', '90843', '90844', '90855'
    )
    union all
    select distinct c.client_nbr, c.clm_id
    from chcdwork.dbo.poem_cohort_cpt c
    join chcdwork.dbo.poem_cohort_dx d
      on c.client_nbr = d.client_nbr and c.clm_id = d.clm_id
    where c.proc_cd in (
        '99201', '99202', '99203', '99204', '99205',
        '99211', '99212', '99213', '99214', '99215'
    )
      and (
          left(replace(d.dx_cd, '.', ''), 3) in (
              'F01', 'F02', 'F03', 'F04', 'F05', 'F06', 'F07', 'F08', 'F09',
              'F10', 'F11', 'F12', 'F13', 'F14', 'F15', 'F16', 'F17', 'F18', 'F19',
              'F20', 'F21', 'F22', 'F23', 'F24', 'F25', 'F26', 'F27', 'F28', 'F29',
              'F30', 'F31', 'F32', 'F33', 'F34', 'F35', 'F36', 'F37', 'F38', 'F39',
              'F40', 'F41', 'F42', 'F43', 'F44', 'F45', 'F46', 'F47', 'F48',
              'F50', 'F51', 'F52', 'F53', 'F54', 'F55', 'F56', 'F57', 'F58', 'F59',
              'F60', 'F61', 'F62', 'F63', 'F64', 'F65', 'F66', 'F67', 'F68', 'F69',
              'F70', 'F71', 'F72', 'F73', 'F74', 'F75', 'F76', 'F77', 'F78', 'F79',
              'F80', 'F81', 'F82', 'F83', 'F84', 'F85', 'F86', 'F87', 'F88', 'F89',
              'F99'
          )
          or replace(d.dx_cd, '.', '') = 'O9934'
      )
) a;

--- combine and give categories 
drop table if exists CHCDWORK.dbo.poem_outcomes_outpatient_categories ; 

select a.*, 
       case when b.client_nbr is not null then 1 else 0 end as pe,
       case when c.client_nbr is not null then 1 else 0 end as prev,
       case when d.client_nbr is not null then 1 else 0 end as contr,
       case when e.client_nbr is not null then 1 else 0 end as mental,
       case when  b.client_nbr is null 
            and c.client_nbr is null 
            and d.client_nbr is null 
            and e.client_nbr is null then 1 else 0 end as other
   into CHCDWORK.dbo.poem_outcomes_outpatient_categories        
   from CHCDWORK.dbo.poem_outcomes_outpatient_all a 
   left join CHCDWORK.dbo.poem_outcomes_outpatient_pe b 
   on a.client_nbr = b.client_nbr 
   and a.clm_id = b.clm_id
   left join CHCDWORK.dbo.poem_outcomes_outpatient_prev c
   on a.client_nbr = c.client_nbr 
   and a.clm_id = c.clm_id
   left join CHCDWORK.dbo.poem_outcomes_outpatient_contr d
   on a.client_nbr = d.client_nbr 
   and a.clm_id = d.clm_id
  left join CHCDWORK.dbo.poem_outcomes_outpatient_mental e
   on a.client_nbr = e.client_nbr 
   and a.clm_id = e.clm_id
   ;
  
  
--- link to episodes and count
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_outcomes_outpatient_12;

SELECT
    c.client_nbr,
    c.ep_num,
    MAX(op.pe) AS out_pe_12,
    MAX(op.prev) AS out_prev_12, 
    MAX(op.contr) AS out_contr_12,
    MAX(op.mental) AS out_mental_12,
    MAX(op.other) AS out_other_12,
    CASE WHEN COUNT(op.client_nbr) > 0 THEN 1 ELSE 0 END AS out_any_outpatient_12,
    COUNT(DISTINCT CASE WHEN op.pe = 1 THEN op.date_ END) AS pe_visit_days_12,
    COUNT(DISTINCT CASE WHEN op.prev = 1 THEN op.date_ END) AS prev_visit_days_12,
    COUNT(DISTINCT CASE WHEN op.contr = 1 THEN op.date_ END) AS contr_visit_days_12,
    COUNT(DISTINCT CASE WHEN op.mental = 1 THEN op.date_ END) AS mental_visit_days_12,
    COUNT(DISTINCT CASE WHEN op.other = 1 THEN op.date_ END) AS other_visit_days_12,
    COUNT(DISTINCT op.date_) AS total_visit_days_12,  -- distinct visit days
    COUNT(op.client_nbr) AS total_claims_12           -- total claims/records
INTO CHCDWORK.dbo.poem_outcomes_outpatient_12
FROM chcdwork.dbo.poem_cohort c
LEFT JOIN CHCDWORK.dbo.poem_outcomes_outpatient_categories op
    ON c.client_nbr = op.client_nbr
    AND op.date_ BETWEEN DATEADD(day, 1, c.anchor_date) AND DATEADD(day, 365, c.anchor_date)
GROUP BY
    c.client_nbr,
    c.ep_num;
   
--- provide summary of combos
 drop table if exists CHCDWORK.dbo.poem_outcomes_outpatient_categories_summary;  
  
   WITH categorized_visits AS (
    SELECT a.*,
        CASE
            WHEN pe = 1 AND prev = 0 AND contr = 0 AND mental = 0 THEN 'Postpartum evaluation only'
            WHEN pe = 0 AND prev = 1 AND contr = 0 AND mental = 0 THEN 'Preventive/well care only'
            WHEN pe = 0 AND prev = 0 AND contr = 1 AND mental = 0 THEN 'Contraceptive management only'
            WHEN pe = 0 AND prev = 0 AND contr = 0 AND mental = 1 THEN 'Mental/behavioral health care only'
            WHEN pe = 1 AND contr = 1 AND prev = 0 AND mental = 0 THEN 'Postpartum & Contraceptive'
            WHEN pe = 0 AND contr = 1 AND prev = 1 AND mental = 0 THEN 'Preventive/well & Contraceptive'
            WHEN pe = 1 AND contr = 0 AND prev = 1 AND mental = 0 THEN 'Postpartum & Preventive/well'
            WHEN pe = 0 AND contr = 1 AND prev = 0 AND mental = 1 THEN 'Contraceptive & Mental/behavioral health care'
            WHEN pe = 1 AND contr = 0 AND prev = 0 AND mental = 1 THEN 'Postpartum & mental/behavioral health care'
            WHEN pe = 0 AND contr = 0 AND prev = 1 AND mental = 1 THEN 'Preventive/well & mental/behavioral health'
            WHEN pe = 0 AND contr = 0 AND prev = 0 AND mental = 0 THEN 'Other acute or chronic illness only'
            ELSE 'Other combination'
        END AS care_type
    FROM CHCDWORK.dbo.poem_outcomes_outpatient_categories a 
    join chcdwork.dbo.poem_cohort c
    ON c.client_nbr = a.client_nbr
    AND a.date_ BETWEEN DATEADD(day, 1, c.anchor_date) AND DATEADD(day, 365, c.anchor_date)
),
counts AS (
    SELECT
        care_type,
        COUNT(*) AS n
    FROM categorized_visits
    GROUP BY care_type
),
totals AS (
    SELECT SUM(n) AS total FROM counts
)
SELECT 
    care_type AS type_care,
    CAST(100.0 * n / total AS DECIMAL(5,1)) AS share_of_visits
into CHCDWORK.dbo.poem_outcomes_outpatient_categories_summary
FROM counts, totals
;
   
   
----
   select count(distinct client_nbr) from CHCDWORK.dbo.poem_outcomes_outpatient_12
   union all
  select count(distinct client_nbr) from CHCDWORK.dbo.poem_cohort;
 
  select count(distinct client_nbr) from CHCDWORK.dbo.poem_outcomes_outpatient_categories;
