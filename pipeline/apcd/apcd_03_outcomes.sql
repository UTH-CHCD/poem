/* ------------------------------------------------------
 * Enrollment
 * 
 * Check to see if that person is enrolled 90 days later 
 * 90 Days begins the day AFTER the anchor day
 */ -----------------------------------------------------
DROP TABLE IF EXISTS research_dev.poem_outcomes_enrollment;

CREATE TABLE research_dev.poem_outcomes_enrollment AS
SELECT DISTINCT 
    c.pers_id,
    c.ep_num,
    CASE WHEN d90.pers_id IS NOT NULL THEN 1 ELSE 0 END AS out_enroll_90,
    CASE WHEN d12.pers_id IS NOT NULL THEN 1 ELSE 0 END AS out_enroll_12
FROM research_dev.poem_cohort c
LEFT JOIN research_di.agg_yrmon_plan AS d90
    ON d90.pers_id = c.pers_id
    and d90.prim_med_plan = 'Medicaid'
   AND d90.yrmon = CAST(
                     TO_CHAR(c.anchor_date + INTERVAL '91 days', 'YYYYMM') 
                     AS INTEGER
                   )
LEFT JOIN research_di.agg_yrmon_plan AS d12
    ON d12.pers_id = c.pers_id
    and d12.prim_med_plan = 'Medicaid'
   AND d12.yrmon = CAST(
                     TO_CHAR(c.anchor_date + INTERVAL '1 year', 'YYYYMM') 
                     AS INTEGER
                   );    
                   
                  
 select * from research_dev.poem_outcomes_enrollment;
 


--- CE After          

DROP TABLE IF EXISTS research_dev.poem_outcomes_ce_after;

CREATE TABLE research_dev.poem_outcomes_ce_after AS
WITH enrollment_months AS (
    SELECT DISTINCT
        c.pers_id,
        c.ep_num,
        c.anchor_date,
        (EXTRACT(YEAR FROM TO_DATE(d.yrmon::text, 'YYYYMM')) * 12 + 
         EXTRACT(MONTH FROM TO_DATE(d.yrmon::text, 'YYYYMM'))) -
        (EXTRACT(YEAR FROM c.anchor_date) * 12 + 
         EXTRACT(MONTH FROM c.anchor_date)) AS months_from_anchor
    FROM research_dev.poem_cohort c
    INNER JOIN research_di.agg_yrmon_plan d
        ON d.pers_id = c.pers_id
        and d.prim_med_plan = 'Medicaid'
       AND d.yrmon >= CAST(TO_CHAR(DATE_TRUNC('month', c.anchor_date), 'YYYYMM') AS INTEGER)
),
with_next AS (
    SELECT 
        pers_id,
        ep_num, 
        anchor_date,
        months_from_anchor,
        LEAD(months_from_anchor) OVER (PARTITION BY pers_id, ep_num ORDER BY months_from_anchor) AS next_month
    FROM enrollment_months
),
gap_detection AS (
    SELECT 
        pers_id,
        ep_num,
        anchor_date,
        months_from_anchor,
        next_month,
        CASE WHEN next_month - months_from_anchor > 1 THEN 1 ELSE 0 END AS has_gap_after
    FROM with_next
)
SELECT 
    pers_id,
    ep_num,
    anchor_date,
    CASE 
        WHEN MIN(months_from_anchor) > 0 THEN 0  -- Didn't start at anchor month
        ELSE COALESCE(MIN(CASE WHEN has_gap_after = 1 THEN months_from_anchor + 1 END), 
                      MAX(months_from_anchor) + 1)  -- No gaps found, all continuous
    END AS ce_after
FROM gap_detection
GROUP BY pers_id, ep_num, anchor_date;


-- CE Before
DROP TABLE IF EXISTS research_dev.poem_outcomes_ce_before; 

CREATE TABLE research_dev.poem_outcomes_ce_before AS
WITH enrollment_months AS (
    SELECT DISTINCT
        c.pers_id,
        c.ep_num,
        c.anchor_date,
        (EXTRACT(YEAR FROM c.anchor_date) * 12 + 
         EXTRACT(MONTH FROM c.anchor_date)) -
        (EXTRACT(YEAR FROM TO_DATE(d.yrmon::text, 'YYYYMM')) * 12 + 
         EXTRACT(MONTH FROM TO_DATE(d.yrmon::text, 'YYYYMM'))) AS months_before_anchor
    FROM research_dev.poem_cohort c
    INNER JOIN research_di.agg_yrmon_plan d
        ON d.pers_id = c.pers_id
       AND d.yrmon < CAST(TO_CHAR(DATE_TRUNC('month', c.anchor_date), 'YYYYMM') AS INTEGER)
),
with_next AS (
    SELECT 
        pers_id,
        ep_num, 
        anchor_date,
        months_before_anchor,
        LEAD(months_before_anchor) OVER (PARTITION BY pers_id, ep_num ORDER BY months_before_anchor DESC) AS next_month
    FROM enrollment_months
),
gap_detection AS (
    SELECT 
        pers_id,
        ep_num,
        anchor_date,
        months_before_anchor,
        next_month,
        CASE WHEN months_before_anchor - next_month > 1 THEN 1 ELSE 0 END AS has_gap_after
    FROM with_next
)
SELECT 
    pers_id,
    ep_num,
    anchor_date,
    CASE 
        WHEN MIN(months_before_anchor) > 1 THEN 0  -- Didn't have enrollment in month before anchor
        ELSE COALESCE(MIN(CASE WHEN has_gap_after = 1 THEN months_before_anchor - 1 END), 
                      MAX(months_before_anchor))  -- No gaps found, all continuous
    END AS ce_before
