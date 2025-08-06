----------------------------------------
--- get all dx 
----------------------------------------

-- clm first 
drop table if exists chcdwork.dbo.poem_all_dx;

with get_dx as (
    select
        trim(b.icn) as icn,
        trim(b.pcn) as pcn,
        case when d.adm_dt = '' then null else cast(d.adm_dt as date) end as admit_date,
        case when d.dis_dt = '' or d.dis_dt = '0001-01-01' then null else cast(d.dis_dt as date) end as discharge_date,
        cast(d.hdr_frm_dos as date) as hdr_frm_dos,
        cast(d.hdr_to_dos as date) as hdr_to_dos,
        dx_cd
    from chcdwork.dbo.clm_dx a
    join chcdwork.dbo.clm_proc b on b.icn = a.icn
    join chcdwork.dbo.clm_header d on d.icn = b.icn
    cross apply (
        values
            (rtrim(a.prim_dx_cd)), (rtrim(a.dx_cd_1)), (rtrim(a.dx_cd_2)),  (rtrim(a.dx_cd_3)),
            (rtrim(a.dx_cd_4)), (rtrim(a.dx_cd_5)), (rtrim(a.dx_cd_6)), (rtrim(a.dx_cd_7)),
            (rtrim(a.dx_cd_8)), (rtrim(a.dx_cd_9)), (rtrim(a.dx_cd_10)), (rtrim(a.dx_cd_11)),
            (rtrim(a.dx_cd_12)),  (rtrim(a.dx_cd_13)), (rtrim(a.dx_cd_14)), (rtrim(a.dx_cd_15)),
            (rtrim(a.dx_cd_16)), (rtrim(a.dx_cd_17)),(rtrim(a.dx_cd_18)), (rtrim(a.dx_cd_19)),
            (rtrim(a.dx_cd_20)), (rtrim(a.dx_cd_21)), (rtrim(a.dx_cd_22)), (rtrim(a.dx_cd_23)),
            (rtrim(a.dx_cd_24)), (rtrim(a.dx_cd_25))
    ) as unnested(dx_cd)
    where year(cast(d.hdr_frm_dos as date)) > 2018
)
select distinct
	    a.icn as clm_id,
	    a.pcn as client_nbr,
	    a.admit_date,
	    a.discharge_date,
	    a.hdr_frm_dos as clm_from_date,
	    a.hdr_to_dos as clm_to_date,
	    'clm_dx' as src_table,
	    b.*
into chcdwork.dbo.poem_all_dx
from get_dx a
join chcdwork.dbo.poem_codeset_births b 
  on a.dx_cd = b.cd;
  
-- then encounters 
 with get_dx as (
    select
        trim(b.mem_id) as mem_id,
        trim(b.derv_enc) as derv_enc,
        case when d.adm_dt = '0001-01-01' then null else d.adm_dt end as admit_date,
        case when d.dis_dt = '0001-01-01' then null else d.dis_dt end as discharge_date,
        cast(d.frm_dos as date) as frm_dos,
        cast(d.to_dos as date) as to_dos,
        dx_cd
    from chcdwork.dbo.enc_dx a
    join chcdwork.dbo.enc_proc b on rtrim(b.derv_enc) = rtrim(a.derv_enc)
    join chcdwork.dbo.enc_header d on d.derv_enc = b.derv_enc
    cross apply (
        values
            (rtrim(a.prim_dx_cd)),(rtrim(a.dx_cd_1)),(rtrim(a.dx_cd_2)),(rtrim(a.dx_cd_3)),
            (rtrim(a.dx_cd_4)), (rtrim(a.dx_cd_5)),(rtrim(a.dx_cd_6)), (rtrim(a.dx_cd_7)),
            (rtrim(a.dx_cd_8)), (rtrim(a.dx_cd_9)), (rtrim(a.dx_cd_10)), (rtrim(a.dx_cd_11)),
            (rtrim(a.dx_cd_12)), (rtrim(a.dx_cd_13)),  (rtrim(a.dx_cd_14)), (rtrim(a.dx_cd_15)),
            (rtrim(a.dx_cd_16)), (rtrim(a.dx_cd_17)), (rtrim(a.dx_cd_18)), (rtrim(a.dx_cd_19)),
            (rtrim(a.dx_cd_20)),(rtrim(a.dx_cd_21)), (rtrim(a.dx_cd_22)), (rtrim(a.dx_cd_23)),
            (rtrim(a.dx_cd_24))
    ) as unnested(dx_cd)
    where year(cast(d.frm_dos as date)) > 2018
)
insert into chcdwork.dbo.poem_all_dx
select distinct
	    a.derv_enc as clm_id,
	    a.mem_id as client_nbr,
	    a.admit_date,
	    a.discharge_date,
	    a.frm_dos as clm_from_date,
	    a.to_dos as clm_to_date,
	    'enc_dx' as src_table,
	    b.*
