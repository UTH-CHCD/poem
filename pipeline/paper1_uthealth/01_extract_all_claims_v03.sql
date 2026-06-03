-- ============================================================
-- Extract All Claims / Build Cohort
-- Converted from SQL Server to Greenplum/PostgreSQL
-- Schema: dev (replaces CHCDWORK.dbo)
-- Source tables: medicaid.* (pre-appended in Greenplum — no per-FY union needed)
--
-- Key conversion notes:
--   CROSS APPLY (VALUES ...) AS unnested(col)  →  CROSS JOIN LATERAL (VALUES ...) AS unnested(col)
--   ISNULL(x, y)             →  COALESCE(x, y)
--   YEAR(date)               →  EXTRACT(YEAR FROM date) or DATE_PART('year', date)
--   DATEADD(unit, n, date)   →  date + INTERVAL 'n unit'
--   DATEDIFF(unit, d1, d2)   →  various (see inline)
--   SELECT TOP 0 *           →  SELECT * ... LIMIT 0
--   DATEFROMPARTS(y,m,d)     →  MAKE_DATE(y,m,d)
--   CHECKSUM(col)             →  HASHTEXT(col)  [for tie-breaking only]
--   WHILE / DECLARE loops    →  DO $$ ... $$ PL/pgSQL blocks
--   CONVERT(date, ...)        →  CAST(... AS date)  /  TO_DATE(...)
--   SUBSTRING(s,1,n)          →  SUBSTRING(s FROM 1 FOR n)
--   DELETE alias FROM table   →  DELETE FROM table WHERE ...
--   ORDER BY inside SELECT INTO → removed (no ordering guarantee needed)
-- ============================================================

----------------------------------------
--- Get all DX (birth outcomes)
----------------------------------------

DROP TABLE IF EXISTS dev.poem_all_dx;

-- Claims
CREATE TABLE dev.poem_all_dx AS
WITH get_dx AS (
    SELECT
        trim(b.icn)                                                   AS icn,
        trim(b.pcn)                                                   AS pcn,
        cast(d.hdr_frm_dos AS date)                                   AS hdr_frm_dos,
        cast(d.hdr_to_dos  AS date)                                   AS hdr_to_dos,
        CASE WHEN d.pat_stat_cd = '' THEN NULL ELSE d.pat_stat_cd END AS pat_stat_cd,
        CASE WHEN trim(b.bill)   = '' THEN NULL ELSE trim(b.bill) END AS bill_type,
        unnest(array[
            rtrim(a.prim_dx_cd),
            rtrim(a.dx_cd_1),  rtrim(a.dx_cd_2),  rtrim(a.dx_cd_3),
            rtrim(a.dx_cd_4),  rtrim(a.dx_cd_5),  rtrim(a.dx_cd_6),
            rtrim(a.dx_cd_7),  rtrim(a.dx_cd_8),  rtrim(a.dx_cd_9),
            rtrim(a.dx_cd_10), rtrim(a.dx_cd_11), rtrim(a.dx_cd_12),
            rtrim(a.dx_cd_13), rtrim(a.dx_cd_14), rtrim(a.dx_cd_15),
            rtrim(a.dx_cd_16), rtrim(a.dx_cd_17), rtrim(a.dx_cd_18),
            rtrim(a.dx_cd_19), rtrim(a.dx_cd_20), rtrim(a.dx_cd_21),
            rtrim(a.dx_cd_22), rtrim(a.dx_cd_23), rtrim(a.dx_cd_24),
            rtrim(a.dx_cd_25)
        ]) AS dx_cd
    FROM medicaid.clm_dx a
    JOIN medicaid.clm_proc b   ON b.icn = a.icn
    JOIN medicaid.clm_header d ON d.icn = b.icn
    WHERE EXTRACT(YEAR FROM cast(d.hdr_frm_dos AS date)) > 2018
)
SELECT DISTINCT
    a.icn         AS clm_id,
    a.pcn         AS client_nbr,
    a.hdr_frm_dos AS clm_from_date,
    a.hdr_to_dos  AS clm_to_date,
    a.pat_stat_cd AS pat_stat,
    'clm_dx'      AS src_table,
    a.bill_type,
    b.*
