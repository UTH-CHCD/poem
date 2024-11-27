----------------------------------------
--- get all dx 
----------------------------------------

-- clm first 
drop table if exists chcdwork.dbo.poem_all_dx;

with get_dx as (
    select
        trim(b.icn) as icn,
        trim(b.pcn) as pcn,
        cast(d.hdr_frm_dos as date) as hdr_frm_dos,
        cast(d.hdr_to_dos as date) as hdr_to_dos,
        case when d.pat_stat_cd = '' then null else d.pat_stat_cd end as pat_stat_cd,
        dx_cd,
        case when trim(b.bill) = '' then null else trim(b.bill) end as bill_type
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
	    a.hdr_frm_dos as clm_from_date,
	    a.hdr_to_dos as clm_to_date,
	    pat_stat_cd as pat_stat,
	    'clm_dx' as src_table,
	    bill_type,
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
        cast(d.frm_dos as date) as frm_dos,
        cast(d.to_dos as date) as to_dos,
        case when d.pat_stat = '' then null else d.pat_stat end as pat_stat,
        dx_cd,
        case when trim(b.bill) = '' then null else trim(b.bill) end as bill_type
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
	    a.frm_dos as clm_from_date,
	    a.to_dos as clm_to_date,
	    pat_stat as pat_stat,
	    'enc_dx' as src_table,
	    bill_type,
	    b.*
from get_dx a
join chcdwork.dbo.poem_codeset_births b
  on a.dx_cd = b.cd;
 
 
-----------------
-- Simplify 
-------------------
drop table if exists chcdwork.dbo.poem_all_dx_simplify; 

-- Insert just the claims with admit and discharge  
 select distinct *, 'F' as fac_prof
   into chcdwork.dbo.poem_all_dx_simplify
   from chcdwork.dbo.poem_all_dx 
  where bill_type is not null
  order by client_nbr;
 
 -- Insert professional claims that do not overlap with existing facility claims
insert into chcdwork.dbo.poem_all_dx_simplify
select distinct a.*, 'P' as fac_prof
from chcdwork.dbo.poem_all_dx a
left join chcdwork.dbo.poem_all_dx_simplify b 
on a.client_nbr = b.client_nbr
   and (
        (a.clm_from_date <= b.clm_to_date and a.clm_to_date >= b.clm_from_date)
       )
where b.client_nbr is null 
  and a.bill_type is null;
  

 /* --------------------------------------
  * Quarantine contradiction records 
  * Get rid of records that contradict eachother (different outcome same claim date)
  */ -------------------------------------
  
 --- put into a quarantine table
 drop table if exists chcdwork.dbo.poem_all_dx_simplify_contradictions;
 
select *
 into chcdwork.dbo.poem_all_dx_simplify_contradictions
 from chcdwork.dbo.poem_all_dx_simplify a
where exists (
    select 1
    from chcdwork.dbo.poem_all_dx_simplify b
    where a.client_nbr = b.client_nbr
    and (a.clm_to_date = b.clm_to_date or a.clm_from_date = b.clm_from_date)
    and a.outcome_type <> b.outcome_type 
);


--- delete from main records 
delete a
from chcdwork.dbo.poem_all_dx_simplify a
where exists (
    select 1
    from chcdwork.dbo.poem_all_dx_simplify b
    where a.client_nbr = b.client_nbr
    and (a.clm_to_date = b.clm_to_date or a.clm_from_date = b.clm_from_date)
    and a.outcome_type <> b.outcome_type 
);



/*
 * Collapse overlapping 
 */
DROP TABLE IF EXISTS CHCDWORK.dbo.poem_all_dx_episodes;

WITH EpisodeData AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY client_nbr ORDER BY clm_from_date, clm_to_date) AS rn
    FROM
        chcdwork.dbo.poem_all_dx_simplify
),
LagData AS (
    SELECT
        *,
        LAG(clm_from_date) OVER (PARTITION BY client_nbr ORDER BY rn) AS prev_start_date,
        LAG(clm_to_date) OVER (PARTITION BY client_nbr ORDER BY rn) AS prev_end_date,
        MAX(clm_to_date) OVER (PARTITION BY client_nbr ORDER BY rn ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS max_end_date_before_current
    FROM
        EpisodeData
),
EpisodeFlagData AS (
    SELECT
        *,
        CASE
            WHEN prev_start_date IS NULL THEN 1  -- Start a new episode if it's the first record for this client
            WHEN clm_from_date > ISNULL(max_end_date_before_current, '1900-01-01') THEN 1  -- Start a new episode if the current clm_from_date is after the max_end_date_before_current
            ELSE 0  -- Continue the current episode if there's an overlap
        END AS NewEpisodeFlag
    FROM
        LagData
),
FinalGrouped AS (
    SELECT
        *,
        SUM(NewEpisodeFlag) OVER (PARTITION BY client_nbr ORDER BY rn ROWS UNBOUNDED PRECEDING) AS EpisodeGroup
    FROM
        EpisodeFlagData
),
RankedEpisodes AS (
    SELECT
        *,
        DENSE_RANK() OVER (PARTITION BY client_nbr ORDER BY EpisodeGroup) AS episode_id
    FROM
        FinalGrouped
)
SELECT
    *
INTO CHCDWORK.dbo.poem_all_dx_episodes
FROM
    RankedEpisodes
ORDER BY
    client_nbr, episode_id, clm_from_date;


-- aggregate beginning and ending dates 
drop table if exists CHCDWORK.dbo.poem_all_dx_episodes_start_end;

select a.client_nbr, a.episode_id, 
       min(clm_from_date) as start_date, 
       max(clm_to_date) as end_date, 
       max(multiple_flag) as multiple_flag,
       max(pat_stat) as pat_stat,
       min(fac_prof) as fac_prof,
       max(a.outcome_type) as outcome_type,
       case when count(distinct a.outcome_type) > 1 THEN 1 else 0 end as lb_sb_mix
  into CHCDWORK.dbo.poem_all_dx_episodes_start_end
  from CHCDWORK.dbo.poem_all_dx_episodes a 
 group by a.client_nbr, a.episode_id;
   
select * from CHCDWORK.dbo.poem_all_dx_episodes_start_end;

/* ------------------------
 * Get info on "streaks"
 * Some people may have many months of claims in a row
 * (We're not sure why) that would result in some false positives
 * So for now get the streak info for filtering out
 */ ------------------------

drop table if exists chcdwork.dbo.poem_all_dx_streaks;

-- Create a temporary table to hold the ranked records
with ranked_records as (
    select
        client_nbr,
        dateadd(month, datediff(month, 0, start_date), 0) as record_month,
        year(dateadd(month, datediff(month, 0, start_date), 0)) as year,
        month(dateadd(month, datediff(month, 0, start_date), 0)) as month,
        rank() over (partition by client_nbr order by dateadd(month, datediff(month, 0, start_date), 0)) as rank
    from chcdwork.dbo.poem_all_dx_episodes_start_end
    group by client_nbr, dateadd(month, datediff(month, 0, start_date), 0)
),
streaks as (
    select
        client_nbr,
        record_month,
        rank - (year(record_month) * 12 + month(record_month)) as streak_id
    from ranked_records
),
consecutive_streaks as (
    select
        client_nbr,
        streak_id,
        min(record_month) as start_month,
        max(record_month) as end_month,
        count(*) as streak_length
    from streaks
    group by client_nbr, streak_id
)
-- select final results into the new table
select p.*,
       cs.streak_id,
       cast(cs.start_month as date) as start_month,
       cast(cs.end_month as date) as end_month,
       cs.streak_length
  into chcdwork.dbo.poem_all_dx_streaks
  from chcdwork.dbo.poem_all_dx_episodes_start_end p
  join streaks s
    on p.client_nbr = s.client_nbr
   and dateadd(month, datediff(month, 0, p.start_date), 0) = s.record_month
  left join consecutive_streaks cs
    on s.client_nbr = cs.client_nbr
    and s.streak_id = cs.streak_id;
    
  --- get those with 6 or more in a streak 
  --- these are mystery claims that might be wrongly flagged 
  drop table if exists chcdwork.dbo.poem_all_dx_streaks_delete;
   
 select distinct client_nbr, episode_id
     into chcdwork.dbo.poem_all_dx_streaks_delete
     from chcdwork.dbo.poem_all_dx_streaks where streak_length  >= 6;
    
-----------------------------------------------------------------------------------------------
--- Quarantine Streak Claims
--- After inspecting these claims individually, it looks like most of them are single prenancies 
--- They would be falsely flagged as multiple pregnancies, therefore setting aside for now
----------------------------------------------------------------------------------------------
 
drop table if exists CHCDWORK.dbo.poem_all_dx_episodes_quarantine_streaks;

select a.* 
  into CHCDWORK.dbo.poem_all_dx_episodes_quarantine_streaks
  from CHCDWORK.dbo.poem_all_dx_episodes_start_end a 
  join chcdwork.dbo.poem_all_dx_streaks_delete b 
   on a.client_nbr = b.client_nbr
  and a.episode_id = b.episode_id;
 
 --- delete the records from the episodes 
 delete a 
  from CHCDWORK.dbo.poem_all_dx_episodes_start_end a 
  inner join chcdwork.dbo.poem_all_dx_streaks_delete b 
   on a.client_nbr = b.client_nbr
  and a.episode_id = b.episode_id;
 
-----------------------------------------------------------------------------------------------
--- Create Episodes
----------------------------------------------------------------------------------------------
-- Build the empty table 
drop table if exists chcdwork.dbo.poem_episodes_build;

-- Create the new table with the same structure and an additional row number column
select top 0 *,
       row_number() over(partition by client_nbr order by episode_id) as rn
into chcdwork.dbo.poem_episodes_build
from chcdwork.dbo.poem_all_dx_episodes_start_end;

--- run LB first 
DECLARE @i INT = 1;

WHILE @i <= 7
BEGIN
    WITH get_all AS (
        SELECT
            a.*,
            ROW_NUMBER() OVER (PARTITION BY a.client_nbr ORDER BY a.episode_id) AS rn
        FROM chcdwork.dbo.poem_all_dx_episodes_start_end a
        LEFT JOIN chcdwork.dbo.poem_episodes_build b
            ON a.client_nbr = b.client_nbr
           AND DATEDIFF(DAY, b.start_date, a.start_date) <= 182
        WHERE a.outcome_type = 'LB'
          AND b.client_nbr IS NULL
    )
    INSERT INTO chcdwork.dbo.poem_episodes_build
    SELECT *
    FROM get_all
    WHERE rn = 1;

    SET @i = @i + 1;
END;

SET @i = 1;

WHILE @i <= 7
BEGIN
    WITH sb_candidates AS (
        SELECT
            a.*,
            ROW_NUMBER() OVER (PARTITION BY a.client_nbr ORDER BY a.episode_id) AS rn
        FROM chcdwork.dbo.poem_all_dx_episodes_start_end a
        LEFT JOIN chcdwork.dbo.poem_episodes_build b
            ON a.client_nbr = b.client_nbr
           AND (
                (b.outcome_type = 'LB' AND DATEDIFF(DAY, b.start_date, a.start_date) <= 182)
                OR (b.outcome_type = 'SB' AND DATEDIFF(DAY, a.start_date, b.start_date) <= 168)
               )
        WHERE a.outcome_type = 'SB'
          AND b.client_nbr IS NULL
    )
    INSERT INTO chcdwork.dbo.poem_episodes_build
    SELECT *
    FROM sb_candidates
    WHERE rn = 1 ;
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
       datediff(year, b.dob, a.start_date) as age,
       c.race as race_cd,
       c.me_code,
       c.src_table as enrollment_table,
       c.zip,
       c.elig_year,
       zip.state,
       year(start_date) as year,
       ROW_NUMBER() over (PARTITION by a.client_nbr order by start_date ) as ep_num,
       a.client_nbr + '-' + cast(ROW_NUMBER() over (PARTITION by a.client_nbr order by start_date ) as varchar) as ep_id,
       DATEDIFF(day, start_date, end_date)  + 1 as los ,
       case when c.client_nbr is null then 0 else 1 end as enrolled_birth
  into chcdwork.dbo.poem_episodes_enrollment
  from chcdwork.dbo.poem_episodes_build a 
  inner join chcdwork.dbo.poem_dob b
    on a.client_nbr = b.client_nbr
  left join chcdwork.dbo.poem_demographics c
    on a.client_nbr = c.client_nbr
   and DATEFROMPARTS(year(a.start_date), month(start_date),1) = c.elig_month
  left join [REF].dbo.zip_zcta_all_years zip
   on c.zip = zip.zip 
  and c.elig_year = zip.year
  ;
 
  
  
  select count(*) from chcdwork.dbo.poem_episodes_enrollment ;
   
--- check episode code 
-- should be equal
select count( distinct trim(client_nbr) +  cast(episode_id as varchar)) 
  from chcdwork.dbo.poem_episodes_enrollment
  union all
  select count(*) from chcdwork.dbo.poem_episodes_enrollment;
 

/*
 * Get Midpoints
 */

drop table if exists chcdwork.dbo.poem_episodes_anchordates; 
 
SELECT client_nbr,
    ep_num,
    start_date,
    end_date,
    -- Calculate the total number of days including both start and end dates
    total_days = DATEDIFF(day, start_date, end_date) + 1,
    -- Determine the tie breaker based on a pseudo-random but reproducible hash of client_nbr
    tie_breaker = CASE 
                    WHEN (DATEDIFF(day, start_date, end_date) + 1) % 2 = 0 
                    THEN ABS(CHECKSUM(client_nbr)) % 2 
                    ELSE 0 
                  END,
    -- Calculate the midpoint offset from the start_date
    midpoint_offset = FLOOR(DATEDIFF(day, start_date, end_date) / 2.0)
                      + CASE 
                          WHEN (DATEDIFF(day, start_date, end_date) + 1) % 2 = 0 
                          THEN ABS(CHECKSUM(client_nbr)) % 2 
                          ELSE 0 
                        END,
    midpoint_date = DATEADD(
        day,
        FLOOR(DATEDIFF(day, start_date, end_date) / 2.0)
        + CASE 
            WHEN (DATEDIFF(day, start_date, end_date) + 1) % 2 = 0 
            THEN ABS(CHECKSUM(client_nbr)) % 2 
            ELSE 0 
          END,
        start_date)
into chcdwork.dbo.poem_episodes_anchordates
FROM chcdwork.dbo.poem_episodes_enrollment ;

select * from chcdwork.dbo.poem_episodes_anchordates;
/*
 * Make final cohort 
 */


drop table if exists chcdwork.dbo.poem_cohort;

select a.* , b.midpoint_date as anchor_date, 
       year(b.midpoint_date ) as anchor_year
  into chcdwork.dbo.poem_cohort
  from chcdwork.dbo.poem_episodes_enrollment a 
  join chcdwork.dbo.poem_episodes_anchordates b 
  on a.client_nbr = b.client_nbr
  and a.ep_num = b.ep_num ; 
 
 --- 
 select count(*)
   from chcdwork.dbo.poem_cohort
 ;
 
 --986069
 
 select *
   from chcdwork.dbo.poem_cohort ;

  
  
  
/*  select a.*, b.out_enroll_90 , c.out_outpatient_contact , d.out_postpartum 
   from chcdwork.dbo.poem_cohort a 
   left join CHCDWORK.dbo.poem_outcomes_enrollment b 
     on a.client_nbr = b.client_nbr
    and a.ep_num = b.ep_num
   left join CHCDWORK.dbo.poem_outcomes_outpatient_contact c
     on a.client_nbr = c.client_nbr
    and a.ep_num = c.ep_num
   left join CHCDWORK.dbo.poem_outcomes_out_postpartum d
     on a.client_nbr = d.client_nbr
    and a.ep_num = d.ep_num ;
   */
  
  
  
  
  
  
  
  
  
  