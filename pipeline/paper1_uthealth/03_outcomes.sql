-- ============================================================
-- Outcomes for POEM Project
-- Converted from SQL Server to Greenplum/PostgreSQL
-- Schema: dev (replaces CHCDWORK.dbo)
-- Source tables: medicaid.* (pre-appended in Greenplum)
--
-- Key conversions:
--   DATEADD(MONTH, n, d)     → d + (n || ' months')::interval
--   DATEADD(DAY, n, d)       → d + n
--   DATEDIFF(MONTH, d1, d2)  → (DATE_PART('year',d2)-DATE_PART('year',d1))*12
--                              + DATE_PART('month',d2)-DATE_PART('month',d1)
--   DATEFROMPARTS(y,m,d)     → MAKE_DATE(y,m,d)
--   SELECT * INTO            → CREATE TABLE AS
--   ISNULL                   → COALESCE
-- ============================================================


/*
 * Any healthcare contact: 3–12 months after anchor date
 */

DROP TABLE IF EXISTS dev.poem_cohort_all_dates_3_12;

CREATE TABLE dev.poem_cohort_all_dates_3_12 AS
WITH get_all AS (
    SELECT pcn    AS client_nbr, to_dos    AS service_date
    FROM medicaid.clm_detail a
    JOIN medicaid.clm_proc b ON b.icn = a.icn
    UNION ALL
    SELECT mem_id AS client_nbr, tdos_csl::date AS service_date
    FROM medicaid.enc_det a
    JOIN medicaid.enc_proc b ON b.derv_enc = a.derv_enc
)
SELECT DISTINCT a.*
FROM get_all a
JOIN dev.poem_cohort b ON a.client_nbr = b.client_nbr
WHERE a.service_date >= (b.anchor_date + INTERVAL '3 months')::date
  AND a.service_date <= (b.anchor_date + INTERVAL '12 months')::date;

DROP TABLE IF EXISTS dev.poem_outcomes_3_12_months;

CREATE TABLE dev.poem_outcomes_3_12_months AS
SELECT
    a.client_nbr,
    a.ep_num,
    MAX(CASE WHEN b.client_nbr IS NOT NULL THEN 1 ELSE 0 END) AS had_claims_3_12_months
FROM dev.poem_cohort a
LEFT JOIN dev.poem_cohort_all_dates_3_12 b ON a.client_nbr = b.client_nbr
GROUP BY a.client_nbr, a.ep_num;


/*
 * Any healthcare contact: 0–12 months after anchor date
 */

DROP TABLE IF EXISTS dev.poem_cohort_all_dates_0_12;

CREATE TABLE dev.poem_cohort_all_dates_0_12 AS
WITH get_all AS (
    SELECT pcn    AS client_nbr, to_dos    AS service_date
    FROM medicaid.clm_detail a
    JOIN medicaid.clm_proc b ON b.icn = a.icn
    UNION ALL
    SELECT mem_id AS client_nbr, tdos_csl::date AS service_date
    FROM medicaid.enc_det a
    JOIN medicaid.enc_proc b ON b.derv_enc = a.derv_enc
)
SELECT DISTINCT a.*
FROM get_all a
JOIN dev.poem_cohort b ON a.client_nbr = b.client_nbr
WHERE a.service_date >  b.anchor_date
  AND a.service_date <= (b.anchor_date + INTERVAL '12 months')::date;

DROP TABLE IF EXISTS dev.poem_outcomes_0_12_months;

CREATE TABLE dev.poem_outcomes_0_12_months AS
SELECT
    a.client_nbr,
    a.ep_num,
    MAX(CASE WHEN b.client_nbr IS NOT NULL THEN 1 ELSE 0 END) AS had_claims_0_12_months
FROM dev.poem_cohort a
LEFT JOIN dev.poem_cohort_all_dates_0_12 b ON a.client_nbr = b.client_nbr
GROUP BY a.client_nbr, a.ep_num;


/* -------------------------------------------------------
 * Enrollment: enrolled at 90 days and 12 months after
 * ----------------------------------------------------- */

DROP TABLE IF EXISTS dev.poem_outcomes_enrollment;

CREATE TABLE dev.poem_outcomes_enrollment AS
SELECT DISTINCT
    c.client_nbr,
    c.ep_num,
    CASE WHEN d90.client_nbr IS NOT NULL THEN 1 ELSE 0 END AS out_enroll_90,
    CASE WHEN d12.client_nbr IS NOT NULL THEN 1 ELSE 0 END AS out_enroll_12
FROM dev.poem_cohort c
LEFT JOIN dev.poem_demographics AS d90
    ON d90.client_nbr = c.client_nbr
   AND d90.elig_month = MAKE_DATE(
           EXTRACT(YEAR  FROM c.anchor_date + 91)::int,
           EXTRACT(MONTH FROM c.anchor_date + 91)::int, 1)
LEFT JOIN dev.poem_demographics AS d12
    ON d12.client_nbr = c.client_nbr
   AND d12.elig_month = MAKE_DATE(
           EXTRACT(YEAR  FROM (c.anchor_date + INTERVAL '1 year')::date)::int,
           EXTRACT(MONTH FROM (c.anchor_date + INTERVAL '1 year')::date)::int, 1);


--- Continuous enrollment AFTER anchor date
DROP TABLE IF EXISTS dev.poem_outcomes_ce_after;