FROM get_dx a
JOIN dev.poem_codeset_births b ON a.dx_cd = b.cd
WHERE a.dx_cd IS NOT NULL AND a.dx_cd <> '';


-- Encounters
INSERT INTO dev.poem_all_dx
WITH get_dx AS (
    SELECT
        trim(b.mem_id)                                                AS mem_id,
        trim(b.derv_enc)                                              AS derv_enc,
        d.frm_dos                                                     AS frm_dos,
        d.to_dos                                                      AS to_dos,
        CASE WHEN d.pat_stat = '' THEN NULL ELSE d.pat_stat END       AS pat_stat,
        CASE WHEN trim(b.bill) = '' THEN NULL ELSE trim(b.bill) END   AS bill_type,
        unnest(array[
            rtrim(a.prim_dx_cd),
            rtrim(a.dx_cd_1),  rtrim(a.dx_cd_2),  rtrim(a.dx_cd_3),
            rtrim(a.dx_cd_4),  rtrim(a.dx_cd_5),  rtrim(a.dx_cd_6),
            rtrim(a.dx_cd_7),  rtrim(a.dx_cd_8),  rtrim(a.dx_cd_9),
            rtrim(a.dx_cd_10), rtrim(a.dx_cd_11), rtrim(a.dx_cd_12),
            rtrim(a.dx_cd_13), rtrim(a.dx_cd_14), rtrim(a.dx_cd_15),
            rtrim(a.dx_cd_16), rtrim(a.dx_cd_17), rtrim(a.dx_cd_18),
            rtrim(a.dx_cd_19), rtrim(a.dx_cd_20), rtrim(a.dx_cd_21),
            rtrim(a.dx_cd_22), rtrim(a.dx_cd_23), rtrim(a.dx_cd_24)
        ]) AS dx_cd
    FROM medicaid.enc_dx a
    JOIN medicaid.enc_proc b   ON rtrim(b.derv_enc) = rtrim(a.derv_enc)
    JOIN medicaid.enc_header d ON d.derv_enc = b.derv_enc
    WHERE EXTRACT(YEAR FROM d.frm_dos) > 2018
)
SELECT DISTINCT
    a.derv_enc AS clm_id,
    a.mem_id   AS client_nbr,
    a.frm_dos  AS clm_from_date,
    a.to_dos   AS clm_to_date,
    a.pat_stat AS pat_stat,
    'enc_dx'   AS src_table,
    a.bill_type,
    b.*
FROM get_dx a
JOIN dev.poem_codeset_births b ON a.dx_cd = b.cd
WHERE a.dx_cd IS NOT NULL AND a.dx_cd <> '';


-----------------
-- Simplify
-------------------

DROP TABLE IF EXISTS dev.poem_all_dx_simplify;

-- Facility claims first (have bill_type)
CREATE TABLE dev.poem_all_dx_simplify AS
SELECT DISTINCT *, 'F' AS fac_prof
FROM dev.poem_all_dx
WHERE bill_type IS NOT NULL;

-- Professional claims that do not overlap with an existing facility claim
INSERT INTO dev.poem_all_dx_simplify
SELECT DISTINCT a.*, 'P' AS fac_prof
FROM dev.poem_all_dx a
LEFT JOIN dev.poem_all_dx_simplify b
    ON a.client_nbr = b.client_nbr
   AND a.clm_from_date <= b.clm_to_date
   AND a.clm_to_date   >= b.clm_from_date
WHERE b.client_nbr IS NULL
  AND a.bill_type IS NULL;


/* -------------------------------------------------------
 * Quarantine contradiction records
 * (different outcome_type on same claim date)
 * ------------------------------------------------------ */

DROP TABLE IF EXISTS dev.poem_all_dx_simplify_contradictions;

