/*
 * Build table - Paper 2 (MH outcomes)
 */

DROP TABLE IF EXISTS research_dev.poem_cohort_analysis2;

CREATE TABLE research_dev.poem_cohort_analysis2 AS
SELECT DISTINCT
    a.*,
    mh.mh_sample,
    mh.mh_anxiety,
    mh.mh_depression,
    mh.mh_suicidal,
    mh.mh_schizophrenia,
    mh.mh_trauma,
    mh.mh_bipolar,
    mh.mh_neurodevelopmental,
    mh.mh_other,
    mh.mh_postpartum_f53,
    mh_post.out_mh_dx_12,
    mh_post.out_mh_anxiety_12,
    mh_post.out_mh_depression_12,
    mh_post.out_mh_suicidal_12,
    mh_post.out_mh_schizophrenia_12,
    mh_post.out_mh_trauma_12,
    mh_post.out_mh_bipolar_12,
    mh_post.out_mh_neurodevelopmental_12,
    mh_post.out_mh_other_12,
    mh_post.out_mh_postpartum_f53_12,
    d.out_mh_drug_12,
    dd.out_mh_drug_scripts_12,
    dd.out_mh_drug_days_covered_12,
    dd.out_mh_drug_avg_days_supply_12,
    t.out_therapy_12,
    op.out_any_outpatient_12,
    op.total_visit_days_12,
    enroll.out_enroll_12,
    enroll.ce_after,
    enroll.ce_before,
    enroll.total_months_after,
    enroll.total_months_before,
    CASE WHEN enroll.ce_after >= 13 THEN 1 ELSE 0 END AS ce_after_12,
    elig.data_submitter_code,
    elig.mc_flag,
    elig.mc_sc,
    elig.me_at,
    elig.me_code,
    elig.me_tp,
    elig.me_sd,
    elig.riskgrp_id,
    w.no_transfusion_weight
FROM research_dev.poem_cohort a
LEFT JOIN research_dev.poem_cohort_mh_sample mh
    ON a.pers_id = mh.pers_id
    AND a.ep_num = mh.ep_num
LEFT JOIN research_dev.poem_cohort_mh_post_sample mh_post
    ON a.pers_id = mh_post.pers_id
    AND a.ep_num = mh_post.ep_num
LEFT JOIN research_dev.poem_outcomes_out_mh_drug d
    ON a.pers_id = d.pers_id
    AND a.ep_num = d.ep_num
LEFT JOIN research_dev.poem_outcomes_out_mh_drug_detail dd
    ON a.pers_id = dd.pers_id
    AND a.ep_num = dd.ep_num
LEFT JOIN research_dev.poem_outcomes_out_therapy t
    ON a.pers_id = t.pers_id
    AND a.ep_num = t.ep_num
LEFT JOIN research_dev.poem_outcomes_outpatient_12 op
    ON a.pers_id = op.pers_id
    AND a.ep_num = op.ep_num
LEFT JOIN research_dev.poem_outcomes_enroll enroll
    ON a.pers_id = enroll.pers_id
    AND a.ep_num = enroll.ep_num
LEFT JOIN research_dev.poem_outcomes_mcd_elig elig
    ON a.pers_id = elig.pers_id
    AND a.ep_num = elig.ep_num
LEFT JOIN research_dev.poem_cohort_weights w
    ON a.pers_id = w.pers_id
    AND a.ep_num = w.ep_num;

SELECT COUNT(*)
FROM research_dev.poem_cohort_analysis2
UNION ALL
SELECT COUNT(*)
FROM research_dev.poem_cohort;

SELECT * FROM research_dev.poem_cohort_analysis2;