CREATE TABLE dev.poem_outcomes_ce_after AS
WITH enrollment_months AS (
    SELECT DISTINCT
        c.client_nbr,
        c.ep_num,
        c.anchor_date,
        (  (DATE_PART('year',  d.elig_month) - DATE_PART('year',
                MAKE_DATE(EXTRACT(YEAR FROM c.anchor_date)::int,
                          EXTRACT(MONTH FROM c.anchor_date)::int, 1))) * 12
         + (DATE_PART('month', d.elig_month) - DATE_PART('month',
                MAKE_DATE(EXTRACT(YEAR FROM c.anchor_date)::int,
                          EXTRACT(MONTH FROM c.anchor_date)::int, 1)))
        )::int AS months_from_anchor
    FROM dev.poem_cohort c
    INNER JOIN dev.poem_demographics d
        ON d.client_nbr = c.client_nbr
       AND d.elig_month >= MAKE_DATE(EXTRACT(YEAR FROM c.anchor_date)::int,
                                     EXTRACT(MONTH FROM c.anchor_date)::int, 1)
),
with_next AS (
    SELECT *,
        LEAD(months_from_anchor) OVER (PARTITION BY client_nbr, ep_num
                                       ORDER BY months_from_anchor) AS next_month
    FROM enrollment_months
),
gap_detection AS (
    SELECT *,
        CASE WHEN next_month - months_from_anchor > 1 THEN 1 ELSE 0 END AS has_gap_after
    FROM with_next
)
SELECT
    client_nbr,
    ep_num,
    anchor_date,
    CASE
        WHEN MIN(months_from_anchor) > 0 THEN 0
        ELSE COALESCE(MIN(CASE WHEN has_gap_after = 1 THEN months_from_anchor + 1 END),
                      MAX(months_from_anchor) + 1)
    END AS ce_after
FROM gap_detection
GROUP BY client_nbr, ep_num, anchor_date;


--- CE After — excluding Healthy Texas Women (me_code = 'W')
DROP TABLE IF EXISTS dev.poem_outcomes_ce_after_nohtw;

CREATE TABLE dev.poem_outcomes_ce_after_nohtw AS
WITH enrollment_months AS (
    SELECT DISTINCT
        c.client_nbr,
        c.ep_num,
        c.anchor_date,
        (  (DATE_PART('year',  d.elig_month) - DATE_PART('year',
                MAKE_DATE(EXTRACT(YEAR FROM c.anchor_date)::int,
                          EXTRACT(MONTH FROM c.anchor_date)::int, 1))) * 12
         + (DATE_PART('month', d.elig_month) - DATE_PART('month',
                MAKE_DATE(EXTRACT(YEAR FROM c.anchor_date)::int,
                          EXTRACT(MONTH FROM c.anchor_date)::int, 1)))
        )::int AS months_from_anchor
    FROM dev.poem_cohort c
    INNER JOIN dev.poem_demographics d
        ON d.client_nbr = c.client_nbr
       AND d.elig_month >= MAKE_DATE(EXTRACT(YEAR FROM c.anchor_date)::int,
                                     EXTRACT(MONTH FROM c.anchor_date)::int, 1)
       AND d.me_code <> 'W'
),
with_next AS (
    SELECT *,
        LEAD(months_from_anchor) OVER (PARTITION BY client_nbr, ep_num
                                       ORDER BY months_from_anchor) AS next_month
    FROM enrollment_months
),
gap_detection AS (
    SELECT *,
        CASE WHEN next_month - months_from_anchor > 1 THEN 1 ELSE 0 END AS has_gap_after
    FROM with_next
)
SELECT
    client_nbr, ep_num, anchor_date,
    CASE
        WHEN MIN(months_from_anchor) > 0 THEN 0
        ELSE COALESCE(MIN(CASE WHEN has_gap_after = 1 THEN months_from_anchor + 1 END),
                      MAX(months_from_anchor) + 1)
    END AS ce_after
FROM gap_detection
GROUP BY client_nbr, ep_num, anchor_date;


--- CE BEFORE anchor date
DROP TABLE IF EXISTS dev.poem_outcomes_ce_before;

CREATE TABLE dev.poem_outcomes_ce_before AS
WITH enrollment_months AS (
    SELECT DISTINCT
        c.client_nbr,
        c.ep_num,
        c.anchor_date,
        (  (DATE_PART('year',
                MAKE_DATE(EXTRACT(YEAR FROM c.anchor_date)::int,
                          EXTRACT(MONTH FROM c.anchor_date)::int, 1)) - DATE_PART('year', d.elig_month)) * 12
         + (DATE_PART('month',
                MAKE_DATE(EXTRACT(YEAR FROM c.anchor_date)::int,
                          EXTRACT(MONTH FROM c.anchor_date)::int, 1)) - DATE_PART('month', d.elig_month))
        )::int AS months_before_anchor
    FROM dev.poem_cohort c
    INNER JOIN dev.poem_demographics d
        ON d.client_nbr = c.client_nbr
       AND d.elig_month < MAKE_DATE(EXTRACT(YEAR FROM c.anchor_date)::int,
                                    EXTRACT(MONTH FROM c.anchor_date)::int, 1)
),
with_next AS (
    SELECT *,
        LEAD(months_before_anchor) OVER (PARTITION BY client_nbr, ep_num
                                         ORDER BY months_before_anchor DESC) AS next_month
    FROM enrollment_months
),
gap_detection AS (
    SELECT *,
        CASE WHEN months_before_anchor - next_month > 1 THEN 1 ELSE 0 END AS has_gap_after
    FROM with_next
)
SELECT
    client_nbr, ep_num, anchor_date,
    CASE
        WHEN MIN(months_before_anchor) > 1 THEN 0
        ELSE COALESCE(MIN(CASE WHEN has_gap_after = 1 THEN months_before_anchor - 1 END),
                      MAX(months_before_anchor))
    END AS ce_before
FROM gap_detection
GROUP BY client_nbr, ep_num, anchor_date;


-- Total months before anchor
DROP TABLE IF EXISTS dev.poem_outcomes_total_before;

