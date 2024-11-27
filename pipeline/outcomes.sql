
/*
 * Outcomes for POEM Project 
 * 
 * Enrollment
 * Outpatient Contact 
 * 
 */


/* ------------------------------------------------------
 * Enrollment
 * 
 * Check to see if that person is enrolled 90 days later 
 * 90 Days begins the day AFTER the anchor day
 */ -----------------------------------------------------

-- 2024-11-04: Changed to next code to adjust for day after 
/*DROP TABLE IF EXISTS CHCDWORK.dbo.poem_outcomes_enrollment;

SELECT 
    c.client_nbr,
    c.ep_num,
    c.anchor_date,
    DATEADD(day, 90, c.anchor_date) AS end_date,
    CASE 
        WHEN d.client_nbr IS NOT NULL THEN 1
        ELSE 0
    END AS out_enroll_90
INTO CHCDWORK.dbo.poem_outcomes_enrollment
FROM chcdwork.dbo.poem_cohort c
LEFT JOIN chcdwork.dbo.poem_demographics d
    ON c.client_nbr = d.client_nbr
    AND YEAR(d.elig_month) = YEAR(DATEADD(day, 90, c.anchor_date))
    AND MONTH(d.elig_month) = MONTH(DATEADD(day, 90, c.anchor_date));*/
   
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_outcomes_enrollment;

SELECT 
    c.client_nbr,
    c.ep_num,
    CASE 
        WHEN d.client_nbr IS NOT NULL THEN 1
        ELSE 0
    END AS out_enroll_90
INTO CHCDWORK.dbo.poem_outcomes_enrollment
FROM chcdwork.dbo.poem_cohort c
LEFT JOIN chcdwork.dbo.poem_demographics d
    ON c.client_nbr = d.client_nbr
    AND YEAR(d.elig_month) = YEAR(DATEADD(day, 91, c.anchor_date))
    AND MONTH(d.elig_month) = MONTH(DATEADD(day, 91, c.anchor_date));
   
   
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
   
  --- make final postpartum outcome table 
 DROP TABLE IF EXISTS CHCDWORK.dbo.poem_outcomes_out_postpartum;

select client_nbr, ep_num, max(out_postpartum) as out_postpartum
  into CHCDWORK.dbo.poem_outcomes_out_postpartum 
  from CHCDWORK.dbo.poem_outcomes_out_postpartum1 
 group by client_nbr, ep_num;
   
  
-- Drop the temporary table
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_outcomes_postpartum_temp;
 
 
 
 