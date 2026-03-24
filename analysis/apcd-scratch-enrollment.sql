DROP TABLE IF EXISTS research_dev.poem_cohort_with_elig;

CREATE TABLE research_dev.poem_cohort_with_elig AS
WITH c AS (
  SELECT
    pc.*,
    (EXTRACT(YEAR  FROM pc.anchor_date)::int * 100
     + EXTRACT(MONTH FROM pc.anchor_date)::int) AS anchor_yrmon
  FROM research_dev.poem_cohort pc
)
SELECT
  distinct c.*,
  e.yrmon              AS elig_yrmon,
  e.data_submitter_code,
  e.payor_code,
  e.group_name,
  e.mem_id,
  e.pure_rate,
  e.mco_id,
  e.fam_size,
  e.education,
  e.case_nbr,
  e.tx_hold,
  e.mc_flag,
  e.mc_sc,
  e.me_at,
  e.me_code,
  e.me_tp,
  e.me_sd,
  e.riskgrp_id,
  e.fam_income,
  e.sig,
  e.base_plan,
  mh.mh_sample
FROM c
JOIN research_di.mcd_elig_supp e
  ON e.apcd_id = c.apcd_id
 AND e.yrmon   = c.anchor_yrmon
LEFT JOIN research_dev.poem_cohort_mh_sample mh 
    ON c.apcd_id = mh.apcd_id 
    AND c.ep_num = mh.ep_num;
DISTRIBUTED RANDOMLY;


select * from research_dev.poem_cohort_with_elig  order by 1,2;