CREATE TABLE dev.poem_outcomes_total_before AS
SELECT
    c.client_nbr, c.ep_num, c.anchor_date,
    COUNT(DISTINCT d.elig_month) AS total_months_before
FROM dev.poem_cohort c
LEFT JOIN dev.poem_demographics d
    ON d.client_nbr = c.client_nbr
   AND d.elig_month < MAKE_DATE(EXTRACT(YEAR FROM c.anchor_date)::int,
                                EXTRACT(MONTH FROM c.anchor_date)::int, 1)
GROUP BY c.client_nbr, c.ep_num, c.anchor_date;


-- Total months after (including anchor month)
DROP TABLE IF EXISTS dev.poem_outcomes_total_after;

CREATE TABLE dev.poem_outcomes_total_after AS
SELECT
    c.client_nbr, c.ep_num, c.anchor_date,
    COUNT(DISTINCT d.elig_month) AS total_months_after
FROM dev.poem_cohort c
LEFT JOIN dev.poem_demographics d
    ON d.client_nbr = c.client_nbr
   AND d.elig_month >= MAKE_DATE(EXTRACT(YEAR FROM c.anchor_date)::int,
                                 EXTRACT(MONTH FROM c.anchor_date)::int, 1)
GROUP BY c.client_nbr, c.ep_num, c.anchor_date;


-- Combined enrollment metrics
DROP TABLE IF EXISTS dev.poem_outcomes_enroll;

CREATE TABLE dev.poem_outcomes_enroll AS
SELECT
    c.client_nbr,
    c.ep_num,
    COALESCE(e.out_enroll_90,        0) AS out_enroll_90,
    COALESCE(e.out_enroll_12,        0) AS out_enroll_12,
    COALESCE(ca.ce_after,            0) AS ce_after,
    COALESCE(nh.ce_after,            0) AS ce_after_nohtw,
    COALESCE(cb.ce_before,           0) AS ce_before,
    COALESCE(ta.total_months_after,  0) AS total_months_after,
    COALESCE(tb.total_months_before, 0) AS total_months_before
FROM dev.poem_cohort c
LEFT JOIN dev.poem_outcomes_enrollment      e  ON e.client_nbr  = c.client_nbr AND e.ep_num  = c.ep_num
LEFT JOIN dev.poem_outcomes_ce_after        ca ON ca.client_nbr = c.client_nbr AND ca.ep_num = c.ep_num
LEFT JOIN dev.poem_outcomes_ce_before       cb ON cb.client_nbr = c.client_nbr AND cb.ep_num = c.ep_num
LEFT JOIN dev.poem_outcomes_total_after     ta ON ta.client_nbr = c.client_nbr AND ta.ep_num = c.ep_num
LEFT JOIN dev.poem_outcomes_total_before    tb ON tb.client_nbr = c.client_nbr AND tb.ep_num = c.ep_num
LEFT JOIN dev.poem_outcomes_ce_after_nohtw  nh ON nh.client_nbr = c.client_nbr AND nh.ep_num = c.ep_num;


/* ----------------------------------
 * Preventive / E&M Visits
 * --------------------------------- */

DROP TABLE IF EXISTS dev.poem_outcomes_prev_em;

CREATE TABLE dev.poem_outcomes_prev_em AS
SELECT
    c.client_nbr,
    c.ep_num,
    c.anchor_date,
    CASE WHEN COUNT(p.proc_cd) > 0 THEN 1 ELSE 0 END AS out_prev_em
FROM dev.poem_cohort c
LEFT JOIN dev.poem_cohort_cpt p
    ON c.client_nbr = p.client_nbr
   AND (
        (p.proc_cd BETWEEN '99202' AND '99215') OR
        (p.proc_cd BETWEEN '99381' AND '99429') OR
        p.proc_cd IN ('99441','99442','99443')
       )
   AND p.to_dos BETWEEN (c.anchor_date + 7) AND (c.anchor_date + 84)
GROUP BY c.client_nbr, c.ep_num, c.anchor_date;


/* ----------------------------------
 * Postpartum Visits
 * --------------------------------- */

DROP TABLE IF EXISTS dev.poem_outcomes_postpartum_temp;

CREATE TABLE dev.poem_outcomes_postpartum_temp AS
SELECT DISTINCT p.client_nbr, p.to_dos, 'CPT'         AS code_type, p.proc_cd AS code
FROM dev.poem_cohort_cpt p
WHERE p.proc_cd IN ('59430','57170','58300','88141','88142','88143','88147','88148',
                    '88150','88152','88153','88164','88165','88166','88167','88174','88175')
UNION ALL
SELECT          p.client_nbr, p.to_dos, 'HCPCS'        AS code_type, p.proc_cd
FROM dev.poem_cohort_cpt p
WHERE p.proc_cd IN ('0503F','99501','G0101','G0123','G0124','G0141','G0143','G0144',
                    'G0145','G0147','G0148','P3000','P3001','Q0091')
UNION ALL
SELECT          p.client_nbr, p.to_dos, 'Bundled CPT'  AS code_type, p.proc_cd
FROM dev.poem_cohort_cpt p
WHERE p.proc_cd IN ('59400','59410','59510','59515','59610','59614','59618','59622')
UNION ALL
SELECT          d.client_nbr, d.clm_from_date, 'ICD'  AS code_type, d.dx_cd
FROM dev.poem_cohort_dx d
WHERE d.dx_cd IN ('Z01411','Z01419','Z0142','Z30430','Z391','Z392');

-- 84-day window
DROP TABLE IF EXISTS dev.poem_outcomes_out_postpartum1;