from get_dx a
join chcdwork.dbo.poem_codeset_births b
  on a.dx_cd = b.cd;
 
 
update statistics chcdwork.dbo.poem_all_dx;
select * from chcdwork.dbo.poem_all_dx ;


/* ------------------------
 * Get info on "streaks"
 * Some people may have many months of claims in a row
 * (We're not sure why) that would result in some false positives
 * So for now get the streak info for filtering out
 */ ------------------------

drop table if exists  chcdwork.dbo.poem_all_dx_streaks; 

-- Create a temporary table to hold the ranked records
with ranked_records as (
    select
        client_nbr,
        outcome_type,
        dateadd(month, datediff(month, 0, clm_to_date), 0) as record_month,
        year(dateadd(month, datediff(month, 0, clm_to_date), 0)) as year,
        month(dateadd(month, datediff(month, 0, clm_to_date), 0)) as month,
        rank() over (partition by client_nbr, outcome_type order by dateadd(month, datediff(month, 0, clm_to_date), 0)) as rank
    from chcdwork.dbo.poem_all_dx
    group by client_nbr, outcome_type, dateadd(month, datediff(month, 0, clm_to_date), 0)
),
streaks as (
    select
        client_nbr,
        outcome_type,
        record_month,
        rank - (year(record_month) * 12 + month(record_month)) as streak_id
    from ranked_records
),
consecutive_streaks as (
    select
        client_nbr,
        outcome_type,
        streak_id,
        min(record_month) as start_month,
        max(record_month) as end_month,
        count(*) as streak_length
    from streaks
    group by client_nbr, outcome_type, streak_id
)
-- select final results into the new table
select p.*,
       cs.streak_id,
       cast(cs.start_month as date) as start_month,
       cast(cs.end_month as date) as end_month,
       cs.streak_length
  into chcdwork.dbo.poem_all_dx_streaks
  from chcdwork.dbo.poem_all_dx p
  join streaks s
    on p.client_nbr = s.client_nbr
   and p.outcome_type = s.outcome_type
   and dateadd(month, datediff(month, 0, p.clm_to_date), 0) = s.record_month
  left join consecutive_streaks cs
    on s.client_nbr = cs.client_nbr
    and s.outcome_type = cs.outcome_type
    and s.streak_id = cs.streak_id;

  
  

  
  
  /*
 * Streak Info 

select *
from chcdwork.dbo.poem_all_dx_streaks
where streak_length >= 6 and outcome_type = 'LB'
and client_nbr <> '000000000'
order by client_nbr, clm_to_date;


select *
from chcdwork.dbo.poem_all_dx_streaks
where streak_length = 8 and outcome_type = 'SB'
order by client_nbr, clm_to_date;
  

select streak_length, count(distinct  concat(client_nbr , streak_id)) episodes 
   from chcdwork.dbo.poem_all_dx_streaks 
  group by streak_length order by episodes desc;
 
 */

  -----------------------------------------------------
 /*
  * checking for conflicting records on same to_date
  */
----------------------------------------------------

 --- put into a quarantine table
 drop table if exists chcdwork.dbo.poem_all_dx_streaks_contradictions;
 
select * 
 into chcdwork.dbo.poem_all_dx_streaks_contradictions
 from chcdwork.dbo.poem_all_dx_streaks a
where exists (
    select 1
    from chcdwork.dbo.poem_all_dx_streaks b
    where a.client_nbr = b.client_nbr
    and a.clm_to_date = b.clm_to_date
    and a.outcome_type <> b.outcome_type 
);

