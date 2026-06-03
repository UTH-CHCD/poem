-- ============================================================
-- Make Smaller (Cohort-Filtered) Working Tables
-- Converted from SQL Server to Greenplum/PostgreSQL
-- Schema: dev (replaces CHCDWORK.dbo)
-- Source tables: medicaid.* (pre-appended in Greenplum)
--
-- Key changes from SQL Server version:
--   CROSS APPLY (VALUES ...) → CROSS JOIN LATERAL (VALUES ...)
--   YEAR(date)               → EXTRACT(YEAR FROM date)
--   SELECT * INTO            → CREATE TABLE AS
--   Three separate per-FY RX UNIONs collapsed into medicaid.mco_rx,
--     medicaid.ffs_rx, medicaid.chip_rx, medicaid.htw_ffs_rx
--     which are already appended in Greenplum
-- ============================================================

/* ------------------------------
 * CPT / Procedure code table
 * ----------------------------- */

DROP TABLE IF EXISTS dev.poem_cohort_cpt;

CREATE TABLE dev.poem_cohort_cpt AS
WITH get_all AS (
    -- Claims
    SELECT
        pcn                 AS client_nbr,
        a.icn               AS clm_id,
        a.to_dos,
        a.proc_cd,
        a.txm_cd            AS taxonomy_cd,
        a.proc_mod_1,
        a.proc_mod_2,
        a.proc_mod_3,
        a.proc_mod_4,
        a.proc_mod_5,
        a.pos,
        a.rev_cd
    FROM medicaid.clm_detail a
    JOIN medicaid.clm_proc b ON b.icn = a.icn
    UNION ALL
    -- Encounters
    SELECT
        mem_id              AS client_nbr,
        a.derv_enc          AS clm_id,
        a.to_date,           -- enc_det.tdos_csl mapped to to_date in original SQL Server prep
        a.proc_cd,
        a.sub_rend_prv_tax_cd AS taxonomy_cd,
        a.proc_mod_cd_1     AS proc_mod_1,
        a.proc_mod_cd_2     AS proc_mod_2,
        a.proc_mod_cd_3     AS proc_mod_3,
        a.proc_mod_cd_4     AS proc_mod_4,
        NULL::varchar       AS proc_mod_5,
        a.pos,
        a.rev_cd
    FROM medicaid.enc_det a
    JOIN medicaid.enc_proc b ON b.derv_enc = a.derv_enc
)
SELECT DISTINCT a.*
FROM get_all a
JOIN dev.poem_cohort b ON a.client_nbr = b.client_nbr;


/* ------------------------------
 * Diagnosis code table
 * ----------------------------- */

DROP TABLE IF EXISTS dev.poem_cohort_dx;

-- Claims
CREATE TABLE dev.poem_cohort_dx AS
WITH get_dx AS (
    SELECT
        trim(b.icn)                                                        AS icn,
        trim(b.pcn)                                                        AS pcn,
        cast(d.hdr_frm_dos AS date)                                        AS hdr_frm_dos,
        cast(d.hdr_to_dos  AS date)                                        AS hdr_to_dos,
        CASE WHEN d.pat_stat_cd = '' THEN NULL ELSE d.pat_stat_cd END      AS pat_stat_cd,
        dx_cd,
        CASE WHEN trim(b.bill) = '' THEN NULL ELSE trim(b.bill) END        AS bill_type
    FROM medicaid.clm_dx a
    JOIN medicaid.clm_proc b   ON b.icn = a.icn
    JOIN medicaid.clm_header d ON d.icn = b.icn
    CROSS JOIN LATERAL (VALUES
        (rtrim(a.prim_dx_cd)), (rtrim(a.dx_cd_1)),  (rtrim(a.dx_cd_2)),  (rtrim(a.dx_cd_3)),
        (rtrim(a.dx_cd_4)),  (rtrim(a.dx_cd_5)),  (rtrim(a.dx_cd_6)),  (rtrim(a.dx_cd_7)),
        (rtrim(a.dx_cd_8)),  (rtrim(a.dx_cd_9)),  (rtrim(a.dx_cd_10)), (rtrim(a.dx_cd_11)),
        (rtrim(a.dx_cd_12)), (rtrim(a.dx_cd_13)), (rtrim(a.dx_cd_14)), (rtrim(a.dx_cd_15)),
        (rtrim(a.dx_cd_16)), (rtrim(a.dx_cd_17)), (rtrim(a.dx_cd_18)), (rtrim(a.dx_cd_19)),
        (rtrim(a.dx_cd_20)), (rtrim(a.dx_cd_21)), (rtrim(a.dx_cd_22)), (rtrim(a.dx_cd_23)),
        (rtrim(a.dx_cd_24)), (rtrim(a.dx_cd_25))
    ) AS unnested(dx_cd)
    WHERE EXTRACT(YEAR FROM cast(d.hdr_frm_dos AS date)) > 2018
)
SELECT DISTINCT
    a.pcn         AS client_nbr,
    a.icn         AS clm_id,
    a.hdr_frm_dos AS clm_from_date,
    a.dx_cd
