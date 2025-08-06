  select count(*) 
    from chcdwork.dbo.poem_cohort_analysis1
    union all
   select count(*) 
    from chcdwork.dbo.poem_cohort
    ;
    
   
   select * 
     from chcdwork.dbo.poem_cohort_analysis1 where out_htn_med_12 is null
     
     
select * 
  from CHCDWORK.dbo.poem_outcomes_out_postpartum12;
  
 with get_bundled as (
 select distinct client_nbr, ep_num, 1 as pp_bundled
  from CHCDWORK.dbo.poem_outcomes_out_postpartum12 where code_type = 'Bundled CPT'
  ), 
  get_non_bundled as (
  select distinct client_nbr, ep_num, 1 as pp_not_bundled
  from CHCDWORK.dbo.poem_outcomes_out_postpartum12 
 where code_type <> 'Bundled CPT' and code_type is not null
  ),
 get_non_bundled as (
  select distinct client_nbr, ep_num, 1 as pp_not_bundled
  from CHCDWORK.dbo.poem_outcomes_out_postpartum12 
 where code_type <> 'Bundled CPT' and code_type is not null
  )
  ;
  
 
  select count(distinct client_nbr + ep_num)
  from CHCDWORK.dbo.poem_outcomes_out_postpartum12 where code_type = 'Bundled CPT'
union all  
  select count(distinct client_nbr + ep_num)
  from CHCDWORK.dbo.poem_outcomes_out_postpartum12 
   where code_type is not null;
   
  --8% had bundled codes 