FROM gap_detection
GROUP BY pers_id, ep_num, anchor_date;


-- Total months before anchor
DROP TABLE IF EXISTS research_dev.poem_outcomes_total_before;

CREATE TABLE research_dev.poem_outcomes_total_before AS
SELECT 
    c.pers_id,
    c.ep_num,
    c.anchor_date,
    COUNT(DISTINCT d.yrmon) AS total_months_before
FROM research_dev.poem_cohort c
LEFT JOIN research_di.agg_yrmon_plan d
    ON d.pers_id = c.pers_id
    and d.prim_med_plan = 'Medicaid'
   AND d.yrmon < CAST(TO_CHAR(DATE_TRUNC('month', c.anchor_date), 'YYYYMM') AS INTEGER)
GROUP BY c.pers_id, c.ep_num, c.anchor_date;

-- Total months after anchor (including anchor month)
DROP TABLE IF EXISTS research_dev.poem_outcomes_total_after;

CREATE TABLE research_dev.poem_outcomes_total_after AS
SELECT 
    c.pers_id,
    c.ep_num,
    c.anchor_date,
    COUNT(DISTINCT d.yrmon) AS total_months_after
FROM research_dev.poem_cohort c
LEFT JOIN research_di.agg_yrmon_plan d
    ON d.pers_id = c.pers_id
    and d.prim_med_plan = 'Medicaid'
   AND d.yrmon >= CAST(TO_CHAR(DATE_TRUNC('month', c.anchor_date), 'YYYYMM') AS INTEGER)
GROUP BY c.pers_id, c.ep_num, c.anchor_date;

-- Combine all enrollment metrics
DROP TABLE IF EXISTS research_dev.poem_outcomes_enroll;

CREATE TABLE research_dev.poem_outcomes_enroll AS
SELECT 
    c.pers_id,
    c.ep_num,
    COALESCE(e.out_enroll_90, 0) AS out_enroll_90,
    COALESCE(e.out_enroll_12, 0) AS out_enroll_12,
    COALESCE(ca.ce_after, 0) AS ce_after,
    COALESCE(cb.ce_before, 0) AS ce_before,
    COALESCE(ta.total_months_after, 0) AS total_months_after,
    COALESCE(tb.total_months_before, 0) AS total_months_before
FROM research_dev.poem_cohort c
LEFT JOIN research_dev.poem_outcomes_enrollment e
    ON e.pers_id = c.pers_id AND e.ep_num = c.ep_num
LEFT JOIN research_dev.poem_outcomes_ce_after ca
    ON ca.pers_id = c.pers_id AND ca.ep_num = c.ep_num
LEFT JOIN research_dev.poem_outcomes_ce_before cb
    ON cb.pers_id = c.pers_id AND cb.ep_num = c.ep_num
LEFT JOIN research_dev.poem_outcomes_total_after ta
    ON ta.pers_id = c.pers_id AND ta.ep_num = c.ep_num
LEFT JOIN research_dev.poem_outcomes_total_before tb
    ON tb.pers_id = c.pers_id AND tb.ep_num = c.ep_num;
    
   
select * from research_dev.poem_outcomes_enroll;


/* ----------------------------------
 * Medicaid Eligibility Details
 * (modal values at anchor month)
 * ----------------------------------*/

DROP TABLE IF EXISTS research_dev.poem_outcomes_mcd_elig;

CREATE TABLE research_dev.poem_outcomes_mcd_elig AS
SELECT 
    c.pers_id,
    c.ep_num,
    MODE() WITHIN GROUP (ORDER BY m.data_submitter_code) AS data_submitter_code,
    MODE() WITHIN GROUP (ORDER BY m.mc_flag)             AS mc_flag,
    MODE() WITHIN GROUP (ORDER BY m.mc_sc)               AS mc_sc,
    MODE() WITHIN GROUP (ORDER BY m.me_at)               AS me_at,
    MODE() WITHIN GROUP (ORDER BY m.me_code)             AS me_code,
    MODE() WITHIN GROUP (ORDER BY m.me_tp)               AS me_tp,
    MODE() WITHIN GROUP (ORDER BY m.me_sd)               AS me_sd,
    MODE() WITHIN GROUP (ORDER BY m.riskgrp_id)          AS riskgrp_id
FROM research_dev.poem_cohort c
JOIN research_di.mcd_elig_supp m
    ON m.pers_id = c.pers_id
    AND m.yrmon = CAST(TO_CHAR(c.anchor_date, 'YYYYMM') AS BIGINT)
GROUP BY c.pers_id, c.ep_num;


/* ----------------------------------
 * Preventitive/E&M Visits 
 * -----------------------------------*/

DROP TABLE IF EXISTS research_dev.poem_outcomes_prev_em;

-- Create the new outcome table
CREATE TABLE research_dev.poem_outcomes_prev_em AS
SELECT
    c.pers_id,
    c.ep_num,
    c.anchor_date,
    CASE WHEN COUNT(p.proc_cd) > 0 THEN 1 ELSE 0 END AS out_prev_em
FROM
    research_dev.poem_cohort c