CREATE TABLE dev.poem_outcomes_out_postpartum1 AS
SELECT
    c.client_nbr, c.ep_num, p.code_type,
    CASE WHEN COUNT(p.client_nbr) > 0 THEN 1 ELSE 0 END AS out_postpartum,
    COUNT(DISTINCT p.code)                               AS code_count
FROM dev.poem_cohort c
LEFT JOIN dev.poem_outcomes_postpartum_temp p
    ON c.client_nbr = p.client_nbr
   AND p.to_dos BETWEEN (c.anchor_date + 7) AND (c.anchor_date + 84)
GROUP BY c.client_nbr, c.ep_num, p.code_type;

-- 6-month window
DROP TABLE IF EXISTS dev.poem_outcomes_out_postpartum6;

CREATE TABLE dev.poem_outcomes_out_postpartum6 AS
SELECT
    c.client_nbr, c.ep_num, p.code_type,
    CASE WHEN COUNT(p.client_nbr) > 0 THEN 1 ELSE 0 END AS out_postpartum_6,
    COUNT(DISTINCT p.code)                               AS code_count_6
FROM dev.poem_cohort c
LEFT JOIN dev.poem_outcomes_postpartum_temp p
    ON c.client_nbr = p.client_nbr
   AND p.to_dos BETWEEN c.anchor_date AND (c.anchor_date + 182)
GROUP BY c.client_nbr, c.ep_num, p.code_type;

-- 12-month window
DROP TABLE IF EXISTS dev.poem_outcomes_out_postpartum12;

CREATE TABLE dev.poem_outcomes_out_postpartum12 AS
SELECT
    c.client_nbr, c.ep_num, p.code_type,
    CASE WHEN COUNT(p.client_nbr) > 0 THEN 1 ELSE 0 END AS out_postpartum_12,
    COUNT(DISTINCT p.code)                               AS code_count_12
FROM dev.poem_cohort c
LEFT JOIN dev.poem_outcomes_postpartum_temp p
    ON c.client_nbr = p.client_nbr
   AND p.to_dos BETWEEN c.anchor_date AND (c.anchor_date + 365)
GROUP BY c.client_nbr, c.ep_num, p.code_type;

-- Final postpartum outcome table
DROP TABLE IF EXISTS dev.poem_outcomes_out_postpartum;

CREATE TABLE dev.poem_outcomes_out_postpartum AS
SELECT
    a.client_nbr, a.ep_num,
    MAX(out_postpartum)    AS out_postpartum,
    MAX(b.out_postpartum_6)  AS out_postpartum_6,
    MAX(c.out_postpartum_12) AS out_postpartum_12
FROM dev.poem_outcomes_out_postpartum1 a
LEFT JOIN dev.poem_outcomes_out_postpartum6  b USING (client_nbr, ep_num)
LEFT JOIN dev.poem_outcomes_out_postpartum12 c USING (client_nbr, ep_num)
GROUP BY a.client_nbr, a.ep_num;

DROP TABLE IF EXISTS dev.poem_outcomes_postpartum_temp;
DROP TABLE IF EXISTS dev.poem_outcomes_out_postpartum12;
DROP TABLE IF EXISTS dev.poem_outcomes_out_postpartum6;
DROP TABLE IF EXISTS dev.poem_outcomes_out_postpartum1;


/* ---------------------------------
 * Diabetes Test Screen
 * -------------------------------- */

DROP TABLE IF EXISTS dev.test_type_lookup;

CREATE TABLE dev.test_type_lookup (
    code_type VARCHAR(10),
    code      VARCHAR(10),
    test_type VARCHAR(50)
);

INSERT INTO dev.test_type_lookup (code_type, code, test_type) VALUES
    ('CPT','83036','HbA1c'), ('CPT','83037','HbA1c'),
    ('CPT','80047','GTT'),   ('CPT','80048','GTT'),   ('CPT','80050','GTT'),
    ('CPT','80053','GTT'),   ('CPT','80069','GTT'),   ('CPT','82947','GTT'),
    ('CPT','82950','GTT'),   ('CPT','82951','GTT');

DROP TABLE IF EXISTS dev.poem_diab_screen_temp;

CREATE TABLE dev.poem_diab_screen_temp AS
SELECT DISTINCT p.client_nbr, p.to_dos, t.code_type, t.code, t.test_type
FROM dev.poem_cohort_cpt p
JOIN dev.test_type_lookup t ON p.proc_cd = t.code;

-- 6-month
DROP TABLE IF EXISTS dev.poem_outcomes_out_diab_screen6;

CREATE TABLE dev.poem_outcomes_out_diab_screen6 AS
SELECT
    c.client_nbr, c.ep_num, p.test_type,
    CASE WHEN COUNT(p.client_nbr) > 0 THEN 1 ELSE 0 END AS out_diab_screen_6,
    COUNT(DISTINCT p.code) AS code_count_6
FROM dev.poem_cohort c
LEFT JOIN dev.poem_diab_screen_temp p
    ON c.client_nbr = p.client_nbr
   AND p.to_dos BETWEEN c.anchor_date AND (c.anchor_date + 182)
GROUP BY c.client_nbr, c.ep_num, p.test_type;

-- 12-month
DROP TABLE IF EXISTS dev.poem_outcomes_out_diab_screen12;

CREATE TABLE dev.poem_outcomes_out_diab_screen12 AS
SELECT
    c.client_nbr, c.ep_num, p.test_type,
    CASE WHEN COUNT(p.client_nbr) > 0 THEN 1 ELSE 0 END AS out_diab_screen_12,
    COUNT(DISTINCT p.code) AS code_count_12
FROM dev.poem_cohort c
LEFT JOIN dev.poem_diab_screen_temp p
    ON c.client_nbr = p.client_nbr
   AND p.to_dos BETWEEN c.anchor_date AND (c.anchor_date + 365)