FROM get_dx a
JOIN dev.poem_cohort b ON b.client_nbr = a.pcn
WHERE a.dx_cd <> '';

-- Encounters
INSERT INTO dev.poem_cohort_dx
WITH get_dx AS (
    SELECT
        trim(b.mem_id)   AS mem_id,
        trim(b.derv_enc) AS derv_enc,
        d.frm_dos        AS frm_dos,
        dx_cd
    FROM medicaid.enc_dx a
    JOIN medicaid.enc_proc b   ON rtrim(b.derv_enc) = rtrim(a.derv_enc)
    JOIN medicaid.enc_header d ON d.derv_enc = b.derv_enc
    CROSS JOIN LATERAL (VALUES
        (rtrim(a.prim_dx_cd)), (rtrim(a.dx_cd_1)),  (rtrim(a.dx_cd_2)),  (rtrim(a.dx_cd_3)),
        (rtrim(a.dx_cd_4)),  (rtrim(a.dx_cd_5)),  (rtrim(a.dx_cd_6)),  (rtrim(a.dx_cd_7)),
        (rtrim(a.dx_cd_8)),  (rtrim(a.dx_cd_9)),  (rtrim(a.dx_cd_10)), (rtrim(a.dx_cd_11)),
        (rtrim(a.dx_cd_12)), (rtrim(a.dx_cd_13)), (rtrim(a.dx_cd_14)), (rtrim(a.dx_cd_15)),
        (rtrim(a.dx_cd_16)), (rtrim(a.dx_cd_17)), (rtrim(a.dx_cd_18)), (rtrim(a.dx_cd_19)),
        (rtrim(a.dx_cd_20)), (rtrim(a.dx_cd_21)), (rtrim(a.dx_cd_22)), (rtrim(a.dx_cd_23)),
        (rtrim(a.dx_cd_24))
    ) AS unnested(dx_cd)
    WHERE EXTRACT(YEAR FROM d.frm_dos) > 2018
)
SELECT DISTINCT
    a.mem_id   AS client_nbr,
    a.derv_enc AS clm_id,
    a.frm_dos  AS clm_from_date,
    a.dx_cd
FROM get_dx a
JOIN dev.poem_cohort b ON b.client_nbr = a.mem_id
WHERE a.dx_cd <> '';


------------------------------------------------
-- RX
-- Greenplum has pre-appended tables:
--   medicaid.mco_rx, medicaid.ffs_rx, medicaid.chip_rx, medicaid.htw_ffs_rx
-- Replaces the 22-table UNION ALL in the SQL Server version.
------------------------------------------------

DROP TABLE IF EXISTS dev.poem_rx;

CREATE TABLE dev.poem_rx AS
SELECT DISTINCT a.client_nbr, a.fill_dt, a.ndc
FROM (
    SELECT trim(pcn) AS client_nbr, rx_fill_dt AS fill_dt, trim(ndc) AS ndc
    FROM medicaid.mco_rx
    UNION ALL
    SELECT trim(pcn), rx_fill_dt, trim(ndc)
    FROM medicaid.ffs_rx
    UNION ALL
    SELECT trim(pcn), rx_fill_dt, trim(ndc)
    FROM medicaid.chip_rx
    UNION ALL
    SELECT trim(pcn), rx_fill_dt, trim(ndc)
    FROM medicaid.htw_ffs_rx
) a
JOIN dev.poem_cohort b ON a.client_nbr = b.client_nbr;


-----------------------
-- ICD Procedure Codes
-----------------------

DROP TABLE IF EXISTS dev.poem_cohort_icd;