LEFT JOIN
    research_dev.medical_adj_poem p
    ON c.pers_id = p.pers_id
    AND (
        (p.proc_cd BETWEEN '99202' AND '99215') OR
        (p.proc_cd BETWEEN '99381' AND '99429') OR
        p.proc_cd IN ('99441', '99442', '99443')
    )
    AND p.dos_thru BETWEEN c.anchor_date + 7 AND c.anchor_date + 84
GROUP BY
    c.pers_id,
    c.ep_num,
    c.anchor_date;

SELECT * FROM research_dev.poem_outcomes_prev_em;


/* --------------------------------------
 * Postpartum Visits
 * --------------------------------------
 */

/* Drop the temporary table if it exists */
DROP TABLE IF EXISTS research_dev.poem_outcomes_postpartum_temp;

/* Create the temporary table with code type and code */
CREATE TABLE research_dev.poem_outcomes_postpartum_temp AS
SELECT DISTINCT
    p.pers_id,
    p.dos_thru,
    'CPT' AS code_type,
    p.proc_cd AS code
FROM research_dev.medical_adj_poem p
WHERE p.proc_cd IN ('59430', '57170', '58300', '88141', '88142', '88143', '88147', '88148', '88150', '88152', '88153', '88164', '88165', '88166', '88167', '88174', '88175')
UNION ALL
SELECT
    p.pers_id,
    p.dos_thru,
    'HCPCS' AS code_type,
    p.proc_cd AS code
FROM research_dev.medical_adj_poem p
WHERE p.proc_cd IN ('0503F', '99501', 'G0101', 'G0123', 'G0124', 'G0141', 'G0143', 'G0144', 'G0145', 'G0147', 'G0148', 'P3000', 'P3001', 'Q0091')
UNION ALL
SELECT
    p.pers_id,
    p.dos_thru,
    'Bundled CPT' AS code_type,
    p.proc_cd AS code
FROM research_dev.medical_adj_poem p
WHERE p.proc_cd IN ('59400', '59410', '59510', '59515', '59610', '59614', '59618', '59622')
UNION ALL
SELECT
    d.pers_id,
    d.dos,
    'ICD' AS code_type,
    d.dx AS code
FROM research_dev.med_dx_poem d
WHERE d.dx IN ('Z01411', 'Z01419', 'Z0142', 'Z30430', 'Z391', 'Z392');


/* 
 * Create the outcome table with breakdown by code type 
 * Just to see if there are bundled codes
 * Then you can take the max for each person+episode 
 * */

DROP TABLE IF EXISTS research_dev.poem_outcomes_out_postpartum1;

CREATE TABLE research_dev.poem_outcomes_out_postpartum1 AS
SELECT
    c.pers_id,
    c.ep_num,
    p.code_type,
    CASE WHEN COUNT(p.pers_id) > 0 THEN 1 ELSE 0 END AS out_postpartum,
    COUNT(DISTINCT p.code) AS code_count
FROM research_dev.poem_cohort c
LEFT JOIN research_dev.poem_outcomes_postpartum_temp p
    ON c.pers_id = p.pers_id
    AND p.dos_thru BETWEEN c.anchor_date + 7 AND c.anchor_date + 84
GROUP BY
    c.pers_id,
    c.ep_num,
    p.code_type;
   
-- 6-month version
   
DROP TABLE IF EXISTS research_dev.poem_outcomes_out_postpartum6;
  
CREATE TABLE research_dev.poem_outcomes_out_postpartum6 AS
SELECT
    c.pers_id,
    c.ep_num,
    p.code_type,
    CASE WHEN COUNT(p.pers_id) > 0 THEN 1 ELSE 0 END AS out_postpartum_6,
    COUNT(DISTINCT p.code) AS code_count_6
FROM research_dev.poem_cohort c
LEFT JOIN research_dev.poem_outcomes_postpartum_temp p
    ON c.pers_id = p.pers_id
    AND p.dos_thru BETWEEN c.anchor_date AND c.anchor_date + 182
GROUP BY
    c.pers_id,
    c.ep_num,
    p.code_type;

-- 12-month version
   
DROP TABLE IF EXISTS research_dev.poem_outcomes_out_postpartum12;

CREATE TABLE research_dev.poem_outcomes_out_postpartum12 AS
SELECT
    c.pers_id,
    c.ep_num,
    p.code_type,
    CASE WHEN COUNT(p.pers_id) > 0 THEN 1 ELSE 0 END AS out_postpartum_12,
    COUNT(DISTINCT p.code) AS code_count_12
FROM research_dev.poem_cohort c
LEFT JOIN research_dev.poem_outcomes_postpartum_temp p
    ON c.pers_id = p.pers_id
    AND p.dos_thru BETWEEN c.anchor_date AND c.anchor_date + 365
GROUP BY
    c.pers_id,
    c.ep_num,
    p.code_type;   
   
   

--- make final postpartum outcome table 
DROP TABLE IF EXISTS research_dev.poem_outcomes_out_postpartum;

CREATE TABLE research_dev.poem_outcomes_out_postpartum AS
SELECT a.pers_id, 
       a.ep_num, 
       MAX(out_postpartum) AS out_postpartum, 
       MAX(b.out_postpartum_6) AS out_postpartum_6,
       MAX(c.out_postpartum_12) AS out_postpartum_12
FROM research_dev.poem_outcomes_out_postpartum1 a
LEFT JOIN research_dev.poem_outcomes_out_postpartum6 b
    ON a.pers_id = b.pers_id AND a.ep_num = b.ep_num
