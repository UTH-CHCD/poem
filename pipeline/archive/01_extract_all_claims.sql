/*
 * This script pulls all claims for live births and stillbirths 
 * 
 */


----------------------------------------
--- Get All DX 
----------------------------------------

---CLM First 
drop table if exists dev.poem_all_dx;

create table dev.poem_all_dx as 
with get_dx as (
		select b.icn, b.pcn,
		       case when d.adm_dt = '' then null else d.adm_dt::date end as admit_date,
		       case when d.dis_dt = '' then null else d.dis_dt::date end as discharge_date,
		       d.hdr_frm_dos::date, 
		       d.hdr_to_dos::date, 
		      -- b.bill,
			   unnest(array[ trim(a.prim_dx_cd), trim(a.dx_cd_1), trim(a.dx_cd_2), trim(a.dx_cd_3), trim(a.dx_cd_4), trim(a.dx_cd_5), trim(a.dx_cd_6), 
			                  trim(a.dx_cd_7), trim(a.dx_cd_8), trim(a.dx_cd_9), trim(a.dx_cd_10), trim(a.dx_cd_11), trim(a.dx_cd_12), trim(a.dx_cd_13), 
			                  trim(a.dx_cd_14), trim(a.dx_cd_15), trim(a.dx_cd_16), trim(a.dx_cd_17), trim(a.dx_cd_18), trim(a.dx_cd_19),
			                  trim(a.dx_cd_20), trim(a.dx_cd_21), trim(a.dx_cd_22), trim(a.dx_cd_23), trim(a.dx_cd_24), trim(a.dx_cd_25) ] )as dx_cd
		  from medicaid.clm_dx a 
		  join medicaid.clm_proc b 
		    on b.icn = a.icn 
		  join medicaid.clm_header d  
		     on d.icn = b.icn 
		  where extract(year from d.hdr_frm_dos::date) > 2018
) 
select distinct 
       a.icn as clm_id,
       a.pcn as client_nbr, 
       a.admit_date,
       a.discharge_date,
       a.hdr_frm_dos as clm_from_date,
       a.hdr_to_dos as clm_to_date,
       'clm_dx' as src_table,
     --  a.bill as bill_type,
       b.*
  from get_dx a 
  join dev.poem_codeset_births b 
    on a.dx_cd = b.cd 
 ;


--- Then ENC
with get_dx as (
		select b.mem_id, b.derv_enc,
		       case when d.adm_dt = '0001-01-01' then null else d.adm_dt end as admit_date,
		       case when d.dis_dt = '0001-01-01' then null else d.dis_dt end as discharge_date,
		       d.frm_dos::date, 
		       d.to_dos::date, 
		       --b.bill,
			   unnest(array[ trim(a.prim_dx_cd), trim(a.dx_cd_1), trim(a.dx_cd_2), trim(a.dx_cd_3), trim(a.dx_cd_4), trim(a.dx_cd_5), trim(a.dx_cd_6), 
			                  trim(a.dx_cd_7), trim(a.dx_cd_8), trim(a.dx_cd_9), trim(a.dx_cd_10), trim(a.dx_cd_11), trim(a.dx_cd_12), trim(a.dx_cd_13), 
			                  trim(a.dx_cd_14), trim(a.dx_cd_15), trim(a.dx_cd_16), trim(a.dx_cd_17), trim(a.dx_cd_18), trim(a.dx_cd_19),
			                  trim(a.dx_cd_20), trim(a.dx_cd_21), trim(a.dx_cd_22), trim(a.dx_cd_23), trim(a.dx_cd_24) ] )as dx_cd
		  from medicaid.enc_dx a
		  join medicaid.enc_proc b
		    on trim(b.derv_enc) = trim(a.derv_enc)
		  join medicaid.enc_header d  
		     on d.derv_enc = b.derv_enc 
		  where extract(year from d.frm_dos::date) > 2018
) 
insert into dev.poem_all_dx
select distinct 
       a.derv_enc as clm_id,
       a.mem_id as client_nbr, 
       a.admit_date,
       a.discharge_date,
       a.frm_dos as clm_from_date,
       a.to_dos as clm_to_date,
       'enc_dx' as src_table,
     --  a.bill as bill_type,
       b.*
  from get_dx a 
  join dev.poem_codeset_births b 
    on a.dx_cd = b.cd 
 ;

--- delete where no valid patient id
delete from dev.poem_all_dx where client_nbr = '000000000';
vacuum analyze dev.poem_all_dx ;

select * from dev.poem_all_dx order by client_nbr;

--select count(*) from dev.poem_all_dx; --2925749
--select src_table, count(*) from dev.poem_all_dx group by 1; --2926361

----------------------------------------------
/*
 * Exclude on Age
 */
-----------------------------------------------

----------------
---First get age
----------------- 
drop table if exists dev.poem_temp_bday ;

--- Temp include chip
create table dev.poem_temp_bday as 
 with get_bdays as 
 (
 select client_nbr , dob::date as dob
  from medicaid.enrl
  where sex = 'F'
 union all
  select client_nbr, substring(date_of_birth,1,9)::date 
  from medicaid.chip_enrl
  where gender_cd = 'F'
  )
  select client_nbr , dob, count(*) as dob_count
  from get_bdays
  group by client_nbr, dob;