CREATE TABLE dev.poem_all_dx_simplify_contradictions AS
SELECT *
FROM dev.poem_all_dx_simplify a
WHERE EXISTS (
    SELECT 1
    FROM dev.poem_all_dx_simplify b
    WHERE a.client_nbr = b.client_nbr
      AND (a.clm_to_date = b.clm_to_date OR a.clm_from_date = b.clm_from_date)
      AND a.outcome_type <> b.outcome_type
);

DELETE FROM dev.poem_all_dx_simplify
WHERE (client_nbr, clm_from_date) IN (
    SELECT DISTINCT a.client_nbr, a.clm_from_date
    FROM dev.poem_all_dx_simplify a
    WHERE EXISTS (
        SELECT 1
        FROM dev.poem_all_dx_simplify b
        WHERE a.client_nbr = b.client_nbr
          AND (a.clm_to_date = b.clm_to_date OR a.clm_from_date = b.clm_from_date)
          AND a.outcome_type <> b.outcome_type
    )
);


/*
 * Collapse overlapping claims into episodes
 */

DROP TABLE IF EXISTS dev.poem_all_dx_episodes;

CREATE TABLE dev.poem_all_dx_episodes AS
WITH EpisodeData AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY client_nbr ORDER BY clm_from_date, clm_to_date) AS rn
    FROM dev.poem_all_dx_simplify
),
LagData AS (
    SELECT *,
        LAG(clm_from_date) OVER (PARTITION BY client_nbr ORDER BY rn) AS prev_start_date,
        LAG(clm_to_date)   OVER (PARTITION BY client_nbr ORDER BY rn) AS prev_end_date,
        MAX(clm_to_date)   OVER (PARTITION BY client_nbr ORDER BY rn
                                 ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS max_end_date_before_current
    FROM EpisodeData
),
EpisodeFlagData AS (
    SELECT *,
        CASE
            WHEN prev_start_date IS NULL THEN 1  -- first record for this client
            WHEN clm_from_date > COALESCE(max_end_date_before_current, '1900-01-01'::date) THEN 1
            ELSE 0
        END AS NewEpisodeFlag
    FROM LagData
),
FinalGrouped AS (
    SELECT *,
        SUM(NewEpisodeFlag) OVER (PARTITION BY client_nbr ORDER BY rn
                                  ROWS UNBOUNDED PRECEDING) AS EpisodeGroup
    FROM EpisodeFlagData
),
RankedEpisodes AS (
    SELECT *,
        DENSE_RANK() OVER (PARTITION BY client_nbr ORDER BY EpisodeGroup) AS episode_id
    FROM FinalGrouped
)
SELECT *
FROM RankedEpisodes;


-- Aggregate start/end dates per episode
DROP TABLE IF EXISTS dev.poem_all_dx_episodes_start_end;

CREATE TABLE dev.poem_all_dx_episodes_start_end AS
SELECT
    a.client_nbr,
    a.episode_id,
    min(clm_from_date)                                                AS start_date,
    max(clm_to_date)                                                  AS end_date,
    max(multiple_flag)                                                AS multiple_flag,
    max(pat_stat)                                                     AS pat_stat,
    min(fac_prof)                                                     AS fac_prof,
    max(a.outcome_type)                                               AS outcome_type,
    CASE WHEN count(DISTINCT a.outcome_type) > 1 THEN 1 ELSE 0 END   AS lb_sb_mix
FROM dev.poem_all_dx_episodes a
GROUP BY a.client_nbr, a.episode_id;


/* ------------------------
 * Streak detection
 * (clients with 6+ consecutive monthly claims are quarantined
 *  as likely mis-flagged single pregnancies)
 * ----------------------- */

DROP TABLE IF EXISTS dev.poem_all_dx_streaks;

CREATE TABLE dev.poem_all_dx_streaks AS
WITH ranked_records AS (
    SELECT
        client_nbr,
        DATE_TRUNC('month', start_date)::date                         AS record_month,
        EXTRACT(YEAR  FROM DATE_TRUNC('month', start_date))::int      AS yr,
        EXTRACT(MONTH FROM DATE_TRUNC('month', start_date))::int      AS mo,
        RANK() OVER (PARTITION BY client_nbr
                     ORDER BY DATE_TRUNC('month', start_date))        AS rnk
    FROM dev.poem_all_dx_episodes_start_end
    GROUP BY client_nbr, DATE_TRUNC('month', start_date)
),
streaks AS (
    SELECT
        client_nbr,
        record_month,
        rnk - (yr * 12 + mo) AS streak_id
    FROM ranked_records
),
consecutive_streaks AS (
    SELECT
        client_nbr,
        streak_id,
        min(record_month) AS start_month,
        max(record_month) AS end_month,
        count(*)          AS streak_length
    FROM streaks
    GROUP BY client_nbr, streak_id
)
SELECT
    p.*,
    cs.streak_id,
    cs.start_month::date,
    cs.end_month::date,
    cs.streak_length
FROM dev.poem_all_dx_episodes_start_end p
JOIN streaks s
    ON p.client_nbr = s.client_nbr
   AND DATE_TRUNC('month', p.start_date)::date = s.record_month
LEFT JOIN consecutive_streaks cs
    ON s.client_nbr = cs.client_nbr
   AND s.streak_id  = cs.streak_id;

-- IDs with 6+ in a streak
DROP TABLE IF EXISTS dev.poem_all_dx_streaks_delete;

CREATE TABLE dev.poem_all_dx_streaks_delete AS
SELECT DISTINCT client_nbr, episode_id
FROM dev.poem_all_dx_streaks
WHERE streak_length >= 6;


-- Quarantine streak records
DROP TABLE IF EXISTS dev.poem_all_dx_episodes_quarantine_streaks;

CREATE TABLE dev.poem_all_dx_episodes_quarantine_streaks AS
SELECT a.*
FROM dev.poem_all_dx_episodes_start_end a
JOIN dev.poem_all_dx_streaks_delete b
    ON a.client_nbr = b.client_nbr
   AND a.episode_id = b.episode_id;

-- Remove streaks from main episode table
DELETE FROM dev.poem_all_dx_episodes_start_end
WHERE (client_nbr, episode_id) IN (
    SELECT client_nbr, episode_id
    FROM dev.poem_all_dx_streaks_delete
);


-----------------------------------------------------------------------------------------------
-- Build Episodes
-- Uses an iterative loop (PL/pgSQL) to replicate the WHILE loop logic.
-- LB episodes are added up to 7 passes, then SB episodes up to 7 passes.
-----------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS dev.poem_episodes_build;

CREATE TABLE dev.poem_episodes_build AS
SELECT *, row_number() OVER (PARTITION BY client_nbr ORDER BY episode_id) AS rn
FROM dev.poem_all_dx_episodes_start_end
LIMIT 0;

DO $$
DECLARE i INT;
BEGIN
    -- LB passes
    FOR i IN 1..7 LOOP
        INSERT INTO dev.poem_episodes_build
        WITH get_all AS (
            SELECT
                a.*,
                ROW_NUMBER() OVER (PARTITION BY a.client_nbr ORDER BY a.episode_id) AS rn
            FROM dev.poem_all_dx_episodes_start_end a
            LEFT JOIN dev.poem_episodes_build b
                ON a.client_nbr = b.client_nbr
               AND (a.start_date - b.start_date) <= 182
            WHERE a.outcome_type = 'LB'
              AND b.client_nbr IS NULL
        )
        SELECT * FROM get_all WHERE rn = 1;
    END LOOP;

    -- SB passes
    FOR i IN 1..7 LOOP
        INSERT INTO dev.poem_episodes_build
        WITH sb_candidates AS (
            SELECT
                a.*,
                ROW_NUMBER() OVER (PARTITION BY a.client_nbr ORDER BY a.episode_id) AS rn
            FROM dev.poem_all_dx_episodes_start_end a
            LEFT JOIN dev.poem_episodes_build b
                ON a.client_nbr = b.client_nbr
               AND (
                    (b.outcome_type = 'LB' AND (a.start_date - b.start_date) <= 182)
                    OR (b.outcome_type = 'SB' AND (b.start_date - a.start_date) <= 168)
                   )
            WHERE a.outcome_type = 'SB'
              AND b.client_nbr IS NULL
        )
        SELECT * FROM sb_candidates WHERE rn = 1;
    END LOOP;
END;
$$;


----------------------------------------------
-- Date of Birth
----------------------------------------------

DROP TABLE IF EXISTS dev.poem_temp_bday;

-- Greenplum: medicaid.enrl and medicaid.chip_enrl are pre-appended
CREATE TABLE dev.poem_temp_bday AS
WITH get_bdays AS (
    SELECT client_nbr, dob::date AS dob
    FROM medicaid.enrl
    UNION ALL
    SELECT client_nbr, CAST(LEFT(date_of_birth, 9) AS date) AS dob
    FROM medicaid.chip_enrl
)
SELECT client_nbr, dob, count(*) AS dob_count
FROM get_bdays
GROUP BY client_nbr, dob;


DROP TABLE IF EXISTS dev.poem_dob;

CREATE TABLE dev.poem_dob AS
WITH get_row_number AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY client_nbr ORDER BY dob_count DESC, dob DESC) AS rn
    FROM dev.poem_temp_bday
)
SELECT client_nbr, dob
FROM get_row_number
WHERE rn = 1;