GROUP BY c.client_nbr, c.ep_num, p.test_type;

-- Detail
DROP TABLE IF EXISTS dev.poem_outcomes_out_diab_screen_detail;

CREATE TABLE dev.poem_outcomes_out_diab_screen_detail AS
WITH DistinctCombos AS (
    SELECT DISTINCT client_nbr, ep_num, test_type
    FROM (
        SELECT client_nbr, ep_num, test_type FROM dev.poem_outcomes_out_diab_screen6
        UNION
        SELECT client_nbr, ep_num, test_type FROM dev.poem_outcomes_out_diab_screen12
    ) combined
)
SELECT
    d.client_nbr, d.ep_num, d.test_type,
    COALESCE(b.out_diab_screen_6,  0) AS out_diab_screen_6,
    COALESCE(c.out_diab_screen_12, 0) AS out_diab_screen_12
FROM DistinctCombos d
LEFT JOIN dev.poem_outcomes_out_diab_screen6  b USING (client_nbr, ep_num, test_type)
LEFT JOIN dev.poem_outcomes_out_diab_screen12 c USING (client_nbr, ep_num, test_type);

-- Simplified
DROP TABLE IF EXISTS dev.poem_outcomes_out_diab_screen;

CREATE TABLE dev.poem_outcomes_out_diab_screen AS
SELECT client_nbr, ep_num,
       MAX(out_diab_screen_6)  AS out_diab_screen_6,
       MAX(out_diab_screen_12) AS out_diab_screen_12
FROM dev.poem_outcomes_out_diab_screen_detail
GROUP BY client_nbr, ep_num;

-- Pivot by test type
DROP TABLE IF EXISTS dev.poem_outcomes_out_diab_screen_by_type_6_12mo;

CREATE TABLE dev.poem_outcomes_out_diab_screen_by_type_6_12mo AS
SELECT
    client_nbr, ep_num,
    MAX(CASE WHEN test_type = 'HbA1c' THEN out_diab_screen_6  ELSE 0 END) AS out_diab_screen_hba1c_6,
    MAX(CASE WHEN test_type = 'GTT'   THEN out_diab_screen_6  ELSE 0 END) AS out_diab_screen_gtt_6,
    MAX(CASE WHEN test_type = 'HbA1c' THEN out_diab_screen_12 ELSE 0 END) AS out_diab_screen_hba1c_12,
    MAX(CASE WHEN test_type = 'GTT'   THEN out_diab_screen_12 ELSE 0 END) AS out_diab_screen_gtt_12
FROM dev.poem_outcomes_out_diab_screen_detail
GROUP BY client_nbr, ep_num;

DROP TABLE IF EXISTS dev.poem_outcomes_out_diab_screen12;
DROP TABLE IF EXISTS dev.poem_outcomes_out_diab_screen6;
DROP TABLE IF EXISTS dev.poem_diab_screen_temp;


/* ---------------------------------
 * Hypertension Medications
 * -------------------------------- */

DROP TABLE IF EXISTS dev.poem_htn_medications;

-- NOTE: ref.ndc_tier_map assumed to exist; adjust schema prefix if needed
CREATE TABLE dev.poem_htn_medications AS
SELECT DISTINCT *
FROM ref.ndc_tier_map
WHERE tier_1_category IN (
    'ACE inhibitors with calcium channel blocking agents',
    'ACE inhibitors with thiazides',
    'angiotensin converting enzyme (ACE) inhibitors',
    'angiotensin II inhibitors',
    'angiotensin II inhibitors with calcium channel blockers',
    'angiotensin II inhibitors with thiazides',
    'angiotensin receptor blockers and neprilysin inhibitors',
    'beta blockers with thiazides',
    'beta blockers, cardioselective',
    'beta blockers, non-cardioselective',
    'calcium channel blocking agents',
    'loop diuretics',
    'miscellaneous diuretics',
    'potassium sparing diuretics with thiazides',
    'potassium-sparing diuretics',
    'renin inhibitors',
    'vasodilators',
    'peripheral vasodilators'
) OR drug_name = 'magnesium sulfate';

DROP TABLE IF EXISTS dev.poem_htn_med_temp;

CREATE TABLE dev.poem_htn_med_temp AS
SELECT DISTINCT
    p.client_nbr,
    p.fill_dt,
    CASE WHEN drug_name = 'magnesium sulfate' THEN drug_name
         ELSE h.tier_1_category
    END AS htn_category
FROM dev.poem_rx p
JOIN dev.poem_htn_medications h ON p.ndc = h.ndc_code;

-- 6-month
DROP TABLE IF EXISTS dev.poem_outcomes_out_htn_med6;

CREATE TABLE dev.poem_outcomes_out_htn_med6 AS
SELECT
    c.client_nbr, c.ep_num, p.htn_category,
    CASE WHEN COUNT(p.client_nbr) > 0 THEN 1 ELSE 0 END AS out_htn_med_6,
    COUNT(DISTINCT p.fill_dt) AS fill_count_6
FROM dev.poem_cohort c
LEFT JOIN dev.poem_htn_med_temp p
    ON c.client_nbr = p.client_nbr
   AND p.fill_dt BETWEEN c.anchor_date AND (c.anchor_date + 182)
GROUP BY c.client_nbr, c.ep_num, p.htn_category;

-- 12-month
DROP TABLE IF EXISTS dev.poem_outcomes_out_htn_med12;

CREATE TABLE dev.poem_outcomes_out_htn_med12 AS
SELECT
    c.client_nbr, c.ep_num, p.htn_category,
    CASE WHEN COUNT(p.client_nbr) > 0 THEN 1 ELSE 0 END AS out_htn_med_12,
    COUNT(DISTINCT p.fill_dt) AS fill_count_12