--- delete from main records 
delete a
from chcdwork.dbo.poem_all_dx_streaks a
where exists (
    select 1
    from chcdwork.dbo.poem_all_dx_streaks b
    where a.client_nbr = b.client_nbr
    and a.clm_to_date = b.clm_to_date
    and a.outcome_type <> b.outcome_type
);

update statistics chcdwork.dbo.poem_all_dx_streaks;

-----------------------------------------------------------------------------------------------
--- Quarantine Bundled Claims
--- After inspecting these claims individually, it looks like most of them are single prenancies 
--- They would be falsely flagged as multiple pregnancies, therefore setting aside for now
----------------------------------------------------------------------------------------------
 
   --- quarantine possible bundle payment claims 
drop table if exists chcdwork.dbo.poem_all_dx_streaks_quarantine ;   
   
select * 
  into chcdwork.dbo.poem_all_dx_streaks_quarantine 
  from chcdwork.dbo.poem_all_dx_streaks 
 where streak_length >= 6;

---- create raw table for episodes 
---- This excludes the longer streaks 
drop table if exists chcdwork.dbo.poem_episodes_raw;

select distinct * 
  into chcdwork.dbo.poem_episodes_raw
  from chcdwork.dbo.poem_all_dx_streaks 
 where streak_length < 6;


-----------------------------------------------------------------------------------------------
--- Create Episodes
----------------------------------------------------------------------------------------------
-- Build the empty table 
drop table if exists chcdwork.dbo.poem_episodes_build;

-- Create the new table with the same structure and an additional row number column
select top 0 *,
       row_number() over(partition by client_nbr order by clm_to_date) as rn
into chcdwork.dbo.poem_episodes_build
from chcdwork.dbo.poem_episodes_raw;

--- run LB first 
DECLARE @i INT = 1;

WHILE @i <= 7
BEGIN
    WITH get_all AS (
        SELECT
            a.*,
            ROW_NUMBER() OVER (PARTITION BY a.client_nbr ORDER BY a.clm_to_date) AS rn
        FROM chcdwork.dbo.poem_episodes_raw a
        LEFT JOIN chcdwork.dbo.poem_episodes_build b
            ON a.client_nbr = b.client_nbr
           AND DATEDIFF(DAY, b.clm_to_date, a.clm_to_date) <= 182
        WHERE a.outcome_type = 'LB'
          AND b.client_nbr IS NULL
    )
    INSERT INTO chcdwork.dbo.poem_episodes_build
    SELECT *
    FROM get_all
    WHERE rn = 1
    ORDER BY client_nbr, clm_to_date;

    SET @i = @i + 1;
END;

SET @i = 1;

WHILE @i <= 7
BEGIN
    WITH sb_candidates AS (
        SELECT
            a.*,
            ROW_NUMBER() OVER (PARTITION BY a.client_nbr ORDER BY a.clm_to_date) AS rn
        FROM chcdwork.dbo.poem_episodes_raw a
        LEFT JOIN chcdwork.dbo.poem_episodes_build b
            ON a.client_nbr = b.client_nbr
           AND (
                (b.outcome_type = 'LB' AND DATEDIFF(DAY, b.clm_to_date, a.clm_to_date) <= 182)
                OR (b.outcome_type = 'SB' AND DATEDIFF(DAY, a.clm_to_date, b.clm_to_date) <= 168)
               )
        WHERE a.outcome_type = 'SB'
          AND b.client_nbr IS NULL
    )
    INSERT INTO chcdwork.dbo.poem_episodes_build
    SELECT *
    FROM sb_candidates
    WHERE rn = 1
    ORDER BY client_nbr, clm_to_date;

    SET @i = @i + 1;
END;



----------------------------------------------
-- Exclude on Age
----------------------------------------------


-- First get age
drop table if exists chcdwork.dbo.poem_temp_bday;

-- include chip
with get_bdays as (
    select client_nbr, dob
    from CHCDWORK.dbo.enrl
    union all
    select client_nbr, convert(date, left(date_of_birth, 9))
    from CHCDWORK.dbo.chip_enrl
) 
select client_nbr, dob, count(*) as dob_count
into chcdwork.dbo.poem_temp_bday
from get_bdays
group by client_nbr, dob;


