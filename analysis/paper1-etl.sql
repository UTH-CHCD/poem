/*
 * Build table
 */

DROP TABLE IF EXISTS chcdwork.dbo.poem_cohort_analysis1;

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
    enroll.out_enroll_12
INTO chcdwork.dbo.poem_cohort_analysis1
FROM chcdwork.dbo.poem_cohort a 
LEFT JOIN CHCDWORK.dbo.poem_cohort_diab_sample b 
    ON a.client_nbr = b.client_nbr 
    AND a.ep_num = b.ep_num
LEFT JOIN CHCDWORK.dbo.poem_outcomes_out_diab_screen c 
    ON a.client_nbr = c.client_nbr 
    AND a.ep_num = c.ep_num
LEFT JOIN CHCDWORK.dbo.poem_outcomes_out_diab_screen_by_type_6_12mo dt  
    ON a.client_nbr = dt.client_nbr 
    AND a.ep_num = dt.ep_num
LEFT JOIN CHCDWORK.dbo.poem_outcomes_out_postpartum d
    ON a.client_nbr = d.client_nbr 
    AND a.ep_num = d.ep_num
LEFT JOIN CHCDWORK.dbo.poem_cohort_htn_sample h
    ON a.client_nbr = h.client_nbr 
    AND a.ep_num = h.ep_num
LEFT JOIN CHCDWORK.dbo.poem_outcomes_out_htn_med hm
    ON a.client_nbr = hm.client_nbr 
    AND a.ep_num = hm.ep_num
LEFT JOIN CHCDWORK.dbo.poem_outcomes_outpatient_12 op  
    ON a.client_nbr = op.client_nbr 
    AND a.ep_num = op.ep_num
LEFT JOIN CHCDWORK.dbo.poem_cohort_weights w
    ON a.client_nbr = w.client_nbr 
    AND a.ep_num = w.ep_num
 left join CHCDWORK.dbo.poem_outcomes_enrollment enroll 
    ON a.client_nbr = enroll.client_nbr 
   AND a.ep_num = enroll.ep_num
;

  select count(*) 
    from chcdwork.dbo.poem_cohort_analysis1
    union all
   select count(*) 
    from chcdwork.dbo.poem_cohort
    union all
   select count(*) 
    from chcdwork.dbo.poem_outcomes_out_htn_med
    ;
    
select * from chcdwork.dbo.poem_cohort_analysis1;
   
 --- get diabetes detail 
drop table if exists chcdwork.dbo.poem_cohort_analysis_diab_detail;

with get_diabetes as (
select distinct client_nbr, ep_num , 1 as diab_sample
  from CHCDWORK.dbo.poem_cohort_dx_cov_280 
 where variable_name in ('com_pre_dm','com_gest_dm')
 )
select a.*, 
       COALESCE(b.diab_sample, 0) as diab_sample,
       test_type,
       out_diab_screen_6,
       out_diab_screen_12
  into chcdwork.dbo.poem_cohort_analysis_diab_detail
  from chcdwork.dbo.poem_cohort a 
  left join get_diabetes b 
    on a.client_nbr = b.client_nbr 
   and a.ep_num = b.ep_num
  left join CHCDWORK.dbo.poem_outcomes_out_diab_screen_detail c 
    on a.client_nbr = c.client_nbr 
   and a.ep_num = c.ep_num
  left join CHCDWORK.dbo.poem_outcomes_out_postpartum d
    on a.client_nbr = d.client_nbr 
   and a.ep_num = d.ep_num
