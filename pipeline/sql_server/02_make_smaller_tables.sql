/* ------------------------------
 * Make table of procedure codes 
 */ -----------------------------

drop table if exists CHCDWORK.dbo.poem_cohort_cpt ;

with get_all as (
select pcn as client_nbr, a.icn as clm_id, to_dos, proc_cd, taxonomy_cd, 
       proc_mod_1, proc_mod_2, proc_mod_3, proc_mod_4, proc_mod_5, 
       pos, rev_cd
  from CHCDWORK.dbo.clm_detail a 
  join chcdwork.dbo.clm_proc b 
   on b.icn = a.icn
 union all 
 select mem_id as client_nbr, a.derv_enc as clm_id, to_date, proc_cd, taxonomy_cd,
       proc_mod_1, proc_mod_2, proc_mod_3, proc_mod_4, proc_mod_5, 
       pos, rev_cd
  from CHCDWORK.dbo.enc_detail a 
  join chcdwork.dbo.enc_proc b 
   on b.derv_enc = a.derv_enc
   )
   select distinct a.*
     into CHCDWORK.dbo.poem_cohort_cpt 
     from get_all a 
     join chcdwork.dbo.poem_cohort b 
       on a.client_nbr = b.client_nbr
 ;
 

select * from CHCDWORK.dbo.poem_cohort_cpt ;

/*
 * Make smaller DX Table 
 */

--- 
drop table if exists chcdwork.dbo.poem_cohort_dx;