LEFT JOIN research_dev.poem_outcomes_out_postpartum12 c
    ON a.pers_id = c.pers_id AND a.ep_num = c.ep_num
GROUP BY a.pers_id, a.ep_num;
   
SELECT * FROM research_dev.poem_outcomes_out_postpartum;  

-- Drop the temporary tables
DROP TABLE IF EXISTS research_dev.poem_outcomes_postpartum_temp;
DROP TABLE IF EXISTS research_dev.poem_outcomes_out_postpartum12;
DROP TABLE IF EXISTS research_dev.poem_outcomes_out_postpartum6;
DROP TABLE IF EXISTS research_dev.poem_outcomes_out_postpartum1;

/* -------------------------------
 * Diabetes Test Screen
 * -------------------------------
 */


/* Drop the temporary table if it exists */
DROP TABLE IF EXISTS research_dev.poem_diab_screen_temp;

/* Create the temporary table by joining with the lookup table */
CREATE TABLE research_dev.poem_diab_screen_temp AS
SELECT DISTINCT
    p.pers_id,
    p.dos_thru,
    t.code_type,
    t.code,
    t.test_type
FROM research_dev.medical_adj_poem p
JOIN research_dev.test_type_lookup t
    ON p.proc_cd = t.code
   where p.pers_id in (select pers_id from research_dev.poem_cohort);

/* 6-month version */
DROP TABLE IF EXISTS research_dev.poem_outcomes_out_diab_screen6;

CREATE TABLE research_dev.poem_outcomes_out_diab_screen6 AS
SELECT
    c.pers_id,
    c.ep_num,
    p.test_type,
    CASE WHEN COUNT(p.pers_id) > 0 THEN 1 ELSE 0 END AS out_diab_screen_6,
    COUNT(DISTINCT p.code) AS code_count_6
FROM research_dev.poem_cohort c
LEFT JOIN research_dev.poem_diab_screen_temp p
    ON c.pers_id = p.pers_id
    AND p.dos_thru BETWEEN c.anchor_date AND c.anchor_date + 182
GROUP BY
    c.pers_id,
    c.ep_num,
    p.test_type;

/* 12-month version */
DROP TABLE IF EXISTS research_dev.poem_outcomes_out_diab_screen12;

CREATE TABLE research_dev.poem_outcomes_out_diab_screen12 AS
SELECT
    c.pers_id,
    c.ep_num,
    p.test_type,
    CASE WHEN COUNT(p.pers_id) > 0 THEN 1 ELSE 0 END AS out_diab_screen_12,
    COUNT(DISTINCT p.code) AS code_count_12
FROM research_dev.poem_cohort c
LEFT JOIN research_dev.poem_diab_screen_temp p
    ON c.pers_id = p.pers_id
    AND p.dos_thru BETWEEN c.anchor_date AND c.anchor_date + 365
GROUP BY
    c.pers_id,
    c.ep_num,
    p.test_type;

-- create table with both test types 
DROP TABLE IF EXISTS research_dev.poem_outcomes_out_diab_screen_detail;

CREATE TABLE research_dev.poem_outcomes_out_diab_screen_detail AS
WITH DistinctCombos AS (
    SELECT DISTINCT
        pers_id,
        ep_num,
        test_type
    FROM (
        SELECT pers_id, ep_num, test_type FROM research_dev.poem_outcomes_out_diab_screen6
        UNION
        SELECT pers_id, ep_num, test_type FROM research_dev.poem_outcomes_out_diab_screen12
    ) AS Combined
)
SELECT
    d.pers_id,
    d.ep_num,
    d.test_type,
    COALESCE(b.out_diab_screen_6, 0) AS out_diab_screen_6,
    COALESCE(c.out_diab_screen_12, 0) AS out_diab_screen_12
FROM DistinctCombos d
LEFT JOIN research_dev.poem_outcomes_out_diab_screen6 b
    ON d.pers_id = b.pers_id 
    AND d.ep_num = b.ep_num 
    AND d.test_type = b.test_type
LEFT JOIN research_dev.poem_outcomes_out_diab_screen12 c
    ON d.pers_id = c.pers_id 
    AND d.ep_num = c.ep_num 
    AND d.test_type = c.test_type;
   
--- simplified table 
-- this is all that is needed for the actual outcomes
-- the details are for the breakdown by test type 
-- use this table for the main outcome 
DROP TABLE IF EXISTS research_dev.poem_outcomes_out_diab_screen;

CREATE TABLE research_dev.poem_outcomes_out_diab_screen AS
SELECT pers_id, 
       ep_num,
       MAX(out_diab_screen_6) AS out_diab_screen_6,
       MAX(out_diab_screen_12) AS out_diab_screen_12
FROM research_dev.poem_outcomes_out_diab_screen_detail
GROUP BY pers_id, ep_num;

/* Cleanup */
DROP TABLE IF EXISTS research_dev.poem_outcomes_out_diab_screen12;
DROP TABLE IF EXISTS research_dev.poem_outcomes_out_diab_screen6; 
DROP TABLE IF EXISTS research_dev.poem_diab_screen_temp;


/* --------------
Hypertension 
-----------------
*/

-- Hypertension medications 

-- make list of ndc codes 
DROP TABLE IF EXISTS research_dev.poem_htn_medications;

CREATE TABLE research_dev.poem_htn_medications AS
SELECT DISTINCT *
FROM research_dev.ndc_tier_map ntm 
WHERE tier_1_category 
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
) OR drug_name = 'magnesium sulfate';

