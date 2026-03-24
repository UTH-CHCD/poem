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
    mh_post.out_mh_dx_12,
    mh_post.out_mh_anxiety_12,
    mh_post.out_mh_depression_12,
    mh_post.out_mh_suicidal_12,
    mh_post.out_mh_schizophrenia_12,
    mh_post.out_mh_trauma_12,
    mh_post.out_mh_bipolar_12,
    mh_post.out_mh_neurodevelopmental_12,
    mh_post.out_mh_other_12,
    d.out_mh_drug_12,
    t.out_therapy_12,
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
    ON a.apcd_id = mh.apcd_id
    AND a.ep_num = mh.ep_num
LEFT JOIN research_dev.poem_cohort_mh_post_sample mh_post
    ON a.apcd_id = mh_post.apcd_id
    AND a.ep_num = mh_post.ep_num
LEFT JOIN research_dev.poem_outcomes_out_mh_drug d
    ON a.apcd_id = d.apcd_id
    AND a.ep_num = d.ep_num
LEFT JOIN research_dev.poem_outcomes_out_therapy t
    ON a.apcd_id = t.apcd_id
    AND a.ep_num = t.ep_num
LEFT JOIN research_dev.poem_outcomes_enroll enroll
    ON a.apcd_id = enroll.apcd_id
    AND a.ep_num = enroll.ep_num
LEFT JOIN research_dev.poem_outcomes_mcd_elig elig
    ON a.apcd_id = elig.apcd_id
    AND a.ep_num = elig.ep_num
LEFT JOIN research_dev.poem_cohort_weights w
    ON a.apcd_id = w.apcd_id 
    AND a.ep_num = w.ep_num;

SELECT COUNT(*)
FROM research_dev.poem_cohort_analysis2
UNION ALL
SELECT COUNT(*)
FROM research_dev.poem_cohort;

SELECT * FROM research_dev.poem_cohort_analysis2;