-- Get most common birthday (or most recent in case of a tie)
drop table if exists chcdwork.dbo.poem_dob;

with get_row_number as (
    select *,
           row_number() over (partition by client_nbr order by dob_count desc, dob desc) as rn
    from chcdwork.dbo.poem_temp_bday
)
select client_nbr, dob
into chcdwork.dbo.poem_dob
from get_row_number
where rn = 1;

-- Drop the temporary birthday table
drop table if exists chcdwork.dbo.poem_temp_bday;

--------------------
-- Get Zips
--------------------

-- enrollment first (can use for zips after )
-- get enrl before chip_enrl
drop table if exists chcdwork.dbo.poem_demographics;

-- Create the new table with combined results
SELECT DISTINCT
       client_nbr,
       race AS race,
       me_code,
       'enrl' AS src_table,
       CAST(SUBSTRING(elig_date, 1, 6) + '01' AS DATE) AS elig_month,
       LEFT(zip, 5) AS zip,
       CAST(SUBSTRING(elig_date, 1, 4) AS FLOAT) AS elig_year  -- Extract year directly
INTO chcdwork.dbo.poem_demographics
FROM chcdwork.dbo.enrl
WHERE CAST(SUBSTRING(elig_date, 1, 4) AS INT) > 2018
UNION ALL
SELECT DISTINCT
       chip.client_nbr,
       ethnicity,
       NULL AS me_code,
       'chip_enrl' AS src_table,
       CAST(SUBSTRING(chip.elig_month, 1, 6) + '01' AS DATE) AS elig_month,
       LEFT(chip.mailing_zip, 5) AS zip,
       CAST(SUBSTRING(chip.elig_month, 1, 4) AS FLOAT) AS elig_year  -- Extract year directly
FROM chcdwork.dbo.chip_enrl chip
LEFT JOIN chcdwork.dbo.enrl enrl
  ON chip.client_nbr = enrl.client_nbr
 AND CAST(SUBSTRING(chip.elig_month, 1, 6) + '01' AS DATE) = CAST(SUBSTRING(enrl.elig_date, 1, 6) + '01' AS DATE)
WHERE enrl.client_nbr IS NULL
  AND CAST(SUBSTRING(chip.elig_month, 1, 4) AS INT) > 2018;
 

-----------------------------------
--- Add Enrollment info to Episodes
-----------------------------------


-- deliveries
-- add info about location 
drop table if exists chcdwork.dbo.poem_episodes_enrollment;

select distinct a.* , b.dob, 
       datediff(year, b.dob, a.clm_from_date) as age,
       c.race as race_cd,
       c.me_code,
       c.src_table as enrollment_table,
       c.zip,
       c.elig_year,
       zip.state,
       year(clm_to_date) as year,
       ROW_NUMBER() over (PARTITION by a.client_nbr order by clm_to_date ) as ep_num,
       a.client_nbr + '-' + cast(ROW_NUMBER() over (PARTITION by a.client_nbr order by clm_to_date ) as varchar) as ep_id
  into chcdwork.dbo.poem_episodes_enrollment
  from chcdwork.dbo.poem_episodes_build a 
  inner join chcdwork.dbo.poem_dob b
    on a.client_nbr = b.client_nbr
  left join chcdwork.dbo.poem_demographics c
    on a.client_nbr = c.client_nbr
   and a.start_month = c.elig_month
  left join [REF].dbo.zip_zcta_all_years zip
   on c.zip = zip.zip 
  and c.elig_year = zip.year
  ;
 

   
--- check episode code 
-- should be equal
select count( distinct trim(client_nbr) +  cast(streak_id as varchar)) 
  from chcdwork.dbo.poem_episodes_enrollment
  union all
  select count(*) from chcdwork.dbo.poem_episodes_enrollment;
 
 --- check those with multiples
 with mult_ep as(
  select client_nbr
   from chcdwork.dbo.poem_episodes_enrollment
  group by client_nbr
    having count(*) > 5
   )
  select * 
    from chcdwork.dbo.poem_episodes_enrollment a 
    join mult_ep b 
      on a.client_nbr = b.client_nbr 
   order by a.client_nbr, clm_to_date;
 
 