/* Drop the temporary table if it exists */
DROP TABLE IF EXISTS research_dev.poem_htn_med_temp;

/* Create the temporary table by joining with the lookup table */
CREATE TABLE research_dev.poem_htn_med_temp AS
SELECT DISTINCT
    p.pers_id,
    p.fill_dt,
    CASE WHEN drug_name = 'magnesium sulfate' THEN drug_name ELSE h.tier_1_category END AS htn_category
FROM research_dev.pharmacy_adj_poem p
JOIN research_dev.poem_htn_medications h
    ON p.ndc = h.ndc_code;

/* 6-month version */
DROP TABLE IF EXISTS research_dev.poem_outcomes_out_htn_med6;

CREATE TABLE research_dev.poem_outcomes_out_htn_med6 AS
SELECT
    c.pers_id,
    c.ep_num,
    p.htn_category,
    CASE WHEN COUNT(p.pers_id) > 0 THEN 1 ELSE 0 END AS out_htn_med_6,
    COUNT(DISTINCT p.fill_dt) AS fill_count_6
FROM research_dev.poem_cohort c
LEFT JOIN research_dev.poem_htn_med_temp p
    ON c.pers_id = p.pers_id
    AND p.fill_dt BETWEEN c.anchor_date AND c.anchor_date + 182
GROUP BY
    c.pers_id,
    c.ep_num,
    p.htn_category;

/* 12-month version */
DROP TABLE IF EXISTS research_dev.poem_outcomes_out_htn_med12;

CREATE TABLE research_dev.poem_outcomes_out_htn_med12 AS
SELECT
    c.pers_id,
    c.ep_num,
    p.htn_category,
    CASE WHEN COUNT(p.pers_id) > 0 THEN 1 ELSE 0 END AS out_htn_med_12,
    COUNT(DISTINCT p.fill_dt) AS fill_count_12
FROM research_dev.poem_cohort c
LEFT JOIN research_dev.poem_htn_med_temp p
    ON c.pers_id = p.pers_id
    AND p.fill_dt BETWEEN c.anchor_date AND c.anchor_date + 365
GROUP BY
    c.pers_id,
    c.ep_num,
    p.htn_category;

/* Create detail table */
DROP TABLE IF EXISTS research_dev.poem_outcomes_out_htn_med_detail;

CREATE TABLE research_dev.poem_outcomes_out_htn_med_detail AS
WITH DistinctCombos AS (
    SELECT DISTINCT
        pers_id,
        ep_num,
        htn_category
    FROM (
        SELECT pers_id, ep_num, htn_category FROM research_dev.poem_outcomes_out_htn_med6
        UNION
        SELECT pers_id, ep_num, htn_category FROM research_dev.poem_outcomes_out_htn_med12
    ) AS Combined
)
SELECT
    d.pers_id,
    d.ep_num,
    d.htn_category,
    COALESCE(m6.out_htn_med_6, 0) AS out_htn_med_6,
    COALESCE(m6.fill_count_6, 0) AS fill_count_6,
    COALESCE(m12.out_htn_med_12, 0) AS out_htn_med_12,
    COALESCE(m12.fill_count_12, 0) AS fill_count_12
FROM DistinctCombos d
LEFT JOIN research_dev.poem_outcomes_out_htn_med6 m6
    ON d.pers_id = m6.pers_id 
    AND d.ep_num = m6.ep_num 
    AND d.htn_category = m6.htn_category
LEFT JOIN research_dev.poem_outcomes_out_htn_med12 m12
    ON d.pers_id = m12.pers_id 
    AND d.ep_num = m12.ep_num 
    AND d.htn_category = m12.htn_category;

/* Create simplified outcomes table */
DROP TABLE IF EXISTS research_dev.poem_outcomes_out_htn_med;

CREATE TABLE research_dev.poem_outcomes_out_htn_med AS
SELECT 
    pers_id,
    ep_num,
    MAX(out_htn_med_6) AS out_htn_med_6,
    MAX(out_htn_med_12) AS out_htn_med_12
FROM research_dev.poem_outcomes_out_htn_med_detail
GROUP BY pers_id, ep_num;

--- Create a simplified table with 0/1 outcomes for each test type (6-month version only)
DROP TABLE IF EXISTS research_dev.poem_outcomes_out_diab_screen_by_type_6_12mo;

-- Pivot the data to have HbA1c and GTT as separate columns for both 6- and 12-month outcomes
CREATE TABLE research_dev.poem_outcomes_out_diab_screen_by_type_6_12mo AS
SELECT 
    pers_id,
    ep_num,
    MAX(CASE WHEN test_type = 'HbA1c' THEN out_diab_screen_6 ELSE 0 END) AS out_diab_screen_hba1c_6,
    MAX(CASE WHEN test_type = 'GTT' THEN out_diab_screen_6 ELSE 0 END) AS out_diab_screen_gtt_6,
    MAX(CASE WHEN test_type = 'HbA1c' THEN out_diab_screen_12 ELSE 0 END) AS out_diab_screen_hba1c_12,
    MAX(CASE WHEN test_type = 'GTT' THEN out_diab_screen_12 ELSE 0 END) AS out_diab_screen_gtt_12
FROM research_dev.poem_outcomes_out_diab_screen_detail
GROUP BY 
    pers_id,
    ep_num;