DROP TABLE IF EXISTS dev.poem_temp_bday;


--------------------
-- Demographics / Enrollment
--------------------

DROP TABLE IF EXISTS dev.poem_demographics_raw;

-- medicaid.enrl and medicaid.chip_enrl are pre-appended in Greenplum
CREATE TABLE dev.poem_demographics_raw AS
SELECT DISTINCT
    client_nbr,
    race                                                         AS race,
    me_code,
    'enrl'                                                       AS src_table,
    TO_DATE(SUBSTRING(elig_date FROM 1 FOR 6) || '01', 'YYYYMMDD') AS elig_month,
    LEFT(zip, 5)                                                 AS zip,
    CAST(SUBSTRING(elig_date FROM 1 FOR 4) AS FLOAT)            AS elig_year,
    contract_id,
    smib::int                                                         AS dual
FROM medicaid.enrl
WHERE CAST(SUBSTRING(elig_date FROM 1 FOR 4) AS INT) > 2018
UNION ALL
SELECT DISTINCT
    chip.client_nbr,
    ethnicity,
    NULL                                                         AS me_code,
    'chip_enrl'                                                  AS src_table,
    TO_DATE(SUBSTRING(chip.elig_month FROM 1 FOR 6) || '01', 'YYYYMMDD') AS elig_month,
    LEFT(chip.mailing_zip, 5)                                   AS zip,
    CAST(SUBSTRING(chip.elig_month FROM 1 FOR 4) AS FLOAT)      AS elig_year,
    plan_cd                                                      AS contract_id,
    0                                                            AS dual