FROM dev.poem_cohort c
LEFT JOIN dev.poem_htn_med_temp p
    ON c.client_nbr = p.client_nbr
   AND p.fill_dt BETWEEN c.anchor_date AND (c.anchor_date + 365)
GROUP BY c.client_nbr, c.ep_num, p.htn_category;

-- Detail
DROP TABLE IF EXISTS dev.poem_outcomes_out_htn_med_detail;

CREATE TABLE dev.poem_outcomes_out_htn_med_detail AS
WITH DistinctCombos AS (
    SELECT DISTINCT client_nbr, ep_num, htn_category
    FROM (
        SELECT client_nbr, ep_num, htn_category FROM dev.poem_outcomes_out_htn_med6
        UNION
        SELECT client_nbr, ep_num, htn_category FROM dev.poem_outcomes_out_htn_med12
    ) combined
)
SELECT
    d.client_nbr, d.ep_num, d.htn_category,
    COALESCE(m6.out_htn_med_6,   0) AS out_htn_med_6,
    COALESCE(m6.fill_count_6,    0) AS fill_count_6,
    COALESCE(m12.out_htn_med_12, 0) AS out_htn_med_12,
    COALESCE(m12.fill_count_12,  0) AS fill_count_12
FROM DistinctCombos d
LEFT JOIN dev.poem_outcomes_out_htn_med6  m6  USING (client_nbr, ep_num, htn_category)
LEFT JOIN dev.poem_outcomes_out_htn_med12 m12 USING (client_nbr, ep_num, htn_category);

-- Simplified
DROP TABLE IF EXISTS dev.poem_outcomes_out_htn_med;

CREATE TABLE dev.poem_outcomes_out_htn_med AS
SELECT client_nbr, ep_num,
       MAX(out_htn_med_6)  AS out_htn_med_6,
       MAX(out_htn_med_12) AS out_htn_med_12
FROM dev.poem_outcomes_out_htn_med_detail
GROUP BY client_nbr, ep_num;

DROP TABLE IF EXISTS dev.poem_outcomes_out_htn_med12;
DROP TABLE IF EXISTS dev.poem_outcomes_out_htn_med6;
DROP TABLE IF EXISTS dev.poem_htn_med_temp;


/* ---------------------------------
 * Outpatient Visits
 * -------------------------------- */

DROP TABLE IF EXISTS dev.poem_outcomes_outpatient_all;

CREATE TABLE dev.poem_outcomes_outpatient_all AS
WITH get_all AS (
    SELECT a.client_nbr, clm_id, to_dos
    FROM dev.poem_cohort_cpt a
    JOIN dev.poem_codes_any_out b
        ON a.proc_cd = b.code AND code_type IN ('cpt','hcpcs')
    UNION ALL
    SELECT a.client_nbr, clm_id, to_dos
    FROM dev.poem_cohort_cpt a
    JOIN dev.poem_codes_any_out b
        ON a.rev_cd = b.code AND code_type = 'revenue_code'
    UNION ALL
    SELECT a.client_nbr, clm_id, to_dos
    FROM dev.poem_cohort_cpt a
    WHERE pos = '02'
    UNION ALL
    SELECT a.client_nbr, clm_id, to_dos
    FROM dev.poem_cohort_cpt a
    WHERE proc_mod_1 IN ('GT','95')
       OR proc_mod_2 IN ('GT','95')
       OR proc_mod_3 IN ('GT','95')
       OR proc_mod_4 IN ('GT','95')
       OR proc_mod_5 IN ('GT','95')
    UNION ALL
    SELECT a.client_nbr, clm_id, clm_from_date AS to_dos
    FROM dev.poem_cohort_dx a
    JOIN dev.poem_codes_any_out b
        ON a.dx_cd = b.code AND code_type = 'icd10'
)
SELECT client_nbr, clm_id, MIN(to_dos) AS date_
FROM get_all
GROUP BY client_nbr, clm_id;


-- Postpartum evaluation visits
DROP TABLE IF EXISTS dev.poem_outcomes_outpatient_pe;

CREATE TABLE dev.poem_outcomes_outpatient_pe AS
SELECT DISTINCT client_nbr, clm_id, 'postpartum_evaluation' AS visit_type
FROM dev.poem_cohort_dx
WHERE SUBSTRING(dx_cd FROM 1 FOR 3) = 'Z39';

-- Preventive visits
DROP TABLE IF EXISTS dev.poem_outcomes_outpatient_prev;

CREATE TABLE dev.poem_outcomes_outpatient_prev AS
SELECT DISTINCT *, 'preventive' AS visit_type
FROM (
    SELECT client_nbr, clm_id
    FROM dev.poem_cohort_cpt
    WHERE (proc_cd BETWEEN '99384' AND '99387')
       OR (proc_cd BETWEEN '99394' AND '99397')
       OR  proc_cd IN ('99381','99382','99383','99391','99392','99393',
                       '99401','99402','99403','99404','99411','99412','99429')
    UNION ALL
    SELECT DISTINCT client_nbr, clm_id
    FROM dev.poem_cohort_dx
    WHERE dx_cd IN ('Z0000','Z0001','Z00121','Z00129')
) a;

-- Contraceptive management
DROP TABLE IF EXISTS dev.poem_outcomes_outpatient_contr;

CREATE TABLE dev.poem_outcomes_outpatient_contr AS
SELECT DISTINCT client_nbr, clm_id, 'contraceptive' AS visit_type
FROM dev.poem_cohort_dx
WHERE SUBSTRING(dx_cd FROM 1 FOR 3) = 'Z30';

-- Mental/behavioral health
DROP TABLE IF EXISTS dev.poem_outcomes_outpatient_mental;

