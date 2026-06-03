-- ============================================================
-- Paper 1 Analysis Table — ETL
-- Converted from SQL Server to Greenplum/PostgreSQL
-- Schema: dev (replaces CHCDWORK.dbo)
-- ============================================================

/*
 * Build analysis table
 */

DROP TABLE IF EXISTS dev.poem_cohort_analysis1;

CREATE TABLE dev.poem_cohort_analysis1 AS
SELECT DISTINCT
    a.*,
    b.diab_sample,
    b.pre_existing_diab,
    b.gest_diab,
    h.htn_sample,
    h.htn_chronic,
    h.htn_gestational,
    h.htn_preeclampsia,
    h.htn_pulmonary,
    c.out_diab_screen_6,
    c.out_diab_screen_12,
    dt.out_diab_screen_hba1c_6,
    dt.out_diab_screen_gtt_6,
    dt.out_diab_screen_hba1c_12,
    dt.out_diab_screen_gtt_12,
    d.out_postpartum,
    d.out_postpartum_6,
    d.out_postpartum_12,
    hm.out_htn_med_6,
    hm.out_htn_med_12,
    op.out_pe_12,
    op.out_prev_12,
    op.out_contr_12,
    op.out_mental_12,
    op.out_other_12,
    op.out_any_outpatient_12,
    op.pe_visit_days_12,
    op.prev_visit_days_12,
    op.contr_visit_days_12,
    op.mental_visit_days_12,
    op.other_visit_days_12,
    op.total_visit_days_12,
    op.total_claims_12,
    -- 0–61 day outpatient window
    op61.out_pe_0_61,
    op61.out_prev_0_61,
    op61.out_contr_0_61,
    op61.out_mental_0_61,
    op61.out_other_0_61,
    op61.out_any_outpatient_0_61,
    op61.pe_visit_days_0_61,
    op61.prev_visit_days_0_61,
    op61.contr_visit_days_0_61,
    op61.mental_visit_days_0_61,
    op61.other_visit_days_0_61,
    op61.total_visit_days_0_61,
    op61.total_claims_0_61,
    -- 61 days to 12 months outpatient window
    op61_12.out_pe_61_12,
    op61_12.out_prev_61_12,
    op61_12.out_contr_61_12,
    op61_12.out_mental_61_12,
    op61_12.out_other_61_12,
    op61_12.out_any_outpatient_61_12,
    op61_12.pe_visit_days_61_12,
    op61_12.prev_visit_days_61_12,
    op61_12.contr_visit_days_61_12,
    op61_12.mental_visit_days_61_12,
    op61_12.other_visit_days_61_12,
    op61_12.total_visit_days_61_12,
    op61_12.total_claims_61_12,
    w.smm_weight,
    w.no_transfusion_weight,
    enroll.out_enroll_12,
    enroll.ce_after,
    enroll.ce_before,
    enroll.total_months_after,
    enroll.total_months_before,
    enroll.ce_after_nohtw,
    CASE WHEN enroll.ce_after_nohtw >= 13 THEN 1 ELSE 0 END AS ce_after_12_nohtw,
    CASE WHEN enroll.ce_after        >= 13 THEN 1 ELSE 0 END AS ce_after_12,
    mh.mh_sample,
    cwlk.phr,
    cwlk.hsr