-- Claims
CREATE TABLE dev.poem_cohort_icd AS
WITH get_icd AS (
    SELECT
        trim(b.pcn)                 AS pcn,
        cast(d.hdr_frm_dos AS date) AS hdr_frm_dos,
        cast(d.hdr_to_dos  AS date) AS hdr_to_dos,
        trim(icd_cd)                AS icd_cd
    FROM medicaid.clm_proc b
    JOIN medicaid.clm_header d ON d.icn = b.icn
    CROSS JOIN LATERAL (VALUES
        (rtrim(b.proc_icd_cd_1)),  (rtrim(b.proc_icd_cd_2)),  (rtrim(b.proc_icd_cd_3)),
        (rtrim(b.proc_icd_cd_4)),  (rtrim(b.proc_icd_cd_5)),  (rtrim(b.proc_icd_cd_6)),
        (rtrim(b.proc_icd_cd_7)),  (rtrim(b.proc_icd_cd_8)),  (rtrim(b.proc_icd_cd_9)),
        (rtrim(b.proc_icd_cd_10)), (rtrim(b.proc_icd_cd_11)), (rtrim(b.proc_icd_cd_12)),
        (rtrim(b.proc_icd_cd_13)), (rtrim(b.proc_icd_cd_14)), (rtrim(b.proc_icd_cd_15)),
        (rtrim(b.proc_icd_cd_16)), (rtrim(b.proc_icd_cd_17)), (rtrim(b.proc_icd_cd_18)),
        (rtrim(b.proc_icd_cd_19)), (rtrim(b.proc_icd_cd_20)), (rtrim(b.proc_icd_cd_21)),
        (rtrim(b.proc_icd_cd_22)), (rtrim(b.proc_icd_cd_23)), (rtrim(b.proc_icd_cd_24)),
        (rtrim(b.proc_icd_cd_25))
    ) AS unnested(icd_cd)
    WHERE EXTRACT(YEAR FROM cast(d.hdr_frm_dos AS date)) > 2018
)
SELECT DISTINCT
    a.pcn         AS client_nbr,
    a.hdr_frm_dos AS clm_from_date,
    a.icd_cd
FROM get_icd a
JOIN dev.poem_cohort b ON b.client_nbr = a.pcn
WHERE a.icd_cd <> '';

-- Encounters
INSERT INTO dev.poem_cohort_icd
WITH get_icd AS (
    SELECT
        trim(b.mem_id)   AS mem_id,
        d.frm_dos        AS frm_dos,
        icd_cd
    FROM medicaid.enc_proc b
    JOIN medicaid.enc_header d ON d.derv_enc = b.derv_enc
    CROSS JOIN LATERAL (VALUES
        (rtrim(b.proc_icd_cd_1)),  (rtrim(b.proc_icd_cd_2)),  (rtrim(b.proc_icd_cd_3)),
        (rtrim(b.proc_icd_cd_4)),  (rtrim(b.proc_icd_cd_5)),  (rtrim(b.proc_icd_cd_6)),
        (rtrim(b.proc_icd_cd_7)),  (rtrim(b.proc_icd_cd_8)),  (rtrim(b.proc_icd_cd_9)),
        (rtrim(b.proc_icd_cd_10)), (rtrim(b.proc_icd_cd_11)), (rtrim(b.proc_icd_cd_12)),
        (rtrim(b.proc_icd_cd_13)), (rtrim(b.proc_icd_cd_14)), (rtrim(b.proc_icd_cd_15)),
        (rtrim(b.proc_icd_cd_16)), (rtrim(b.proc_icd_cd_17)), (rtrim(b.proc_icd_cd_18)),
        (rtrim(b.proc_icd_cd_19)), (rtrim(b.proc_icd_cd_20)), (rtrim(b.proc_icd_cd_21)),
        (rtrim(b.proc_icd_cd_22)), (rtrim(b.proc_icd_cd_23)), (rtrim(b.proc_icd_cd_24))
    ) AS unnested(icd_cd)
    WHERE EXTRACT(YEAR FROM d.frm_dos) > 2018
)
SELECT DISTINCT
    a.mem_id   AS client_nbr,
    a.frm_dos  AS clm_from_date,
    a.icd_cd
FROM get_icd a
JOIN dev.poem_cohort b ON b.client_nbr = a.mem_id
WHERE a.icd_cd <> '';