FROM medicaid.chip_enrl chip
LEFT JOIN medicaid.enrl enrl
    ON chip.client_nbr = enrl.client_nbr
   AND TO_DATE(SUBSTRING(chip.elig_month FROM 1 FOR 6) || '01', 'YYYYMMDD')
     = TO_DATE(SUBSTRING(enrl.elig_date   FROM 1 FOR 6) || '01', 'YYYYMMDD')
WHERE enrl.client_nbr IS NULL
  AND CAST(SUBSTRING(chip.elig_month FROM 1 FOR 4) AS INT) > 2018;


-- Add plan name
DROP TABLE IF EXISTS dev.poem_demographics;

CREATE TABLE dev.poem_demographics AS
SELECT DISTINCT a.*, b.mco_program_nm AS plan_
FROM dev.poem_demographics_raw a
JOIN reference_tables.medicaid_lu_contract b ON a.contract_id = b.plan_cd;
-- NOTE: lu_contract should exist in medicaid schema; adjust schema prefix if needed


-----------------------------------
-- Add Enrollment Info to Episodes
-----------------------------------

DROP TABLE IF EXISTS dev.poem_episodes_enrollment;

CREATE TABLE dev.poem_episodes_enrollment AS
SELECT DISTINCT
    a.*,
    b.dob,
    DATE_PART('year', AGE(a.start_date, b.dob))::int           AS age,
    c.race                                                      AS race_cd,
    c.me_code,
    c.src_table                                                 AS enrollment_table,
    c.zip,
    c.elig_year,
    zip.state,
    EXTRACT(YEAR FROM a.start_date)::int                        AS year,
    ROW_NUMBER() OVER (PARTITION BY a.client_nbr ORDER BY a.start_date) AS ep_num,
    a.client_nbr || '-' ||
        ROW_NUMBER() OVER (PARTITION BY a.client_nbr ORDER BY a.start_date)::varchar AS ep_id,
    (a.end_date - a.start_date) + 1                             AS los,
    CASE WHEN c.client_nbr IS NULL THEN 0 ELSE 1 END            AS enrolled_birth,
    c.plan_,
    c.dual