/* Cleanup */
DROP TABLE IF EXISTS research_dev.poem_outcomes_out_htn_med12;
DROP TABLE IF EXISTS research_dev.poem_outcomes_out_htn_med6;
DROP TABLE IF EXISTS research_dev.poem_htn_med_temp;


/*
 * Outpatient Visits
 */

-- get the base table of all outpatient claims before classifying them 

DROP TABLE IF EXISTS research_dev.poem_outcomes_outpatient_all;

CREATE TABLE research_dev.poem_outcomes_outpatient_all AS
WITH get_all AS (
    SELECT a.pers_id, a.clm_id AS clm_id, dos_thru AS to_dos
    FROM research_dev.medical_adj_poem a 
    JOIN research_dev.poem_codes_any_out b 
        ON a.proc_cd = b.code 
        AND code_type IN ('cpt','hcpcs')
    UNION ALL
    SELECT a.pers_id, a.clm_id AS clm_id, dos_thru AS to_dos
    FROM research_dev.medical_adj_poem a 
    JOIN research_dev.poem_codes_any_out b 
        ON a.rev = b.code 
        AND code_type = 'revenue_code'
    UNION ALL
    SELECT a.pers_id, a.clm_id AS clm_id, dos_thru AS to_dos
    FROM research_dev.medical_adj_poem a 
    WHERE pos = '02'
    UNION ALL 
    SELECT a.pers_id, a.clm_id AS clm_id, dos_thru AS to_dos
    FROM research_dev.medical_adj_poem a 
    WHERE proc_mod1 IN ('GT','95')
        OR proc_mod2 IN ('GT','95')
        OR proc_mod3 IN ('GT','95')
        OR proc_mod4 IN ('GT','95')
    UNION ALL
    SELECT a.pers_id, a.clm_id AS clm_id, dos AS to_dos
    FROM research_dev.med_dx_poem a 
    JOIN research_dev.poem_codes_any_out b 
        ON a.dx = b.code 
        AND code_type = 'icd10'   
)
SELECT pers_id, 
       clm_id, 
       MIN(to_dos) AS date_
FROM get_all 
where pers_id in (select pers_id from research_dev.poem_cohort )
GROUP BY pers_id, clm_id;

-----------------------
---- get type 
-----------------------
  
-- evaluation
DROP TABLE IF EXISTS research_dev.poem_outcomes_outpatient_pe;  
  
CREATE TABLE research_dev.poem_outcomes_outpatient_pe AS
SELECT DISTINCT pers_id, clm_id AS clm_id, 'postpartum_evaluation' AS visit_type
FROM research_dev.med_dx_poem 
WHERE SUBSTRING(dx, 1, 3) = 'Z39';

-- preventive 
DROP TABLE IF EXISTS research_dev.poem_outcomes_outpatient_prev;  

CREATE TABLE research_dev.poem_outcomes_outpatient_prev AS
SELECT DISTINCT *, 'preventive' AS visit_type
FROM (
    SELECT pers_id, clm_id AS clm_id  
    FROM research_dev.medical_adj_poem 
    WHERE (proc_cd BETWEEN '99384' AND '99387' OR
           proc_cd BETWEEN '99394' AND '99397' OR
           proc_cd IN ('99381', '99382', '99383', '99391', '99392', '99393',
                       '99401', '99402', '99403', '99404', '99411', '99412', '99429'))
    UNION ALL
    SELECT DISTINCT pers_id, clm_id AS clm_id
    FROM research_dev.med_dx_poem 
    WHERE dx IN ('Z0000', 'Z0001', 'Z00121', 'Z00129')
    and pers_id in (select pers_id from research_dev.poem_cohort )
) a;

-- contraceptive management
DROP TABLE IF EXISTS research_dev.poem_outcomes_outpatient_contr;

CREATE TABLE research_dev.poem_outcomes_outpatient_contr AS
SELECT DISTINCT pers_id, clm_id AS clm_id, 'contraceptive' AS visit_type
FROM research_dev.med_dx_poem 
WHERE SUBSTRING(dx, 1, 3) = 'Z30'
and pers_id in (select pers_id from research_dev.poem_cohort );

-- mental
DROP TABLE IF EXISTS research_dev.poem_outcomes_outpatient_mental;

CREATE TABLE research_dev.poem_outcomes_outpatient_mental AS
SELECT DISTINCT 
    pers_id,
    clm_id,
    'mental' AS visit_type