CREATE TABLE dev.poem_outcomes_outpatient_mental AS
SELECT DISTINCT client_nbr, clm_id, 'mental' AS visit_type
FROM (
    SELECT client_nbr, clm_id
    FROM dev.poem_cohort_cpt
    WHERE proc_cd IN (
        '90804','90805','90806','90807','90808','90809','90810','90811','90812','90813',
        '90814','90815','90816','90817','90818','90819','90821','90822','90823','90824',
        '90826','90827','90828','90829','90832','90833','90834','90836','90837','90838',
        '90839','90840','90845','90846','90847','90849','90853','90857','90862','90875',
        '90876','90820','90841','90842','90843','90844','90855'
    )
    UNION ALL
    SELECT DISTINCT c.client_nbr, c.clm_id
    FROM dev.poem_cohort_cpt c
    JOIN dev.poem_cohort_dx d
        ON c.client_nbr = d.client_nbr AND c.clm_id = d.clm_id
    WHERE c.proc_cd IN ('99201','99202','99203','99204','99205',
                        '99211','99212','99213','99214','99215')
      AND (
           LEFT(REPLACE(d.dx_cd, '.', ''), 3) IN (
               'F01','F02','F03','F04','F05','F06','F07','F08','F09',
               'F10','F11','F12','F13','F14','F15','F16','F17','F18','F19',
               'F20','F21','F22','F23','F24','F25','F26','F27','F28','F29',
               'F30','F31','F32','F33','F34','F35','F36','F37','F38','F39',
               'F40','F41','F42','F43','F44','F45','F46','F47','F48',
               'F50','F51','F52','F53','F54','F55','F56','F57','F58','F59',
               'F60','F61','F62','F63','F64','F65','F66','F67','F68','F69',
               'F70','F71','F72','F73','F74','F75','F76','F77','F78','F79',
               'F80','F81','F82','F83','F84','F85','F86','F87','F88','F89',
               'F99'
           )
           OR REPLACE(d.dx_cd, '.', '') = 'O9934'
          )
) a;


-- Categorize outpatient claims
DROP TABLE IF EXISTS dev.poem_outcomes_outpatient_categories;

CREATE TABLE dev.poem_outcomes_outpatient_categories AS
SELECT
    a.*,
    CASE WHEN b.client_nbr IS NOT NULL THEN 1 ELSE 0 END AS pe,
    CASE WHEN c.client_nbr IS NOT NULL THEN 1 ELSE 0 END AS prev,
    CASE WHEN d.client_nbr IS NOT NULL THEN 1 ELSE 0 END AS contr,
    CASE WHEN e.client_nbr IS NOT NULL THEN 1 ELSE 0 END AS mental,
    CASE WHEN b.client_nbr IS NULL
          AND c.client_nbr IS NULL
          AND d.client_nbr IS NULL
          AND e.client_nbr IS NULL THEN 1 ELSE 0 END      AS other
FROM dev.poem_outcomes_outpatient_all a
LEFT JOIN dev.poem_outcomes_outpatient_pe    b USING (client_nbr, clm_id)
LEFT JOIN dev.poem_outcomes_outpatient_prev  c USING (client_nbr, clm_id)
LEFT JOIN dev.poem_outcomes_outpatient_contr d USING (client_nbr, clm_id)
LEFT JOIN dev.poem_outcomes_outpatient_mental e USING (client_nbr, clm_id);


-- Outpatient: 0–12 months
DROP TABLE IF EXISTS dev.poem_outcomes_outpatient_12;

CREATE TABLE dev.poem_outcomes_outpatient_12 AS
SELECT
    c.client_nbr,
    c.ep_num,
    MAX(op.pe)                                                      AS out_pe_12,
    MAX(op.prev)                                                    AS out_prev_12,
    MAX(op.contr)                                                   AS out_contr_12,
    MAX(op.mental)                                                  AS out_mental_12,
    MAX(op.other)                                                   AS out_other_12,
    CASE WHEN COUNT(op.client_nbr) > 0 THEN 1 ELSE 0 END           AS out_any_outpatient_12,
    COUNT(DISTINCT CASE WHEN op.pe     = 1 THEN op.date_ END)      AS pe_visit_days_12,
    COUNT(DISTINCT CASE WHEN op.prev   = 1 THEN op.date_ END)      AS prev_visit_days_12,
    COUNT(DISTINCT CASE WHEN op.contr  = 1 THEN op.date_ END)      AS contr_visit_days_12,
    COUNT(DISTINCT CASE WHEN op.mental = 1 THEN op.date_ END)      AS mental_visit_days_12,
    COUNT(DISTINCT CASE WHEN op.other  = 1 THEN op.date_ END)      AS other_visit_days_12,
    COUNT(DISTINCT op.date_)                                        AS total_visit_days_12,
    COUNT(op.client_nbr)                                            AS total_claims_12
FROM dev.poem_cohort c
LEFT JOIN dev.poem_outcomes_outpatient_categories op
    ON c.client_nbr = op.client_nbr
   AND op.date_ BETWEEN (c.anchor_date + 1) AND (c.anchor_date + 365)
GROUP BY c.client_nbr, c.ep_num;


-- Outpatient: 0–61 days
DROP TABLE IF EXISTS dev.poem_outcomes_outpatient_0_61;

