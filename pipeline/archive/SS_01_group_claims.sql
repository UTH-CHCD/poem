
 
 drop table if exists CHCDWORK.dbo.poem_episodes_alldates;
 
-- insert discharges
 select distinct a.client_nbr , a.ep_num, 'discharge' as clm_type, b.discharge_date as date_
   into CHCDWORK.dbo.poem_episodes_alldates
   from chcdwork.dbo.poem_episodes_enrollment a 
   join chcdwork.dbo.poem_episodes_raw b 
    on a.client_nbr = b.client_nbr 
   and a.streak_id = b.streak_id 
   where b.discharge_date is not null
   order by a.client_nbr , a.ep_num 
  ;
  
 insert into CHCDWORK.dbo.poem_episodes_alldates
  select distinct a.client_nbr , a.ep_num, 'admit' as clm_type, b.admit_date 
   from chcdwork.dbo.poem_episodes_enrollment a 
   join chcdwork.dbo.poem_episodes_raw b 
    on a.client_nbr = b.client_nbr 
   and a.streak_id = b.streak_id 
   where b.admit_date is not null
   order by a.client_nbr , a.ep_num 
  ;
 
  insert into CHCDWORK.dbo.poem_episodes_alldates
  select distinct a.client_nbr , a.ep_num, 'clm_to' as clm_type, b.clm_to_date  
   from chcdwork.dbo.poem_episodes_enrollment a 
   join chcdwork.dbo.poem_episodes_raw b 
    on a.client_nbr = b.client_nbr 
   and a.streak_id = b.streak_id 
   where b.clm_to_date is not null
   order by a.client_nbr , a.ep_num 
  ;
 
  insert into CHCDWORK.dbo.poem_episodes_alldates
  select distinct a.client_nbr , a.ep_num, 'clm_from' as clm_type, b.clm_from_date  
   from chcdwork.dbo.poem_episodes_enrollment a 
   join chcdwork.dbo.poem_episodes_raw b 
    on a.client_nbr = b.client_nbr 
   and a.streak_id = b.streak_id 
   where b.clm_from_date is not null
   order by a.client_nbr , a.ep_num 
  ;
 
 select * from CHCDWORK.dbo.poem_episodes_alldates order by client_nbr, ep_num, date_
 
 -- get count of number of days per episode
/* with get_count as (
 select client_nbr , ep_num , count(distinct date_) as c
  from CHCDWORK.dbo.poem_episodes_alldates
  group by client_nbr , ep_num 
  )
  select c as unique_dates, count(distinct client_nbr + cast(ep_num as varchar)) as episode_count
    from get_count
    group by c
    order by c;*/
   
 --- get date ranges of min max per episode
 drop table if exists CHCDWORK.dbo.poem_episodes_dateranges;
 
select client_nbr , ep_num , 
       min( date_) as min_date, 
       max(date_) as max_date
  into CHCDWORK.dbo.poem_episodes_dateranges
  from CHCDWORK.dbo.poem_episodes_alldates
  group by client_nbr , ep_num ;
 
 
 
 
 /*
  * Get Delivery Codes and Dates 
  */

 ---clm procs 
 drop table if exists chcdwork.dbo.poem_all_proc;
 
   with get_proc as (
    select
        trim(a.icn) as icn,
        trim(a.pcn) as pcn,
        cast(d.hdr_frm_dos as date) as hdr_frm_dos,
        cast(d.hdr_to_dos as date) as hdr_to_dos,
        proc_icd_cd
    from chcdwork.dbo.clm_proc a
    join chcdwork.dbo.clm_header d on d.icn = a.icn
    cross apply (
        values
            (rtrim(a.proc_icd_cd_1)), (rtrim(a.proc_icd_cd_2)), (rtrim(a.proc_icd_cd_3)),
            (rtrim(a.proc_icd_cd_4)), (rtrim(a.proc_icd_cd_5)), (rtrim(a.proc_icd_cd_6)),
            (rtrim(a.proc_icd_cd_7)), (rtrim(a.proc_icd_cd_8)), (rtrim(a.proc_icd_cd_9)),
            (rtrim(a.proc_icd_cd_10)), (rtrim(a.proc_icd_cd_11)), (rtrim(a.proc_icd_cd_12)),
            (rtrim(a.proc_icd_cd_13)), (rtrim(a.proc_icd_cd_14)), (rtrim(a.proc_icd_cd_15)),
            (rtrim(a.proc_icd_cd_16)), (rtrim(a.proc_icd_cd_17)), (rtrim(a.proc_icd_cd_18)),
            (rtrim(a.proc_icd_cd_19)), (rtrim(a.proc_icd_cd_20)), (rtrim(a.proc_icd_cd_21)),
            (rtrim(a.proc_icd_cd_22)), (rtrim(a.proc_icd_cd_23)), (rtrim(a.proc_icd_cd_24)),
            (rtrim(a.proc_icd_cd_25))
    ) as unnested(proc_icd_cd)
    where year(cast(d.hdr_frm_dos as date)) > 2018
)
select distinct
	    a.pcn as client_nbr,
	    a.hdr_frm_dos as clm_from_date,
	    a.hdr_to_dos as clm_to_date,
        a.proc_icd_cd,
        b.description
   into chcdwork.dbo.poem_all_proc
   from get_proc a
   join chcdwork.dbo.poem_codeset_delivery b 
   on a.proc_icd_cd = b.code
;
 
 --- enc procs 
 with get_proc as (
    select
        trim(a.mem_id) as mem_id,
        trim(a.derv_enc) as derv_enc,
        cast(d.frm_dos as date) as frm_dos,
        cast(d.to_dos as date) as to_dos,
        proc_icd_cd
    from chcdwork.dbo.enc_proc a
    join chcdwork.dbo.enc_header d on d.derv_enc = a.derv_enc 
    cross apply (
        values
            (rtrim(a.proc_icd_cd_1)),(rtrim(a.proc_icd_cd_2)),(rtrim(a.proc_icd_cd_3)),
            (rtrim(a.proc_icd_cd_4)), (rtrim(a.proc_icd_cd_5)),(rtrim(a.proc_icd_cd_6)),
            (rtrim(a.proc_icd_cd_7)),(rtrim(a.proc_icd_cd_8)),(rtrim(a.proc_icd_cd_9)),
            (rtrim(a.proc_icd_cd_10)),(rtrim(a.proc_icd_cd_11)),(rtrim(a.proc_icd_cd_12)),
            (rtrim(a.proc_icd_cd_13)),(rtrim(a.proc_icd_cd_14)),(rtrim(a.proc_icd_cd_15)),
            (rtrim(a.proc_icd_cd_16)),(rtrim(a.proc_icd_cd_17)),(rtrim(a.proc_icd_cd_18)),
            (rtrim(a.proc_icd_cd_19)),(rtrim(a.proc_icd_cd_20)),(rtrim(a.proc_icd_cd_21)),
            (rtrim(a.proc_icd_cd_22)),(rtrim(a.proc_icd_cd_23)),(rtrim(a.proc_icd_cd_24))
    ) as unnested(proc_icd_cd)
    where year(cast(d.frm_dos as date)) > 2018
)
insert into chcdwork.dbo.poem_all_proc
select mem_id as client_nbr,
       a.frm_dos as clm_from_date,
	    a.to_dos as clm_to_date,
	    a.proc_icd_cd,
        b.description
  from get_proc a
   join chcdwork.dbo.poem_codeset_delivery b 
   on a.proc_icd_cd = b.code;

  
select *
  from chcdwork.dbo.clm_proc a
join CHCDWORK.dbo.clm_detail b 
on a.ICN = b.icn