-- get most common birthday (or most recent in case of a tie) 
drop table if exists dev.poem_dob ;

create table dev.poem_dob as 
with get_row_number as 
(
select * , 
       row_number() over (partition by client_nbr order by dob_count desc, dob desc) as rn
  from dev.poem_temp_bday 
)
select client_nbr, dob 
  from get_row_number where rn = 1;
 
drop table if exists dev.poem_temp_bday ;


-------------------
--- Exclude on Age
--- (This also implicitly conditions on enrollment AT ANY TIME)
-------------------
vacuum analyze dev.poem_all_dx;
  
select * from  dev.poem_all_dx order by client_nbr , clm_to_date  ;

---- deliveries
drop table if exists dev.poem_all_dx_age;

create table dev.poem_all_dx_age as 
select distinct a.* , b.dob, 
       extract(year from age(a.clm_from_date, b.dob)) as age,
       extract(year from a.clm_from_date) as year_from,
       extract(year from a.clm_to_date) as year_to
  from dev.poem_all_dx a 
  join dev.poem_dob b 
    on a.client_nbr = b.client_nbr
   and extract(year from age(a.clm_from_date, b.dob)) between 15 and 55
   ;
  
  ----------------------------
  --- Exclude on TX 
  --- (This implicitly filters on enrollment MONTH OF CLAIM)
  ----------------------------
  
 /*
Zip Code Problems
There are some people with non-TX Zip codes 
We want to filter them out
*/ 

drop table if exists dev.poem_temp_zips;

create table dev.poem_temp_zips as 
select distinct * from (
select client_nbr , to_date(elig_date, 'YYYYMM') as elig_month, substring(zip,1,5) as zip
  from medicaid.enrl
 union all
select client_nbr , to_date(elig_month, 'YYYYMM'), substring(mailing_zip,1,5)
  from medicaid.chip_enrl 
  ) a
 where extract(year from elig_month) > 2018;
 
 --- filter to just TEXAS
drop table if exists dev.poem_temp_zips_tx;

create table dev.poem_temp_zips_tx as 
 select distinct a.*
   from dev.poem_temp_zips a 
   join crosswalk.zip_cd b 
   on a.zip = b.zip 
   and b.usps_zip_pref_state = 'TX'
   ;
   
  drop table if exists dev.poem_temp_zips;
  

 --- Filter Table for TX Zips
drop table if exists dev.poem_all_dx_age_tx;
 
 create table dev.poem_all_dx_age_tx as 
 select distinct a.*
   from dev.poem_all_dx_age a 
   join dev.poem_temp_zips_tx b 
     on a.client_nbr = b.client_nbr
    and to_char(clm_from_date, 'YYYYMM') = to_char(elig_month, 'YYYYMM');
   
   


/* ------------------------
 * Get info on "streaks"
 * Some people may have many months of claims in a row
 * (We're not sure why) that would result in some false positives
 * So for now get the streak info for filtering out
 */ ------------------------

drop table if exists dev.poem_all_dx_age_streaks;

create table dev.poem_all_dx_age_streaks as
with ranked_records as (
    select
        client_nbr,
        outcome_type,
        date_trunc('month', clm_from_date) as record_month,
        extract(year from date_trunc('month', clm_from_date)) as year,
        extract(month from date_trunc('month', clm_from_date)) as month,
        rank() over (partition by client_nbr, outcome_type order by date_trunc('month', clm_from_date)) as rank
    from
        dev.poem_all_dx_age_tx
    group by
        client_nbr, outcome_type, date_trunc('month', clm_from_date)
),
streaks as (
    select
        client_nbr,
        outcome_type,
        record_month,
        rank - (year * 12 + month) as streak_id
    from
        ranked_records
),
consecutive_streaks as (
    select
        client_nbr,
        outcome_type,
        streak_id,
        min(record_month) as start_month,
        max(record_month) as end_month,
        count(*) as streak_length
    from
        streaks
    group by
        client_nbr, outcome_type, streak_id
)
select
    p.*,
    cs.streak_id,
    cs.start_month::date,
    cs.end_month::date,
    cs.streak_length
from
    dev.poem_all_dx_age_tx p
join streaks s
    on p.client_nbr = s.client_nbr
    and p.outcome_type = s.outcome_type
    and date_trunc('month', p.clm_from_date) = s.record_month
left join consecutive_streaks cs
    on s.client_nbr = cs.client_nbr
    and s.outcome_type = cs.outcome_type
    and s.streak_id = cs.streak_id;

vacuum analyze dev.poem_all_dx_age_streaks;