FROM dev.poem_cohort a
LEFT JOIN dev.poem_cohort_diab_sample                    b      ON a.client_nbr = b.client_nbr      AND a.ep_num = b.ep_num
LEFT JOIN dev.poem_outcomes_out_diab_screen              c      ON a.client_nbr = c.client_nbr      AND a.ep_num = c.ep_num
LEFT JOIN dev.poem_outcomes_out_diab_screen_by_type_6_12mo dt   ON a.client_nbr = dt.client_nbr     AND a.ep_num = dt.ep_num
LEFT JOIN dev.poem_outcomes_out_postpartum               d      ON a.client_nbr = d.client_nbr      AND a.ep_num = d.ep_num
LEFT JOIN dev.poem_cohort_htn_sample                     h      ON a.client_nbr = h.client_nbr      AND a.ep_num = h.ep_num
LEFT JOIN dev.poem_outcomes_out_htn_med                  hm     ON a.client_nbr = hm.client_nbr     AND a.ep_num = hm.ep_num
LEFT JOIN dev.poem_outcomes_outpatient_12                op     ON a.client_nbr = op.client_nbr     AND a.ep_num = op.ep_num
LEFT JOIN dev.poem_outcomes_outpatient_0_61              op61   ON a.client_nbr = op61.client_nbr   AND a.ep_num = op61.ep_num
LEFT JOIN dev.poem_outcomes_outpatient_61_12             op61_12 ON a.client_nbr = op61_12.client_nbr AND a.ep_num = op61_12.ep_num
LEFT JOIN dev.poem_cohort_weights                        w      ON a.client_nbr = w.client_nbr      AND a.ep_num = w.ep_num
LEFT JOIN dev.poem_outcomes_enroll                       enroll ON a.client_nbr = enroll.client_nbr AND a.ep_num = enroll.ep_num
LEFT JOIN dev.poem_cohort_mh_sample                      mh     ON a.client_nbr = mh.client_nbr     AND a.ep_num = mh.ep_num
LEFT JOIN dev.zip_phr_hsr_crosswalk                      cwlk   ON a.zip = cwlk.zip;


-- Sanity checks
SELECT count(*) FROM dev.poem_cohort_analysis1
UNION ALL
SELECT count(*) FROM dev.poem_cohort
UNION ALL
SELECT count(*) FROM dev.poem_outcomes_out_htn_med;


/*
 * Diabetes detail table
 */

DROP TABLE IF EXISTS dev.poem_cohort_analysis_diab_detail;

CREATE TABLE dev.poem_cohort_analysis_diab_detail AS
WITH get_diabetes AS (
    SELECT DISTINCT client_nbr, ep_num, 1 AS diab_sample
    FROM dev.poem_cohort_dx_cov_280
    WHERE variable_name IN ('com_pre_dm', 'com_gest_dm')
)
SELECT
    a.*,
    COALESCE(b.diab_sample, 0) AS diab_sample,
    c.test_type,
    c.out_diab_screen_6,
    c.out_diab_screen_12
FROM dev.poem_cohort a
LEFT JOIN get_diabetes                           b  ON a.client_nbr = b.client_nbr AND a.ep_num = b.ep_num
LEFT JOIN dev.poem_outcomes_out_diab_screen_detail c ON a.client_nbr = c.client_nbr AND a.ep_num = c.ep_num
LEFT JOIN dev.poem_outcomes_out_postpartum        d  ON a.client_nbr = d.client_nbr AND a.ep_num = d.ep_num;


-----------------------------------------
-- Scratch / QA (commented out)
-----------------------------------------

/*
-- Diabetes QA: what % of covariates occur during the episode vs. prior
DROP TABLE IF EXISTS dev.poem_cohort_diab_qa;

CREATE TABLE dev.poem_cohort_diab_qa AS
SELECT client_nbr, ep_num, anchor_date, MAX(during_episode) AS during_episode
FROM (
    SELECT DISTINCT a.client_nbr, a.ep_num, a.anchor_date, 1 AS during_episode
    FROM dev.poem_cohort a
    JOIN dev.poem_cohort_dx_cov_all b
        ON a.client_nbr = b.client_nbr
       AND b.clm_from_date BETWEEN a.start_date AND a.end_date
    WHERE variable_name LIKE '%dm%'
    UNION ALL
    SELECT DISTINCT a.client_nbr, a.ep_num, a.anchor_date, 0 AS during_episode
    FROM dev.poem_cohort a
    JOIN dev.poem_cohort_dx_cov_all b
        ON a.client_nbr = b.client_nbr
       AND (a.start_date - b.clm_from_date) BETWEEN 1 AND 280   -- DATEDIFF(day, clm_from_date, start_date)
    WHERE variable_name LIKE '%dm%'
) a
GROUP BY client_nbr, ep_num, anchor_date;

-- HTN QA
DROP TABLE IF EXISTS dev.poem_cohort_htn_qa;

CREATE TABLE dev.poem_cohort_htn_qa AS
SELECT client_nbr, ep_num, anchor_date, MAX(during_episode) AS during_episode
FROM (
    SELECT DISTINCT a.client_nbr, a.ep_num, a.anchor_date, 1 AS during_episode
    FROM dev.poem_cohort a
    JOIN dev.poem_cohort_dx_cov_all b
        ON a.client_nbr = b.client_nbr
       AND b.clm_from_date BETWEEN a.start_date AND a.end_date
    WHERE variable_name LIKE '%htn%'
    UNION ALL
    SELECT DISTINCT a.client_nbr, a.ep_num, a.anchor_date, 0 AS during_episode
    FROM dev.poem_cohort a
    JOIN dev.poem_cohort_dx_cov_all b
        ON a.client_nbr = b.client_nbr
       AND (a.start_date - b.clm_from_date) BETWEEN 1 AND 280   -- DATEDIFF(day, clm_from_date, start_date)
    WHERE variable_name LIKE '%htn%'
) a
GROUP BY client_nbr, ep_num, anchor_date;
*/