;
   
   
   -----------------------------------------
   -----------------------------------------
   -----------------------------------------
   
   /*
   Scratch
   */
   
 /*  --- diabetes QA to see what % of the covariates occur during the episode 
   drop table if exists chcdwork.dbo.poem_cohort_diab_qa;
   
   select client_nbr, ep_num, anchor_date, max(during_episode)  as during_episode
   into chcdwork.dbo.poem_cohort_diab_qa
  from (
  select distinct a.client_nbr , a.ep_num , a.anchor_date , 1 as during_episode
    from chcdwork.dbo.poem_cohort a 
    join CHCDWORK.dbo.poem_cohort_dx_cov_all b 
    on a.client_nbr = b.client_nbr 
   and b.clm_from_date between a.start_date and a.end_date 
   where variable_name like '%dm%'
   union all 
     select distinct a.client_nbr , a.ep_num , a.anchor_date , 0 as during_episode 
    from chcdwork.dbo.poem_cohort a 
    join CHCDWORK.dbo.poem_cohort_dx_cov_all b 
    on a.client_nbr = b.client_nbr 
   and DATEDIFF(day, b.clm_from_date, a.start_date) between 1 and 280
   where variable_name like '%dm%'
   ) a
   group by client_nbr, ep_num, anchor_date; 
   
  --- check on hypertension
     drop table if exists chcdwork.dbo.poem_cohort_htn_qa;
   
   select client_nbr, ep_num, anchor_date, max(during_episode)  as during_episode
   into chcdwork.dbo.poem_cohort_htn_qa
  from (
  select distinct a.client_nbr , a.ep_num , a.anchor_date , 1 as during_episode
    from chcdwork.dbo.poem_cohort a 
    join CHCDWORK.dbo.poem_cohort_dx_cov_all b 
    on a.client_nbr = b.client_nbr 
   and b.clm_from_date between a.start_date and a.end_date 
   where variable_name like '%htn%'
   union all 
     select distinct a.client_nbr , a.ep_num , a.anchor_date , 0 as during_episode 
    from chcdwork.dbo.poem_cohort a 
    join CHCDWORK.dbo.poem_cohort_dx_cov_all b 
    on a.client_nbr = b.client_nbr 
   and DATEDIFF(day, b.clm_from_date, a.start_date) between 1 and 280
   where variable_name like '%htn%'
   ) a
   group by client_nbr, ep_num, anchor_date; */
   
  
  /*
   *   ---- taxonomy codes
   */
  /*
  with get_tax as (
  SELECT
    c.client_nbr,
    c.ep_num,
    case when p.taxonomy_cd = '' then null else p.taxonomy_cd end as taxonomy_cd
--INTO CHCDWORK.dbo.poem_outcomes_prev_em
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
    AND p.to_dos > c.end_date
    )
  select display_name , count(*) as count_
  from get_tax a 
  left join [REF].dbo.nucc_taxonomy b 
  on a.taxonomy_cd = b.code 
  GROUP by display_name 
  order by count_ desc
;
  
  
  with get_tax as (
  SELECT
    c.client_nbr,
    c.ep_num,
    case when p.taxonomy_cd = '' then null else p.taxonomy_cd end as taxonomy_cd
--INTO CHCDWORK.dbo.poem_outcomes_prev_em
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
    AND p.to_dos > c.end_date
    )
  select grouping, classification , specialization , display_name , count(*) as count_
  from get_tax a 
  left join [REF].dbo.nucc_taxonomy b 
  on a.taxonomy_cd = b.code 
  GROUP by grouping, classification , specialization , display_name 
  order by count_ desc
;
    
  */
  
  
  
  
  /*
   * 
   * 
   * 
   * SELECT 
    YEAR(clm_from_date) AS year_,
    MONTH(clm_from_date) AS month_,
    COUNT(*) AS record_count
FROM CHCDWORK.dbo.poem_cohort_dx
GROUP BY 
    YEAR(clm_from_date),
    MONTH(clm_from_date)
ORDER BY 
    YEAR(clm_from_date),
    MONTH(clm_from_date);
   
 SELECT 
    YEAR(to_dos) AS year_,
    MONTH(to_dos) AS month_,
    COUNT(*) AS record_count
FROM CHCDWORK.dbo.poem_cohort_cpt
GROUP BY 
    YEAR(to_dos),
    MONTH(to_dos)
ORDER BY 
    YEAR(to_dos),
    MONTH(to_dos);
   
   
 SELECT 
    YEAR(date_) AS year_,
    MONTH(date_) AS month_,
    COUNT(*) AS record_count
FROM CHCDWORK.dbo.poem_outcomes_outpatient_all
GROUP BY 
    YEAR(date_),
    MONTH(date_)
ORDER BY 
    YEAR(date_),
    MONTH(date_);
    */


/*
 * 
 * select me_code , plan_, count(*)
  from chcdwork.dbo.poem_cohort
  group by me_code , plan_
  order by me_code , plan_;
 
 select me_code , plan_, dual, count(*)
  from chcdwork.dbo.poem_cohort
  group by me_code , plan_, dual
  order by me_code , plan_, dual;
 
 select me_tp, count(*)  
  from chcdwork.dbo.enrl group by me_tp order by count(*) ;
 
 **/