/*
 * Streak Info 
 * 
 * 
 
select *
from dev.poem_all_dx_age_streaks
where streak_length >= 6 and outcome_type = 'LB'
order by client_nbr, clm_to_date;


select *
from dev.poem_all_dx_age_streaks
where streak_length = 8 and outcome_type = 'SB'
order by client_nbr, clm_to_date;
  

select streak_length, count(distinct  client_nbr || streak_id::text ) episodes 
   from dev.poem_all_dx_age_streaks 
  group by streak_length order by episodes desc;
  
  select outcome_type, streak_length, count(distinct streak_id::text || client_nbr) episodes 
   from dev.poem_all_dx_age_streaks 
  group by 1, 2 order by 1, 2;
 
 */

 /*
|streak_length|count  |
|-------------|-------|
1	749416
2	22659
3	244
4	36
5	22
6	11
8	10
7	3
9	1
  */
 
-----------------------------------------------------
 /*
  * checking for conflicting records on same to_date
  */
----------------------------------------------------

/*
select *
from dev.poem_all_dx_age_streaks a 
join dev.poem_all_dx_age_streaks b 
 on a.client_nbr = b.client_nbr 
and a.clm_to_date = b.clm_to_date
and a.outcome_type = 'LB' and b.outcome_type = 'SB';
*/
 
 --- put into a quarantine table
 drop table if exists dev.poem_all_dx_age_streaks_contradictions;
 
select * 
 into dev.poem_all_dx_age_streaks_contradictions
 from dev.poem_all_dx_age_streaks a
where exists (
    select 1
    from dev.poem_all_dx_age_streaks b
    where a.client_nbr = b.client_nbr
    and a.clm_to_date = b.clm_to_date
    and a.outcome_type <> b.outcome_type 
)
order by a.client_nbr;


--- delete from main records 
delete from dev.poem_all_dx_age_streaks a
where exists (
    select 1
    from dev.poem_all_dx_age_streaks b
    where a.client_nbr = b.client_nbr
    and a.clm_to_date = b.clm_to_date
    and a.outcome_type <> b.outcome_type 
);

vacuum analyze dev.poem_all_dx_age_streaks;

/*
---- check how many episodes are eliminated by excluding contraditions

select count(distinct streak_id::text || client_nbr) episodes 
  from dev.poem_all_dx_age_streaks_contradictions ;
--4072

select count(distinct streak_id::text || client_nbr) episodes 
  from dev.poem_all_dx_age_streaks_contradictions 
  where streak_id::text || client_nbr 
    not in (select distinct streak_id::text || client_nbr from dev.poem_all_dx_age_streaks) ;
--1102
*/


-----------------------------------------------------------------------------------------------
--- Quarantine Bundled Claims
--- After inspecting these claims individually, it looks like most of them are single prenancies 
--- They would be falsely flagged as multiple pregnancies, therefore setting aside for now
----------------------------------------------------------------------------------------------
 
   --- quarantine possible bundle payment claims 
drop table if exists dev.poem_all_dx_age_streaks_quarantine ;   
   
select * 
  into dev.poem_all_dx_age_streaks_quarantine 
  from dev.poem_all_dx_age_streaks 
 where streak_length >= 6;

---- create raw table for episodes 
---- This excludes the longer streaks 
drop table if exists dev.poem_episodes_raw;

create table dev.poem_episodes_raw as 
select distinct * 
  from dev.poem_all_dx_age_streaks 
 where streak_length < 6;

/*
 * Create the episodes 
 */

-- Build the empty table 
drop table if exists dev.poem_episodes_build;

create table dev.poem_episodes_build as 
 select *, row_number() over(partition by client_nbr order by clm_to_date) as rn
   from dev.poem_episodes_raw 
  limit 0;
 
 
select * from dev.poem_episodes_build;

-- Fill with LB first 
-- There 
do $$
declare
    i integer;
begin
    for i in 1..7 loop
        -- Your SQL code goes here
        with get_all as (
            select
                a.*,
                row_number() over (partition by a.client_nbr order by a.clm_to_date) as rn
            from dev.poem_episodes_raw a
            left join dev.poem_episodes_build b
              on a.client_nbr = b.client_nbr
             and a.clm_to_date - b.clm_to_date <= 182
            where a.outcome_type = 'LB'
              and b.client_nbr is null
        )
        insert into dev.poem_episodes_build
        select *
        from get_all
        where rn = 1
        order by client_nbr, clm_to_date;

    end loop;
end $$;


vacuum analyze dev.poem_episodes_build;

-- Insert "SB" episodes
do $$
declare
    i integer;
begin
    for i in 1..7 loop
        with sb_candidates as (
            select
                a.*,
                row_number() over (partition by a.client_nbr order by a.clm_to_date) as rn
            from dev.poem_episodes_raw a
            left join dev.poem_episodes_build b
              on a.client_nbr = b.client_nbr
             and (b.outcome_type = 'LB' and a.clm_to_date - b.clm_to_date <= 182
                  or b.outcome_type = 'SB' and b.clm_to_date - a.clm_to_date <= 168)
            where a.outcome_type = 'SB'
              and b.client_nbr is null
        )
        insert into dev.poem_episodes_build
        select *
        from sb_candidates
        where rn = 1
        order by client_nbr, clm_to_date;
    end loop;
end $$;
  
vacuum analyze dev.poem_episodes_build;