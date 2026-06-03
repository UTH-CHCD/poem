# POEM Project — SQL Server → Greenplum Migration Notes

## Files converted

| Original file                      | Converted file                     | Notes |
|------------------------------------|------------------------------------|-------|
| `00_create_sql_codesets.sql`       | ✅ converted                        | Syntax-only changes |
| `01_extract_all_claims_v03.sql`    | ✅ converted                        | Significant refactor (see below) |
| `02_make_smaller_tables.sql`       | ✅ converted                        | RX union collapsed |
| `03_outcomes.sql`                  | ✅ converted                        | Date arithmetic rewritten |
| `covariates_v03.sql`               | ✅ converted                        | Minimal changes |
| `00_make_appended_tables_FY24.sql` | ❌ **not needed**                   | Tables pre-appended in Greenplum |

---

## Schema mapping

| SQL Server                  | Greenplum        |
|-----------------------------|------------------|
| `CHCDWORK.dbo.<table>`      | `dev.<table>`    |
| `MEDICAID.dbo.<table>_FY##` | `medicaid.<table>` (pre-appended) |
| `REF.dbo.<table>`           | `ref.<table>`    |

---

## Key SQL syntax changes

### Table creation
```sql
-- SQL Server
SELECT * INTO CHCDWORK.dbo.my_table FROM ...

-- Greenplum
CREATE TABLE dev.my_table AS SELECT * FROM ...
```

### Lateral unnesting (pivot rows to columns)
```sql
-- SQL Server
CROSS APPLY (VALUES (col1), (col2)) AS unnested(val)

-- Greenplum
CROSS JOIN LATERAL (VALUES (col1), (col2)) AS unnested(val)
```

### Date arithmetic
```sql
-- SQL Server                          -- Greenplum
DATEADD(DAY, 91, anchor_date)         anchor_date + 91
DATEADD(MONTH, 3, anchor_date)        (anchor_date + INTERVAL '3 months')::date
DATEADD(YEAR, 1, anchor_date)         (anchor_date + INTERVAL '1 year')::date
DATEDIFF(day, d1, d2)                 (d2 - d1)   -- returns integer
DATEDIFF(MONTH, d1, d2)               (DATE_PART('year',d2)-DATE_PART('year',d1))*12
                                        + DATE_PART('month',d2)-DATE_PART('month',d1)
DATEFROMPARTS(y, m, d)                MAKE_DATE(y::int, m::int, d)
YEAR(date)                            EXTRACT(YEAR FROM date)
```

### Null handling / string functions
```sql
-- SQL Server          -- Greenplum
ISNULL(x, y)          COALESCE(x, y)
SUBSTRING(s, 1, n)    SUBSTRING(s FROM 1 FOR n)
CHECKSUM(col)         HASHTEXT(col)   -- for tie-breaking only
```

### Procedural loops
```sql
-- SQL Server: DECLARE @i INT; WHILE @i <= 7 BEGIN ... SET @i = @i + 1; END
-- Greenplum:  DO $$ BEGIN FOR i IN 1..7 LOOP ... END LOOP; END; $$;
```

### DELETE with alias
```sql
-- SQL Server
DELETE a FROM my_table a WHERE EXISTS (...)

-- Greenplum
DELETE FROM my_table WHERE (key_col) IN (SELECT key_col FROM my_table WHERE ...)
```

### ORDER BY in CREATE TABLE AS
Removed — Greenplum does not guarantee order in heap tables. Add `ORDER BY` to downstream queries as needed.

---

## RX table consolidation (`02_make_smaller_tables.sql`)

The SQL Server version unioned 22 per-fiscal-year RX tables (`MCO_RX_FY18`…`FY24`, `FFS_RX_FY18`…`FY24`, etc.).
In Greenplum these are pre-appended as four tables, so the query is simply:

```sql
SELECT ... FROM medicaid.mco_rx
UNION ALL SELECT ... FROM medicaid.ffs_rx
UNION ALL SELECT ... FROM medicaid.chip_rx
UNION ALL SELECT ... FROM medicaid.htw_ffs_rx
```

---

## Tables referenced but not in DDL — verify schema before running

The following tables are joined in the code but were not in the provided DDL export.
Confirm their schema/name in the Greenplum database:

| Table                        | Used in file            | Likely schema |
|------------------------------|-------------------------|---------------|
| `poem_comorbid_index`        | `covariates_v03.sql`    | `dev`         |
| `poem_covariates_dx`         | `covariates_v03.sql`    | `dev`         |
| `poem_mh_dx`                 | `covariates_v03.sql`    | `dev`         |
| `poem_codes_any_out`         | `03_outcomes.sql`       | `dev`         |
| `lu_contract`                | `01_extract_all_claims` | `medicaid`    |
| `ndc_tier_map`               | `03_outcomes.sql`       | `ref`         |
| `zip_zcta_all_years`         | `01_extract_all_claims` | `ref`         |
| `enc_det` (tdos_csl column)  | `02_make_smaller_tables`, `03_outcomes` | `medicaid` |

> **Note on `enc_det`:** The Greenplum DDL shows `medicaid.enc_det` with column `tdos_csl varchar`.
> The SQL Server code referenced a pre-processed `enc_detail` view with `to_date` as an aliased date column.
> The converted code reads directly from `medicaid.enc_det` and casts `tdos_csl::date` inline.
