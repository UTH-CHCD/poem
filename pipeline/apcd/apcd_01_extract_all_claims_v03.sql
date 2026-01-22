DROP TABLE IF EXISTS research_dev.poem_all_dx;

CREATE TABLE research_dev.poem_all_dx AS
SELECT DISTINCT
    a.apcd_id         ,
    a.derv_pccn, 
    'med_dx'                 AS src_table,
    b.*,
    c.admit_dt , c.discharge_dt , 
    c.dos_from , c.dos_thru ,
    c.bill 
FROM research_di.med_dx a
JOIN research_dev.poem_codeset_births b
  ON a.dx = b.cd
  left outer join research_di.medical_adj c
   on a.apcd_id = c.apcd_id 
  and a.derv_pccn = c.derv_pccn
WHERE EXTRACT(YEAR FROM a.dos) > 2018
  and a.payor_code = 20000238
;


-----------------
-- Simplfiy (take facility claims first!)
-----------------

drop table if exists research_dev.poem_all_dx_simplify;

create table research_dev.poem_all_dx_simplify as 
with hosp_births as (
  select distinct apcd_id, outcome_type, 
         admit_dt as dos_from, discharge_dt as dos_thru 
  from research_dev.poem_all_dx 
  where bill is not null
  and admit_dt is not null and discharge_dt is not null
),
other_births as (
  select distinct apcd_id, outcome_type, 
         dos_from, dos_thru 
  from research_dev.poem_all_dx 
  where bill is null
)
select * , 'F' as claim_type from hosp_births
	union all
select o.* , 'P'
from other_births o
where not exists (
  select 1 
  from hosp_births h
  where h.apcd_id = o.apcd_id
    and h.outcome_type = o.outcome_type
    and h.dos_from <= o.dos_thru 
    and h.dos_thru >= o.dos_from
);


 /* --------------------------------------
  * Quarantine contradiction records 
  * Get rid of records that contradict eachother (different outcome same claim date)
  */ -------------------------------------
  
--- put into a quarantine table
drop table if exists research_dev.poem_all_dx_simplify_contradictions;

create table research_dev.poem_all_dx_simplify_contradictions as
select *
from research_dev.poem_all_dx_simplify a
where exists (
    select 1
    from research_dev.poem_all_dx_simplify b
    where a.apcd_id = b.apcd_id
    and (a.dos_thru = b.dos_thru or a.dos_from = b.dos_from)
    and a.outcome_type <> b.outcome_type 
);

--- delete from main records 
delete from research_dev.poem_all_dx_simplify a
where exists (
    select 1
    from research_dev.poem_all_dx_simplify b
    where a.apcd_id = b.apcd_id
    and (a.dos_thru = b.dos_thru or a.dos_from = b.dos_from)
    and a.outcome_type <> b.outcome_type 
);


/*
 * Collapse overlapping 
 */
DROP TABLE IF EXISTS research_dev.poem_all_dx_episodes;