/*
-- Taxonomy code breakdown for prev/E&M visits after episode end
WITH get_tax AS (
    SELECT
        c.client_nbr,
        c.ep_num,
        CASE WHEN p.taxonomy_cd = '' THEN NULL ELSE p.taxonomy_cd END AS taxonomy_cd
    FROM dev.poem_cohort c
    LEFT JOIN dev.poem_cohort_cpt p
        ON c.client_nbr = p.client_nbr
       AND (
            (p.proc_cd BETWEEN '99202' AND '99215') OR
            (p.proc_cd BETWEEN '99381' AND '99429') OR
             p.proc_cd IN ('99441','99442','99443')
           )
       AND p.to_dos > c.end_date
)
SELECT display_name, COUNT(*) AS count_
FROM get_tax a
LEFT JOIN ref.nucc_taxonomy b ON a.taxonomy_cd = b.code
GROUP BY display_name
ORDER BY count_ DESC;

WITH get_tax AS (
    SELECT
        c.client_nbr,
        c.ep_num,
        CASE WHEN p.taxonomy_cd = '' THEN NULL ELSE p.taxonomy_cd END AS taxonomy_cd
    FROM dev.poem_cohort c
    LEFT JOIN dev.poem_cohort_cpt p
        ON c.client_nbr = p.client_nbr
       AND (
            (p.proc_cd BETWEEN '99202' AND '99215') OR
            (p.proc_cd BETWEEN '99381' AND '99429') OR
             p.proc_cd IN ('99441','99442','99443')
           )
       AND p.to_dos > c.end_date
)
SELECT grouping, classification, specialization, display_name, COUNT(*) AS count_
FROM get_tax a
LEFT JOIN ref.nucc_taxonomy b ON a.taxonomy_cd = b.code
GROUP BY grouping, classification, specialization, display_name
ORDER BY count_ DESC;
*/


/*
-- Claim/encounter date distribution checks
SELECT
    EXTRACT(YEAR  FROM clm_from_date) AS year_,
    EXTRACT(MONTH FROM clm_from_date) AS month_,
    COUNT(*) AS record_count
FROM dev.poem_cohort_dx
GROUP BY 1, 2
ORDER BY 1, 2;

SELECT
    EXTRACT(YEAR  FROM to_dos) AS year_,
    EXTRACT(MONTH FROM to_dos) AS month_,
    COUNT(*) AS record_count
FROM dev.poem_cohort_cpt
GROUP BY 1, 2
ORDER BY 1, 2;

SELECT
    EXTRACT(YEAR  FROM date_) AS year_,
    EXTRACT(MONTH FROM date_) AS month_,
    COUNT(*) AS record_count
FROM dev.poem_outcomes_outpatient_all
GROUP BY 1, 2
ORDER BY 1, 2;
*/


/*
-- Plan / enrollment category checks
SELECT me_code, plan_, COUNT(*)
FROM dev.poem_cohort
GROUP BY me_code, plan_
ORDER BY me_code, plan_;

SELECT me_code, plan_, dual, COUNT(*)
FROM dev.poem_cohort
GROUP BY me_code, plan_, dual
ORDER BY me_code, plan_, dual;

SELECT me_tp, COUNT(*)
FROM dev.poem_cohort
GROUP BY me_tp
ORDER BY COUNT(*);
*/
