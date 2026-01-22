/*
 * Build table
 */
DROP TABLE IF EXISTS research_dev.poem_cohort_analysis1;

CREATE TABLE research_dev.poem_cohort_analysis1 AS
SELECT DISTINCT 
    a.*, 
    diab_sample,
    pre_existing_diab,
    htn_sample,
    out_diab_screen_6,
    out_diab_screen_12,
    out_diab_screen_hba1c_6,   
    out_diab_screen_gtt_6,    
    out_diab_screen_hba1c_12,
    out_diab_screen_gtt_12,
    out_postpartum,
    out_postpartum_6,
    out_postpartum_12,
    out_htn_med_6,
    out_htn_med_12,
    out_pe_12,
    out_prev_12,
    out_contr_12,
    out_mental_12,
    out_other_12,
    out_any_outpatient_12,
    pe_visit_days_12,
    prev_visit_days_12,
    contr_visit_days_12,
    mental_visit_days_12,
    other_visit_days_12,
    total_visit_days_12,
    total_claims_12,
    smm_weight, 
    no_transfusion_weight,
    enroll.out_enroll_12,
    enroll.ce_after,
    enroll.ce_before,
    enroll.total_months_after,
    enroll.total_months_before,
    CASE WHEN enroll.ce_after >= 13 THEN 1 ELSE 0 END AS ce_after_12,
    mh.mh_sample
FROM research_dev.poem_cohort a 
LEFT JOIN research_dev.poem_cohort_diab_sample b 
    ON a.apcd_id = b.apcd_id 
    AND a.ep_num = b.ep_num
LEFT JOIN research_dev.poem_outcomes_out_diab_screen c 
    ON a.apcd_id = c.apcd_id 
    AND a.ep_num = c.ep_num
LEFT JOIN research_dev.poem_outcomes_out_diab_screen_by_type_6_12mo dt  
    ON a.apcd_id = dt.apcd_id 
    AND a.ep_num = dt.ep_num
LEFT JOIN research_dev.poem_outcomes_out_postpartum d
    ON a.apcd_id = d.apcd_id 
    AND a.ep_num = d.ep_num
LEFT JOIN research_dev.poem_cohort_htn_sample h
    ON a.apcd_id = h.apcd_id 
    AND a.ep_num = h.ep_num
LEFT JOIN research_dev.poem_outcomes_out_htn_med hm
    ON a.apcd_id = hm.apcd_id 
    AND a.ep_num = hm.ep_num
LEFT JOIN research_dev.poem_outcomes_outpatient_12 op  
    ON a.apcd_id = op.apcd_id 
    AND a.ep_num = op.ep_num
LEFT JOIN research_dev.poem_cohort_weights w
    ON a.apcd_id = w.apcd_id 
    AND a.ep_num = w.ep_num
LEFT JOIN research_dev.poem_outcomes_enroll enroll 
    ON a.apcd_id = enroll.apcd_id 
    AND a.ep_num = enroll.ep_num
LEFT JOIN research_dev.poem_cohort_mh_sample mh 
    ON a.apcd_id = mh.apcd_id 
    AND a.ep_num = mh.ep_num;

SELECT COUNT(*) 
FROM research_dev.poem_cohort_analysis1
UNION ALL
SELECT COUNT(*) 
FROM research_dev.poem_cohort
UNION ALL
SELECT COUNT(*) 
FROM research_dev.poem_outcomes_out_htn_med;

SELECT * FROM research_dev.poem_cohort_analysis1;

--- get diabetes detail 
DROP TABLE IF EXISTS research_dev.poem_cohort_analysis_diab_detail;

CREATE TABLE research_dev.poem_cohort_analysis_diab_detail AS
WITH get_diabetes AS (
    SELECT DISTINCT apcd_id, ep_num, 1 AS diab_sample
    FROM research_dev.poem_cohort_cov_280 
    WHERE condition IN ('com_pre_dm','com_gest_dm')
)
SELECT a.*, 
       COALESCE(b.diab_sample, 0) AS diab_sample,
       test_type,
       out_diab_screen_6,
       out_diab_screen_12
FROM research_dev.poem_cohort a 
LEFT JOIN get_diabetes b 
    ON a.apcd_id = b.apcd_id 
    AND a.ep_num = b.ep_num
LEFT JOIN research_dev.poem_outcomes_out_diab_screen_detail c 
    ON a.apcd_id = c.apcd_id 
    AND a.ep_num = c.ep_num
LEFT JOIN research_dev.poem_outcomes_out_postpartum d
    ON a.apcd_id = d.apcd_id 
    AND a.ep_num = d.ep_num;