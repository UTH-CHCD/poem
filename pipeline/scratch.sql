
   
   
   select * 
     from CHCDWORK.dbo.poem_all_dx_episodes 
     where client_nbr = '503336846'
order by client_nbr, rn;


 select * 
     from CHCDWORK.dbo.poem_all_dx_episodes  a 
     join CHCDWORK.dbo.poem_los b 
     on a.client_nbr = b.client_nbr
     and a.episode_id = b.episode_id
     and los > 100
order by a.client_nbr, rn;


   select client_nbr, outcome_type, start_date, end_date, episode_id
     from CHCDWORK.dbo.poem_all_dx_episodes 
   where client_nbr <> '000000000' 
   and client_nbr in (select client_nbr from CHCDWORK.dbo.poem_all_dx_episodes_count where ep_count = 4)
order by client_nbr, rn;

--- count by episodes
drop table if exists CHCDWORK.dbo.poem_all_dx_episodes_count;

select client_nbr, count(distinct episode_id) as ep_count
  into CHCDWORK.dbo.poem_all_dx_episodes_count
  from CHCDWORK.dbo.poem_all_dx_episodes 
 group by client_nbr;

select pat_stat, count(*)
  from CHCDWORK.dbo.poem_all_dx_episodes_start_end
 group by pat_stat;

select fac_prof, count(*)
  from CHCDWORK.dbo.poem_all_dx_episodes_start_end
 group by fac_prof;
  


    
    
-- check those with multiple dates    
with many_dates as (
   select client_nbr, episode_id , count(distinct clm_to_date) as c
    from CHCDWORK.dbo.poem_all_dx_episodes  
  group by client_nbr, episode_id
    having count(distinct clm_to_date) = 5
     )
     select * 
      from CHCDWORK.dbo.poem_all_dx_episodes a 
      join many_dates b 
      on a.client_nbr = b.client_nbr
      and a.episode_id = b.episode_id
      order by a.client_nbr, a.episode_id, a.rn ;
     
select datediff(day, admit_date, discharge_date) , count(*)
  from CHCDWORK.dbo.poem_all_dx_episodes
  group by datediff(day, admit_date, discharge_date)
  order by datediff(day, admit_date, discharge_date) 
  
  
select datediff(day, start_date, end_date) , count(*)
  from CHCDWORK.dbo.poem_all_dx_episodes_start_end
  group by datediff(day, start_date, end_date)
  order by datediff(day, start_date, end_date) 
 --- transfer stuff
  
  
select *
 from chcdwork.dbo.poem_episodes_enrollment
 where los = 1099;




select count(*)
 from chcdwork.dbo.poem_episodes_enrollment
 where los > 100;
     
   select *
     from CHCDWORK.dbo.poem_all_dx_episodes 
   where client_nbr <> '000000000' 
   and client_nbr in (
   select client_nbr from CHCDWORK.dbo.poem_all_dx_episodes 
where pat_stat in ('02', '05', '65', '82', '85', '88', '93', '94')
   )
order by client_nbr, rn;



   select count(distinct client_nbr) from CHCDWORK.dbo.poem_all_dx_episodes 
where pat_stat in ('02', '05', '65', '82', '85', '88', '93', '94');

select * from chcdwork.dbo.poem_episodes_enrollment;

--- getting multiple outcome types
drop table if exists CHCDWORK.dbo.poem_all_dx_episodes_multout;

select client_nbr, episode_id
into CHCDWORK.dbo.poem_all_dx_episodes_multout
  from CHCDWORK.dbo.poem_all_dx_episodes
 group by client_nbr, episode_id
having count(distinct outcome_type) > 1;


select * 
      from CHCDWORK.dbo.poem_all_dx_episodes a 
      join CHCDWORK.dbo.poem_all_dx_episodes_multout b 
      on a.client_nbr = b.client_nbr
      and a.episode_id = b.episode_id
      order by a.client_nbr, a.episode_id, a.rn ;