FROM dev.poem_episodes_build a
INNER JOIN dev.poem_dob b
    ON a.client_nbr = b.client_nbr
LEFT JOIN dev.poem_demographics c
    ON a.client_nbr = c.client_nbr
   AND MAKE_DATE(EXTRACT(YEAR FROM a.start_date)::int,
                 EXTRACT(MONTH FROM a.start_date)::int, 1) = c.elig_month
LEFT JOIN dev.zip_zcta_all_years zip   -- adjust schema if needed
    ON c.zip = zip.zip
   AND c.elig_year = zip.year;


-- Sanity check (distinct episode IDs should equal row count)
SELECT count(DISTINCT trim(client_nbr) || cast(episode_id AS varchar))
FROM dev.poem_episodes_enrollment
UNION ALL
SELECT count(*) FROM dev.poem_episodes_enrollment;


/*
 * Compute anchor dates (midpoints with tie-breaking)
 */

DROP TABLE IF EXISTS dev.poem_episodes_anchordates;

CREATE TABLE dev.poem_episodes_anchordates AS
SELECT
    client_nbr,
    ep_num,
    start_date,
    end_date,
    (end_date - start_date) + 1                                                AS total_days,
    CASE WHEN ((end_date - start_date) + 1) % 2 = 0
         THEN ABS(HASHTEXT(client_nbr)) % 2
         ELSE 0
    END                                                                         AS tie_breaker,
    FLOOR((end_date - start_date) / 2.0)::int
        + CASE WHEN ((end_date - start_date) + 1) % 2 = 0
               THEN ABS(HASHTEXT(client_nbr)) % 2
               ELSE 0 END                                                       AS midpoint_offset,
    start_date + (
        FLOOR((end_date - start_date) / 2.0)::int
        + CASE WHEN ((end_date - start_date) + 1) % 2 = 0
               THEN ABS(HASHTEXT(client_nbr)) % 2
               ELSE 0 END
    )                                                                           AS midpoint_date
FROM dev.poem_episodes_enrollment;


/*
 * Final cohort
 */

DROP TABLE IF EXISTS dev.poem_cohort;

CREATE TABLE dev.poem_cohort AS
SELECT distinct a.*, b.midpoint_date AS anchor_date,
       EXTRACT(YEAR FROM b.midpoint_date)::int AS anchor_year
FROM dev.poem_episodes_enrollment a
JOIN dev.poem_episodes_anchordates b
    ON a.client_nbr = b.client_nbr
   AND a.ep_num     = b.ep_num;

-- Row counts
SELECT count(*) FROM dev.poem_cohort;
SELECT EXTRACT(YEAR FROM anchor_date), count(*) FROM dev.poem_cohort GROUP BY 1;