FROM (
    SELECT pers_id, clm_id AS clm_id
    FROM research_dev.medical_adj_poem
    WHERE proc_cd IN (
        '90804', '90805', '90806', '90807', '90808', '90809', '90810', '90811', '90812', '90813',
        '90814', '90815', '90816', '90817', '90818', '90819', '90821', '90822', '90823', '90824',
        '90826', '90827', '90828', '90829', '90832', '90833', '90834', '90836', '90837', '90838',
        '90839', '90840', '90845', '90846', '90847', '90849', '90853', '90857', '90862', '90875',
        '90876', '90820', '90841', '90842', '90843', '90844', '90855'
    )
    UNION ALL
    SELECT DISTINCT c.pers_id, c.clm_id AS clm_id
    FROM research_dev.medical_adj_poem c
    JOIN research_dev.med_dx_poem d
        ON c.pers_id = d.pers_id 
        AND c.clm_id = d.clm_id
    WHERE c.proc_cd IN (
        '99201', '99202', '99203', '99204', '99205',
        '99211', '99212', '99213', '99214', '99215'
    )
    AND (
        LEFT(REPLACE(d.dx, '.', ''), 3) IN (
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
        OR REPLACE(d.dx, '.', '') = 'O9934'
    )
) a
where pers_id in (select pers_id from research_dev.poem_cohort );

--- combine and give categories 
DROP TABLE IF EXISTS research_dev.poem_outcomes_outpatient_categories;

CREATE TABLE research_dev.poem_outcomes_outpatient_categories AS
SELECT a.*, 
       CASE WHEN b.pers_id IS NOT NULL THEN 1 ELSE 0 END AS pe,
       CASE WHEN c.pers_id IS NOT NULL THEN 1 ELSE 0 END AS prev,
       CASE WHEN d.pers_id IS NOT NULL THEN 1 ELSE 0 END AS contr,
       CASE WHEN e.pers_id IS NOT NULL THEN 1 ELSE 0 END AS mental,
       CASE WHEN b.pers_id IS NULL 
            AND c.pers_id IS NULL 
            AND d.pers_id IS NULL 
            AND e.pers_id IS NULL THEN 1 ELSE 0 END AS other
FROM research_dev.poem_outcomes_outpatient_all a 
LEFT JOIN research_dev.poem_outcomes_outpatient_pe b 
    ON a.pers_id = b.pers_id 
    AND a.clm_id = b.clm_id
LEFT JOIN research_dev.poem_outcomes_outpatient_prev c
    ON a.pers_id = c.pers_id 
    AND a.clm_id = c.clm_id
LEFT JOIN research_dev.poem_outcomes_outpatient_contr d
    ON a.pers_id = d.pers_id 
    AND a.clm_id = d.clm_id
LEFT JOIN research_dev.poem_outcomes_outpatient_mental e
    ON a.pers_id = e.pers_id 
    AND a.clm_id = e.clm_id;

--- link to episodes and count
DROP TABLE IF EXISTS research_dev.poem_outcomes_outpatient_12;

CREATE TABLE research_dev.poem_outcomes_outpatient_12 AS
SELECT
    c.pers_id,
    c.ep_num,
    MAX(op.pe) AS out_pe_12,
    MAX(op.prev) AS out_prev_12, 
    MAX(op.contr) AS out_contr_12,
    MAX(op.mental) AS out_mental_12,
    MAX(op.other) AS out_other_12,
    CASE WHEN COUNT(op.pers_id) > 0 THEN 1 ELSE 0 END AS out_any_outpatient_12,
    COUNT(DISTINCT CASE WHEN op.pe = 1 THEN op.date_ END) AS pe_visit_days_12,
    COUNT(DISTINCT CASE WHEN op.prev = 1 THEN op.date_ END) AS prev_visit_days_12,
    COUNT(DISTINCT CASE WHEN op.contr = 1 THEN op.date_ END) AS contr_visit_days_12,
    COUNT(DISTINCT CASE WHEN op.mental = 1 THEN op.date_ END) AS mental_visit_days_12,
    COUNT(DISTINCT CASE WHEN op.other = 1 THEN op.date_ END) AS other_visit_days_12,
    COUNT(DISTINCT op.date_) AS total_visit_days_12,
    COUNT(op.pers_id) AS total_claims_12
FROM research_dev.poem_cohort c
LEFT JOIN research_dev.poem_outcomes_outpatient_categories op
    ON c.pers_id = op.pers_id
    AND op.date_ BETWEEN c.anchor_date + 1 AND c.anchor_date + 365
GROUP BY
    c.pers_id,
    c.ep_num;

--- provide summary of combos
DROP TABLE IF EXISTS research_dev.poem_outcomes_outpatient_categories_summary;  

CREATE TABLE research_dev.poem_outcomes_outpatient_categories_summary AS
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
    FROM research_dev.poem_outcomes_outpatient_categories a 
    JOIN research_dev.poem_cohort c
        ON c.pers_id = a.pers_id
        AND a.date_ BETWEEN c.anchor_date + 1 AND c.anchor_date + 365
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
    CAST(100.0 * n / total AS NUMERIC(5,1)) AS share_of_visits
FROM counts, totals;



/* ----------------------------------
 * MH Drugs (NDC-based)
 * ----------------------------------*/

DROP TABLE IF EXISTS research_dev.poem_outcomes_out_mh_drug;

CREATE TABLE research_dev.poem_outcomes_out_mh_drug AS
SELECT
    c.pers_id,
    c.ep_num,
    CASE WHEN COUNT(p.ndc) > 0 THEN 1 ELSE 0 END AS out_mh_drug_12
FROM research_dev.poem_cohort c
LEFT JOIN research_dev.pharmacy_adj_poem p
    ON p.pers_id = c.pers_id
    AND p.fill_dt BETWEEN c.anchor_date + 1 AND c.anchor_date + 365
    AND p.ndc IN (SELECT ndc FROM research_dev.poem_mh_ndc)
GROUP BY
    c.pers_id,
    c.ep_num;
   
 /* ----------------------------------
 * MH Drug Details (NDC-based, 12 months)
 * ----------------------------------*/

DROP TABLE IF EXISTS research_dev.poem_outcomes_out_mh_drug_detail;

CREATE TABLE research_dev.poem_outcomes_out_mh_drug_detail AS
SELECT
    c.pers_id,
    c.ep_num,
    COUNT(p.ndc)                        AS out_mh_drug_scripts_12,
    SUM(p.days_supply)                     AS out_mh_drug_days_covered_12,
    AVG(p.days_supply)                     AS out_mh_drug_avg_days_supply_12
FROM research_dev.poem_cohort c
LEFT JOIN research_dev.pharmacy_adj_poem p
    ON p.pers_id = c.pers_id
    AND p.fill_dt BETWEEN c.anchor_date + 1 AND c.anchor_date + 365
    AND p.ndc IN (SELECT ndc FROM research_dev.poem_mh_ndc)
GROUP BY
    c.pers_id,
    c.ep_num;

/* ----------------------------------
 * Therapy Sessions (CPT-based)
 * ----------------------------------*/

DROP TABLE IF EXISTS research_dev.poem_outcomes_out_therapy;

CREATE TABLE research_dev.poem_outcomes_out_therapy AS
SELECT
    c.pers_id,
    c.ep_num,
    CASE WHEN COUNT(m.proc_cd) > 0 THEN 1 ELSE 0 END AS out_therapy_12
FROM research_dev.poem_cohort c
LEFT JOIN research_dev.medical_adj_poem m
    ON m.pers_id = c.pers_id
    AND m.dos_thru BETWEEN c.anchor_date + 1 AND c.anchor_date + 365
    AND m.proc_cd IN (
        '90832', '90833', '90834', '90836', '90837', '90838',
        '90839', '90840', '90846', '90847', '90849', '90853',
        '90863', 'G0176', 'H2032'
    )
GROUP BY
    c.pers_id,
    c.ep_num;


------------------
--- Mental Health DX (Subsequent, within 1 year after anchor) -----
------------------

-- all subsequent MH DX with categories
DROP TABLE IF EXISTS research_dev.poem_cohort_subgroup_mh_post1;

CREATE TABLE research_dev.poem_cohort_subgroup_mh_post1 AS
SELECT DISTINCT 
    a.pers_id, 
    a.dos,
    b.mh_category
FROM research_dev.med_dx_poem a 
JOIN research_dev.poem_mh_dx b 
    ON a.dx = b.icd_dx
WHERE a.pers_id IN (SELECT pers_id FROM research_dev.poem_cohort);

-- mental health DX to anchor dates with categories (1 year after)
DROP TABLE IF EXISTS research_dev.poem_cohort_mh_post_sample_detail;

CREATE TABLE research_dev.poem_cohort_mh_post_sample_detail AS
SELECT 
    a.pers_id, 
    a.ep_num,
    b.mh_category,
    COUNT(b.dos) AS dx_count
FROM research_dev.poem_cohort a
INNER JOIN research_dev.poem_cohort_subgroup_mh_post1 b 
    ON a.pers_id = b.pers_id 
    AND b.dos BETWEEN a.anchor_date + 1 AND a.anchor_date + 365
GROUP BY 
    a.pers_id, 
    a.ep_num,
    b.mh_category;

-- one row per pers_id and ep_num — any subsequent MH dx in year after anchor
DROP TABLE IF EXISTS research_dev.poem_cohort_mh_post_sample;

CREATE TABLE research_dev.poem_cohort_mh_post_sample AS
SELECT 
    a.pers_id, 
    a.ep_num,
    CASE 
        WHEN COUNT(b.dos) > 0 THEN 1 
        ELSE 0 
    END AS out_mh_dx_12,
    MAX(CASE WHEN b.mh_category = 'Anxiety and fear-related disorders'               THEN 1 ELSE 0 END) AS out_mh_anxiety_12,
    MAX(CASE WHEN b.mh_category = 'Depressive disorders'                              THEN 1 ELSE 0 END) AS out_mh_depression_12,
    MAX(CASE WHEN b.mh_category = 'Suicidal ideation/attempt/intentional self-harm'  THEN 1 ELSE 0 END) AS out_mh_suicidal_12,
    MAX(CASE WHEN b.mh_category = 'Schizophrenia spectrum/other pyschotic disorders' THEN 1 ELSE 0 END) AS out_mh_schizophrenia_12,
    MAX(CASE WHEN b.mh_category = 'Trauma- and stressor-related disorders'           THEN 1 ELSE 0 END) AS out_mh_trauma_12,
    MAX(CASE WHEN b.mh_category = 'Bipolar and related disorders'                    THEN 1 ELSE 0 END) AS out_mh_bipolar_12,
    MAX(CASE WHEN b.mh_category = 'Other - neurodevelopmental disorders'             THEN 1 ELSE 0 END) AS out_mh_neurodevelopmental_12,
    MAX(CASE WHEN b.mh_category = 'Other - other disorders'                          THEN 1 ELSE 0 END) AS out_mh_other_12,
    MAX(CASE WHEN REPLACE(f53.dx, '.', '') LIKE 'F53%'                               THEN 1 ELSE 0 END) AS out_mh_postpartum_f53_12
FROM research_dev.poem_cohort a
LEFT JOIN research_dev.poem_cohort_subgroup_mh_post1 b 
    ON a.pers_id = b.pers_id 
    AND b.dos BETWEEN a.anchor_date + 1 AND a.anchor_date + 365
LEFT JOIN research_dev.med_dx_poem f53 -- additional add for category not in original table 
    ON a.pers_id = f53.pers_id
    AND f53.dos BETWEEN a.anchor_date + 1 AND a.anchor_date + 365
    AND REPLACE(f53.dx, '.', '') LIKE 'F53%'
GROUP BY 
    a.pers_id, 
    a.ep_num;

DROP TABLE IF EXISTS research_dev.poem_cohort_subgroup_mh_post1;