with get_dx as (
    select
        trim(b.icn) as icn,
        trim(b.pcn) as pcn ,
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
select distinct a.pcn as client_nbr,
       icn as clm_id,
       a.hdr_frm_dos as clm_from_date,
       a.dx_cd
  into chcdwork.dbo.poem_cohort_dx
  from get_dx a
  join chcdwork.dbo.poem_cohort b 
     on b.client_nbr = a.pcn
  where dx_cd <> '';
 
 
 --- then enc 
 with get_dx as (
    select
        trim(b.mem_id) as mem_id,
        trim(b.derv_enc) as derv_enc ,
        cast(d.frm_dos as date) as frm_dos,
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
insert into chcdwork.dbo.poem_cohort_dx
select distinct a.mem_id as client_nbr,
       derv_enc as clm_id,
       a.frm_dos as clm_from_date,
       a.dx_cd
  from get_dx a
  join chcdwork.dbo.poem_cohort b 
     on b.client_nbr = a.mem_id
  where dx_cd <> '';
 
 
 select * from chcdwork.dbo.poem_cohort_dx;


------------------------------------------------
-- RX
------------------------------------------------

drop table if exists CHCDWORK.dbo.poem_rx;

select distinct a.* 
into CHCDWORK.dbo.poem_rx from (
select trim(pcn) as client_nbr,  cast(RX_FILL_DT as date) as fill_dt, 
       trim(NDC) as ndc 
  from MEDICAID.dbo.MCO_RX_FY18
union all 
select trim(pcn) as client_nbr,  cast(RX_FILL_DT as date) as to_dosfrom, 
       trim(NDC) as ndc 
  from MEDICAID.dbo.MCO_RX_FY19
union all 
select trim(pcn) as client_nbr,  cast(RX_FILL_DT as date) as to_dosfrom, 
       trim(NDC) as ndc 
  from MEDICAID.dbo.MCO_RX_FY20
union all 
select trim(pcn) as client_nbr,  cast(RX_FILL_DT as date) as to_dosfrom, 
       trim(NDC) as ndc 
  from MEDICAID.dbo.MCO_RX_FY21
union all 
select trim(pcn) as client_nbr,  cast(RX_FILL_DT as date) as to_dosfrom, 
       trim(NDC) as ndc 
  from MEDICAID.dbo.MCO_RX_FY22
union all 
select trim(pcn) as client_nbr,  cast(RX_FILL_DT as date) as to_dosfrom, 
       trim(NDC) as ndc 
  from MEDICAID.dbo.MCO_RX_FY23
  union all 
select trim(pcn) as client_nbr,  cast(RX_FILL_DT as date) as to_dosfrom, 
       trim(NDC) as ndc 
  from MEDICAID.dbo.MCO_RX_FY24
union all 
select trim(pcn) as client_nbr,  cast(RX_FILL_DT as date) as fill_dt, 
       trim(NDC) as ndc 
  from MEDICAID.dbo.FFS_RX_FY18
union all 
select trim(pcn) as client_nbr,  cast(RX_FILL_DT as date) as to_dosfrom, 
       trim(NDC) as ndc 
  from MEDICAID.dbo.FFS_RX_FY19
union all 
select trim(pcn) as client_nbr,  cast(RX_FILL_DT as date) as to_dosfrom, 
       trim(NDC) as ndc 
  from MEDICAID.dbo.FFS_RX_FY20
union all 
select trim(pcn) as client_nbr,  cast(RX_FILL_DT as date) as to_dosfrom, 
       trim(NDC) as ndc 
  from MEDICAID.dbo.FFS_RX_FY21
union all 
select trim(pcn) as client_nbr,  cast(RX_FILL_DT as date) as to_dosfrom, 
       trim(NDC) as ndc 
  from MEDICAID.dbo.FFS_RX_FY22
union all 
select trim(pcn) as client_nbr,  cast(RX_FILL_DT as date) as to_dosfrom, 
       trim(NDC) as ndc 
  from MEDICAID.dbo.FFS_RX_FY23
  union all 
select trim(pcn) as client_nbr,  cast(RX_FILL_DT as date) as to_dosfrom, 
       trim(NDC) as ndc 
  from MEDICAID.dbo.FFS_RX_FY24
union all 
select trim(pcn) as client_nbr,  cast(RX_FILL_DT as date) as to_dosfrom, 
       trim(NDC) as ndc 
  from MEDICAID.dbo.FFS_RX_FY18_19_HTW
union all 
select trim(pcn) as client_nbr,  cast(RX_FILL_DT as date) as fill_dt, 
       trim(NDC) as ndc 
  from MEDICAID.dbo.CHIP_RX_FY18
union all 
select trim(pcn) as client_nbr,  cast(RX_FILL_DT as date) as to_dosfrom, 
       trim(NDC) as ndc 
  from MEDICAID.dbo.CHIP_RX_FY19
union all 
select trim(pcn) as client_nbr,  cast(RX_FILL_DT as date) as to_dosfrom, 
       trim(NDC) as ndc 
  from MEDICAID.dbo.CHIP_RX_FY20
union all 
select trim(pcn) as client_nbr,  cast(RX_FILL_DT as date) as to_dosfrom, 
       trim(NDC) as ndc 
  from MEDICAID.dbo.CHIP_RX_FY21
union all 
select trim(pcn) as client_nbr,  cast(RX_FILL_DT as date) as to_dosfrom, 
       trim(NDC) as ndc 
  from MEDICAID.dbo.CHIP_RX_FY22
union all 
select trim(pcn) as client_nbr,  cast(RX_FILL_DT as date) as to_dosfrom, 
       trim(NDC) as ndc 
  from MEDICAID.dbo.CHIP_RX_FY23
union all 
select trim(pcn) as client_nbr,  cast(RX_FILL_DT as date) as to_dosfrom, 
       trim(NDC) as ndc 
  from MEDICAID.dbo.CHIP_RX_FY24
  ) a 
  join chcdwork.dbo.poem_cohort b 
     on a.client_nbr = b.client_nbr;
    
-----------------------    
    --- ICD Codes
-----------------------
    
drop table if exists chcdwork.dbo.poem_cohort_icd;

with get_icd as (
    select
        trim(b.pcn) as pcn ,
        cast(d.hdr_frm_dos as date) as hdr_frm_dos,
        cast(d.hdr_to_dos as date) as hdr_to_dos,
        trim(icd_cd) as icd_cd
    from chcdwork.dbo.clm_proc b 
    join chcdwork.dbo.clm_header d on d.icn = b.icn
    cross apply (
        values
            (rtrim(b.proc_icd_cd_1)), (rtrim(b.proc_icd_cd_2)),  (rtrim(b.proc_icd_cd_3)),
            (rtrim(b.proc_icd_cd_4)), (rtrim(b.proc_icd_cd_5)), (rtrim(b.proc_icd_cd_6)), (rtrim(b.proc_icd_cd_7)),
            (rtrim(b.proc_icd_cd_8)), (rtrim(b.proc_icd_cd_9)), (rtrim(b.proc_icd_cd_10)), (rtrim(b.proc_icd_cd_11)),
            (rtrim(b.proc_icd_cd_12)),  (rtrim(b.proc_icd_cd_13)), (rtrim(b.proc_icd_cd_14)), (rtrim(b.proc_icd_cd_15)),
            (rtrim(b.proc_icd_cd_16)), (rtrim(b.proc_icd_cd_17)),(rtrim(b.proc_icd_cd_18)), (rtrim(b.proc_icd_cd_19)),
            (rtrim(b.proc_icd_cd_20)), (rtrim(b.proc_icd_cd_21)), (rtrim(b.proc_icd_cd_22)), (rtrim(b.proc_icd_cd_23)),
            (rtrim(b.proc_icd_cd_24)), (rtrim(b.proc_icd_cd_25))
    ) as unnested(icd_cd)
    where year(cast(d.hdr_frm_dos as date)) > 2018
)
select distinct a.pcn as client_nbr,
       a.hdr_frm_dos as clm_from_date,
       a.icd_cd
  into chcdwork.dbo.poem_cohort_icd
  from get_icd a
  join chcdwork.dbo.poem_cohort b 
     on b.client_nbr = a.pcn
     where icd_cd <> ''
  ;
 
 
 --- then enc 
 with get_dx as (
    select
        trim(b.mem_id) as mem_id,
        cast(d.frm_dos as date) as frm_dos,
        icd_cd
    from  chcdwork.dbo.enc_proc b 
    join chcdwork.dbo.enc_header d 
      on d.derv_enc = b.derv_enc
    cross apply (
        values
            (rtrim(b.proc_icd_cd_1)), (rtrim(b.proc_icd_cd_2)),  (rtrim(b.proc_icd_cd_3)),
            (rtrim(b.proc_icd_cd_4)), (rtrim(b.proc_icd_cd_5)), (rtrim(b.proc_icd_cd_6)), (rtrim(b.proc_icd_cd_7)),
            (rtrim(b.proc_icd_cd_8)), (rtrim(b.proc_icd_cd_9)), (rtrim(b.proc_icd_cd_10)), (rtrim(b.proc_icd_cd_11)),
            (rtrim(b.proc_icd_cd_12)),  (rtrim(b.proc_icd_cd_13)), (rtrim(b.proc_icd_cd_14)), (rtrim(b.proc_icd_cd_15)),
            (rtrim(b.proc_icd_cd_16)), (rtrim(b.proc_icd_cd_17)),(rtrim(b.proc_icd_cd_18)), (rtrim(b.proc_icd_cd_19)),
            (rtrim(b.proc_icd_cd_20)), (rtrim(b.proc_icd_cd_21)), (rtrim(b.proc_icd_cd_22)), (rtrim(b.proc_icd_cd_23)),
            (rtrim(b.proc_icd_cd_24))
    ) as unnested(icd_cd)
    where year(cast(d.frm_dos as date)) > 2018
)
insert into chcdwork.dbo.poem_cohort_icd
select distinct a.mem_id as client_nbr,
       a.frm_dos as clm_from_date,
       a.icd_cd
  from get_dx a
  join chcdwork.dbo.poem_cohort b 
     on b.client_nbr = a.mem_id
  where icd_cd <> '';
 
 
 select * from chcdwork.dbo.poem_cohort_icd;