CREATE TABLE research_dev.poem_all_dx_episodes AS
WITH EpisodeData AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY apcd_id ORDER BY dos_from, dos_thru) AS rn
    FROM
        research_dev.poem_all_dx_simplify
),
LagData AS (
    SELECT
        *,
        LAG(dos_from) OVER (PARTITION BY apcd_id ORDER BY rn) AS prev_start_date,
        LAG(dos_thru) OVER (PARTITION BY apcd_id ORDER BY rn) AS prev_end_date,
        MAX(dos_thru) OVER (PARTITION BY apcd_id ORDER BY rn ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS max_end_date_before_current
    FROM
        EpisodeData
),
EpisodeFlagData AS (
    SELECT
        *,
        CASE
            WHEN prev_start_date IS NULL THEN 1  -- Start a new episode if it's the first record for this client
            WHEN dos_from > COALESCE(max_end_date_before_current, '1900-01-01'::date) THEN 1  -- Start a new episode if the current dos_from is after the max_end_date_before_current
            ELSE 0  -- Continue the current episode if there's an overlap
        END AS NewEpisodeFlag
    FROM
        LagData
),
FinalGrouped AS (
    SELECT
        *,
        SUM(NewEpisodeFlag) OVER (PARTITION BY apcd_id ORDER BY rn ROWS UNBOUNDED PRECEDING) AS EpisodeGroup
    FROM
        EpisodeFlagData
),
RankedEpisodes AS (
    SELECT
        *,
        DENSE_RANK() OVER (PARTITION BY apcd_id ORDER BY EpisodeGroup) AS episode_id
    FROM
        FinalGrouped
)
SELECT
    *
FROM
    RankedEpisodes
ORDER BY
    apcd_id, episode_id, dos_from;
    
   
   
-- aggregate beginning and ending dates 
drop table if exists research_dev.poem_all_dx_episodes_start_end;

create table research_dev.poem_all_dx_episodes_start_end as
select a.apcd_id, a.episode_id, 
       min(dos_from) as start_date, 
       max(dos_thru) as end_date, 
       max(claim_type) as claim_type,
       max(outcome_type) as outcome_type,
       case when count(distinct a.outcome_type) > 1 then 1 else 0 end as lb_sb_mix
  from research_dev.poem_all_dx_episodes a 
 group by a.apcd_id, a.episode_id;
   

-- Clean up P claims where F exists nearby 
delete from research_dev.poem_all_dx_episodes_start_end
where claim_type = 'P'
and exists (
    select 1
    from research_dev.poem_all_dx_episodes_start_end f
    where f.apcd_id = poem_all_dx_episodes_start_end.apcd_id
    and f.claim_type = 'F'
    and f.outcome_type = poem_all_dx_episodes_start_end.outcome_type
    and abs(f.start_date - poem_all_dx_episodes_start_end.start_date) <= 30
);

-- vacuum
vacuum full research_dev.poem_all_dx_episodes_start_end;


/* ------------------------
 * Get info on "streaks"
 * Some people may have many months of claims in a row
 * (We're not sure why) that would result in some false positives
 * So for now get the streak info for filtering out
 */ ------------------------
drop table if exists research_dev.poem_all_dx_streaks;

-- Create a temporary table to hold the ranked records
create table research_dev.poem_all_dx_streaks as
with ranked_records as (
    select
        apcd_id,
        date_trunc('month', start_date)::date as record_month,
        extract(year from date_trunc('month', start_date)) as year,
        extract(month from date_trunc('month', start_date)) as month,
        rank() over (partition by apcd_id order by date_trunc('month', start_date)) as rank
    from research_dev.poem_all_dx_episodes_start_end
    group by apcd_id, date_trunc('month', start_date)
),
streaks as (
    select
        apcd_id,
        record_month,
        rank - (extract(year from record_month) * 12 + extract(month from record_month)) as streak_id
    from ranked_records
),
consecutive_streaks as (
    select
        apcd_id,
        streak_id,
        min(record_month) as start_month,
        max(record_month) as end_month,
        count(*) as streak_length
    from streaks
    group by apcd_id, streak_id
)
-- select final results into the new table
select p.*,
       cs.streak_id,
       cs.start_month::date as start_month,
       cs.end_month::date as end_month,
       cs.streak_length
  from research_dev.poem_all_dx_episodes_start_end p
  join streaks s
    on p.apcd_id = s.apcd_id
   and date_trunc('month', p.start_date)::date = s.record_month
  left join consecutive_streaks cs
    on s.apcd_id = cs.apcd_id
    and s.streak_id = cs.streak_id;
    
--- get those with 6 or more in a streak 
--- these are mystery claims that might be wrongly flagged 
drop table if exists research_dev.poem_all_dx_streaks_delete;
   
create table research_dev.poem_all_dx_streaks_delete as
select distinct apcd_id, episode_id
from research_dev.poem_all_dx_streaks 
where streak_length >= 6;


-----------------------------------------------------------------------------------------------
--- Quarantine Streak Claims
--- After inspecting these claims individually, it looks like most of them are single prenancies 
--- They would be falsely flagged as multiple pregnancies, therefore setting aside for now
----------------------------------------------------------------------------------------------
 
drop table if exists research_dev.poem_all_dx_episodes_quarantine_streaks;

create table research_dev.poem_all_dx_episodes_quarantine_streaks as
select a.* 
  from research_dev.poem_all_dx_episodes_start_end a 
  join research_dev.poem_all_dx_streaks_delete b 
    on a.apcd_id = b.apcd_id
   and a.episode_id = b.episode_id;
 
--- delete the records from the episodes 
delete from research_dev.poem_all_dx_episodes_start_end a 
using research_dev.poem_all_dx_streaks_delete b 
where a.apcd_id = b.apcd_id
  and a.episode_id = b.episode_id;
  
 
-----------------------------------------------------------------------------------------------
--- Create Episodes
----------------------------------------------------------------------------------------------
-- Build the empty table 
drop table if exists research_dev.poem_episodes_build;

-- Create the new table with the same structure and an additional row number column
create table research_dev.poem_episodes_build as
select *,
       row_number() over(partition by apcd_id order by episode_id) as rn
from research_dev.poem_all_dx_episodes_start_end
where 1=0;  -- equivalent to top 0

--- run LB first 
DO $$
DECLARE
    i INT := 1;
BEGIN
    WHILE i <= 7 LOOP
        WITH get_all AS (
            SELECT
                a.*,
                ROW_NUMBER() OVER (PARTITION BY a.apcd_id ORDER BY a.episode_id) AS rn
            FROM research_dev.poem_all_dx_episodes_start_end a
            LEFT JOIN research_dev.poem_episodes_build b
                ON a.apcd_id = b.apcd_id
               AND (a.start_date - b.start_date) <= 182
            WHERE a.outcome_type = 'LB'
              AND b.apcd_id IS NULL
        )
        INSERT INTO research_dev.poem_episodes_build
        SELECT *
        FROM get_all
        WHERE rn = 1;
        
        i := i + 1;
    END LOOP;
END $$;

DO $$
DECLARE
    i INT := 1;
BEGIN
    WHILE i <= 7 LOOP
        WITH sb_candidates AS (
            SELECT
                a.*,
                ROW_NUMBER() OVER (PARTITION BY a.apcd_id ORDER BY a.episode_id) AS rn
            FROM research_dev.poem_all_dx_episodes_start_end a
            LEFT JOIN research_dev.poem_episodes_build b
                ON a.apcd_id = b.apcd_id
               AND (
                    (b.outcome_type = 'LB' AND (a.start_date - b.start_date) <= 182)
                    OR (b.outcome_type = 'SB' AND (b.start_date - a.start_date) <= 168)
                   )
            WHERE a.outcome_type = 'SB'
              AND b.apcd_id IS NULL
        )
        INSERT INTO research_dev.poem_episodes_build
        SELECT *
        FROM sb_candidates
        WHERE rn = 1;
        
        i := i + 1;
    END LOOP;
END $$;


-----------------------------------
--- Add Enrollment info to Episodes
-----------------------------------
drop table if exists research_dev.poem_episodes_enrollment;

create table research_dev.poem_episodes_enrollment as 
select a.*, 
       b.yr, 
       b.age, 
       b.race_1, 
       b.hispanic_ind, 
       b.zip, 
       b.fips, 
       b.state, 
       b.prim_med_plan,
       b.prim_med_plan_design, 
       episode_id as ep_num,
       c.prim_med_plan as prim_med_plan_mon,
       c.prim_med_plan_design as prim_med_plan_design_mon,
       c.med_ind,
       case when c.prim_med_plan = 'Medicaid' then 1 else 0 end as enrolled_birth,
       end_date - start_date + 1 as los
  from research_dev.poem_episodes_build a 
  join research_di.agg_yr_plan b 
    on a.apcd_id = b.apcd_id 
   and extract(year from a.start_date) = b.yr
  left outer join research_di.agg_yrmon_plan c
    on a.apcd_id = c.apcd_id
   and to_char(a.start_date, 'YYYYMM')::int8 = c.yrmon
   and c.prim_med_plan = 'Medicaid'
  order by 1,2;
  

 -- Check distinctness
 select count(*) from research_dev.poem_episodes_enrollment
 union all
 select count(distinct apcd_id::text || episode_id::text) from research_dev.poem_episodes_enrollment;

table research_dev.poem_episodes_enrollment;
/*
 * Get Midpoints
 */
drop table if exists research_dev.poem_episodes_anchordates; 

create table research_dev.poem_episodes_anchordates as
SELECT apcd_id,
    episode_id as ep_num,
    start_date,
    end_date,
    (end_date - start_date) + 1 as total_days,
    CASE 
        WHEN ((end_date - start_date) + 1) % 2 = 0 
        THEN ABS(hashtext(apcd_id::text)) % 2 
        ELSE 0 
    END as tie_breaker,
    FLOOR((end_date - start_date) / 2.0)
        + CASE 
            WHEN ((end_date - start_date) + 1) % 2 = 0 
            THEN ABS(hashtext(apcd_id::text)) % 2 
            ELSE 0 
          END as midpoint_offset,
    start_date + (FLOOR((end_date - start_date) / 2.0)
        + CASE 
            WHEN ((end_date - start_date) + 1) % 2 = 0 
            THEN ABS(hashtext(apcd_id::text)) % 2 
            ELSE 0 
          END)::integer as midpoint_date
FROM research_dev.poem_episodes_enrollment;

select * from research_dev.poem_episodes_anchordates;

/*
 * Make final cohort 
 */
drop table if exists research_dev.poem_cohort;

create table research_dev.poem_cohort as
select a.*, 
       b.midpoint_date as anchor_date, 
       extract(year from b.midpoint_date) as anchor_year
from research_dev.poem_episodes_enrollment a 
join research_dev.poem_episodes_anchordates b 
  on a.apcd_id = b.apcd_id
 and a.ep_num = b.ep_num;
 




/*
 * Create smaller extract tables
 * We want to limit to the medicaid payor code
 */

--- Medical
drop table if exists research_dev.medical_adj_poem ;

create table research_dev.medical_adj_poem as 
select ma.*
  from research_dev.poem_cohort a 
  join research_di.medical_adj ma 
    on a.apcd_id = ma.apcd_id
   and ma.payor_code = 20000238;
 
analyze research_dev.medical_adj_poem;
  
 --- Pharmacy
drop table if exists research_dev.pharmacy_adj_poem ;

create table research_dev.pharmacy_adj_poem as 
select ma.*
  from research_dev.poem_cohort a 
  join research_di.pharmacy_adj ma 
    on a.apcd_id = ma.apcd_id
   and ma.payor_code = 20000238;
  
analyze research_dev.pharmacy_adj_poem;
   
--- DX
drop table if exists research_dev.med_dx_poem ;  

create table research_dev.med_dx_poem as 
select ma.*
  from research_dev.poem_cohort a 
  join research_di.med_dx ma 
    on a.apcd_id = ma.apcd_id
   and ma.payor_code = 20000238;  
  
 analyze research_dev.med_dx_poem;