CREATE TABLE dev.poem_outcomes_outpatient_0_61 AS
SELECT
    c.client_nbr, c.ep_num,
    MAX(op.pe)    AS out_pe_0_61,    MAX(op.prev)   AS out_prev_0_61,
    MAX(op.contr) AS out_contr_0_61, MAX(op.mental) AS out_mental_0_61,
    MAX(op.other) AS out_other_0_61,
    CASE WHEN COUNT(op.client_nbr) > 0 THEN 1 ELSE 0 END          AS out_any_outpatient_0_61,
    COUNT(DISTINCT CASE WHEN op.pe     = 1 THEN op.date_ END)     AS pe_visit_days_0_61,
    COUNT(DISTINCT CASE WHEN op.prev   = 1 THEN op.date_ END)     AS prev_visit_days_0_61,
    COUNT(DISTINCT CASE WHEN op.contr  = 1 THEN op.date_ END)     AS contr_visit_days_0_61,
    COUNT(DISTINCT CASE WHEN op.mental = 1 THEN op.date_ END)     AS mental_visit_days_0_61,
    COUNT(DISTINCT CASE WHEN op.other  = 1 THEN op.date_ END)     AS other_visit_days_0_61,
    COUNT(DISTINCT op.date_)                                       AS total_visit_days_0_61,
    COUNT(op.client_nbr)                                           AS total_claims_0_61
FROM dev.poem_cohort c
LEFT JOIN dev.poem_outcomes_outpatient_categories op
    ON c.client_nbr = op.client_nbr
   AND op.date_ BETWEEN (c.anchor_date + 1) AND (c.anchor_date + 61)
GROUP BY c.client_nbr, c.ep_num;


-- Outpatient: 61 days – 12 months
DROP TABLE IF EXISTS dev.poem_outcomes_outpatient_61_12;

CREATE TABLE dev.poem_outcomes_outpatient_61_12 AS
SELECT
    c.client_nbr, c.ep_num,
    MAX(op.pe)    AS out_pe_61_12,    MAX(op.prev)   AS out_prev_61_12,
    MAX(op.contr) AS out_contr_61_12, MAX(op.mental) AS out_mental_61_12,
    MAX(op.other) AS out_other_61_12,
    CASE WHEN COUNT(op.client_nbr) > 0 THEN 1 ELSE 0 END          AS out_any_outpatient_61_12,
    COUNT(DISTINCT CASE WHEN op.pe     = 1 THEN op.date_ END)     AS pe_visit_days_61_12,
    COUNT(DISTINCT CASE WHEN op.prev   = 1 THEN op.date_ END)     AS prev_visit_days_61_12,
    COUNT(DISTINCT CASE WHEN op.contr  = 1 THEN op.date_ END)     AS contr_visit_days_61_12,
    COUNT(DISTINCT CASE WHEN op.mental = 1 THEN op.date_ END)     AS mental_visit_days_61_12,
    COUNT(DISTINCT CASE WHEN op.other  = 1 THEN op.date_ END)     AS other_visit_days_61_12,
    COUNT(DISTINCT op.date_)                                       AS total_visit_days_61_12,
    COUNT(op.client_nbr)                                           AS total_claims_61_12
FROM dev.poem_cohort c
LEFT JOIN dev.poem_outcomes_outpatient_categories op
    ON c.client_nbr = op.client_nbr
   AND op.date_ BETWEEN (c.anchor_date + 62) AND (c.anchor_date + 365)
GROUP BY c.client_nbr, c.ep_num;


-- Summary of visit category combinations
DROP TABLE IF EXISTS dev.poem_outcomes_outpatient_categories_summary;

CREATE TABLE dev.poem_outcomes_outpatient_categories_summary AS
WITH categorized_visits AS (
    SELECT a.*,
        CASE
            WHEN pe=1 AND prev=0 AND contr=0 AND mental=0 THEN 'Postpartum evaluation only'
            WHEN pe=0 AND prev=1 AND contr=0 AND mental=0 THEN 'Preventive/well care only'
            WHEN pe=0 AND prev=0 AND contr=1 AND mental=0 THEN 'Contraceptive management only'
            WHEN pe=0 AND prev=0 AND contr=0 AND mental=1 THEN 'Mental/behavioral health care only'
            WHEN pe=1 AND contr=1 AND prev=0 AND mental=0 THEN 'Postpartum & Contraceptive'
            WHEN pe=0 AND contr=1 AND prev=1 AND mental=0 THEN 'Preventive/well & Contraceptive'
            WHEN pe=1 AND contr=0 AND prev=1 AND mental=0 THEN 'Postpartum & Preventive/well'
            WHEN pe=0 AND contr=1 AND prev=0 AND mental=1 THEN 'Contraceptive & Mental/behavioral health care'
            WHEN pe=1 AND contr=0 AND prev=0 AND mental=1 THEN 'Postpartum & mental/behavioral health care'
            WHEN pe=0 AND contr=0 AND prev=1 AND mental=1 THEN 'Preventive/well & mental/behavioral health'
            WHEN pe=0 AND contr=0 AND prev=0 AND mental=0 THEN 'Other acute or chronic illness only'
            ELSE 'Other combination'
        END AS care_type
    FROM dev.poem_outcomes_outpatient_categories a
    JOIN dev.poem_cohort c
        ON c.client_nbr = a.client_nbr
       AND a.date_ BETWEEN (c.anchor_date + 1) AND (c.anchor_date + 365)
),
counts AS (
    SELECT care_type, COUNT(*) AS n
    FROM categorized_visits
    GROUP BY care_type
),
totals AS (SELECT SUM(n) AS total FROM counts)
SELECT
    care_type                                    AS type_care,
    CAST(100.0 * n / total AS NUMERIC(5,1))      AS share_of_visits
FROM counts, totals;


-- Sanity checks
SELECT count(DISTINCT client_nbr) FROM dev.poem_outcomes_outpatient_12;
SELECT count(DISTINCT client_nbr) FROM dev.poem_cohort;
SELECT count(DISTINCT client_nbr) FROM dev.poem_outcomes_outpatient_categories;
