--------------------------
--- make appended tables--
-------------------------- 

---clm are smaller, hence why i select * there 

drop table if exists CHCDWORK.dbo.clm_dx;

select * 
into CHCDWORK.dbo.clm_dx
from 
(
select * from MEDICAID.dbo.CLM_DX_19 
union all 
select * from MEDICAID.dbo.CLM_DX_20
union all 
select * from MEDICAID.dbo.CLM_DX_21
union all
select * from MEDICAID.dbo.CLM_DX_22
union all 
select * from MEDICAID.dbo.CLM_DX_23
) a ;

update statistics CHCDWORK.dbo.clm_dx;

--- 

drop table if exists CHCDWORK.dbo.clm_header;

select * 
into CHCDWORK.dbo.clm_header
from 
(
select * from MEDICAID.dbo.CLM_HEADER_19 
union all 
select * from MEDICAID.dbo.CLM_HEADER_20
union all 
select * from MEDICAID.dbo.CLM_HEADER_21
union all
select * from MEDICAID.dbo.CLM_HEADER_22
union all 
select * from MEDICAID.dbo.CLM_HEADER_23
) a;

update statistics CHCDWORK.dbo.clm_header;

---
drop table if exists CHCDWORK.dbo.clm_proc;

select * 
into CHCDWORK.dbo.clm_proc
from 
(
select * from MEDICAID.dbo.CLM_PROC_19 
union all 
select * from MEDICAID.dbo.CLM_PROC_20
union all 
select * from MEDICAID.dbo.CLM_PROC_21
union all
select * from MEDICAID.dbo.CLM_PROC_22
union all 
select * from MEDICAID.dbo.CLM_PROC_23
) a;

update statistics CHCDWORK.dbo.clm_proc;

----------- ENCOUNTERS ----------------------------------------------------
-- encounters table much bigger than clm, have to be selective what you grab 

--dx
drop table if exists CHCDWORK.dbo.enc_dx;

select * 
into CHCDWORK.dbo.enc_dx
from 
(
select DERV_ENC, PRIM_DX_CD, DX_CD_1, DX_CD_2, DX_CD_3, DX_CD_4, 
DX_CD_5, DX_CD_6, DX_CD_7, DX_CD_8, DX_CD_9, 
DX_CD_10, DX_CD_11, DX_CD_12, DX_CD_13, DX_CD_14, DX_CD_15, 
DX_CD_16, DX_CD_17, DX_CD_18, DX_CD_19, DX_CD_20, DX_CD_21, DX_CD_22,
DX_CD_23, DX_CD_24
from MEDICAID.dbo.ENC_DX_19 
union all 
select DERV_ENC, PRIM_DX_CD, DX_CD_1, DX_CD_2, DX_CD_3, DX_CD_4, 
DX_CD_5, DX_CD_6, DX_CD_7, DX_CD_8, DX_CD_9, 
DX_CD_10, DX_CD_11, DX_CD_12, DX_CD_13, DX_CD_14, DX_CD_15, 
DX_CD_16, DX_CD_17, DX_CD_18, DX_CD_19, DX_CD_20, DX_CD_21, DX_CD_22,
DX_CD_23, DX_CD_24
from MEDICAID.dbo.ENC_DX_20
union all 
select DERV_ENC, PRIM_DX_CD, DX_CD_1, DX_CD_2, DX_CD_3, DX_CD_4, 
DX_CD_5, DX_CD_6, DX_CD_7, DX_CD_8, DX_CD_9, 
DX_CD_10, DX_CD_11, DX_CD_12, DX_CD_13, DX_CD_14, DX_CD_15, 
DX_CD_16, DX_CD_17, DX_CD_18, DX_CD_19, DX_CD_20, DX_CD_21, DX_CD_22,
DX_CD_23, DX_CD_24
from MEDICAID.dbo.ENC_DX_21
union all
select DERV_ENC, PRIM_DX_CD, DX_CD_1, DX_CD_2, DX_CD_3, DX_CD_4, 
DX_CD_5, DX_CD_6, DX_CD_7, DX_CD_8, DX_CD_9, 
DX_CD_10, DX_CD_11, DX_CD_12, DX_CD_13, DX_CD_14, DX_CD_15, 
DX_CD_16, DX_CD_17, DX_CD_18, DX_CD_19, DX_CD_20, DX_CD_21, DX_CD_22,
DX_CD_23, DX_CD_24
from MEDICAID.dbo.ENC_DX_22
union all 
select DERV_ENC, PRIM_DX_CD, DX_CD_1, DX_CD_2, DX_CD_3, DX_CD_4, 
DX_CD_5, DX_CD_6, DX_CD_7, DX_CD_8, DX_CD_9, 
DX_CD_10, DX_CD_11, DX_CD_12, DX_CD_13, DX_CD_14, DX_CD_15, 
DX_CD_16, DX_CD_17, DX_CD_18, DX_CD_19, DX_CD_20, DX_CD_21, DX_CD_22,
DX_CD_23, DX_CD_24
from MEDICAID.dbo.ENC_DX_23
) a ;

update statistics CHCDWORK.dbo.ENC_dx;

-- header 
drop table if exists CHCDWORK.dbo.enc_header;

select *
into CHCDWORK.dbo.enc_header
from 
(
select derv_enc, adm_dt, dis_dt, frm_dos, to_dos, pat_stat  from MEDICAID.dbo.ENC_HEADER_19 
union all 
select derv_enc, adm_dt, dis_dt, frm_dos, to_dos, pat_stat from MEDICAID.dbo.ENC_HEADER_20
union all 
select derv_enc, adm_dt, dis_dt, frm_dos, to_dos, pat_stat from MEDICAID.dbo.ENC_HEADER_21
union all
select derv_enc, adm_dt, dis_dt, frm_dos, to_dos, pat_stat from MEDICAID.dbo.ENC_HEADER_22
union all 
select derv_enc, adm_dt, dis_dt, frm_dos, to_dos, pat_stat from MEDICAID.dbo.ENC_HEADER_23
) a;

update statistics CHCDWORK.dbo.enc_header;


-- proc 
drop table if exists CHCDWORK.dbo.enc_proc;

select *
into CHCDWORK.dbo.enc_proc
from 
(
select mem_id, derv_enc, PRIM_PROC_CD, PROC_ICD_CD_1, PROC_ICD_CD_2, PROC_ICD_CD_3, PROC_ICD_CD_4, 
PROC_ICD_CD_5, PROC_ICD_CD_6, PROC_ICD_CD_7, PROC_ICD_CD_8, PROC_ICD_CD_9, 
PROC_ICD_CD_10, PROC_ICD_CD_11, PROC_ICD_CD_12, PROC_ICD_CD_13, PROC_ICD_CD_14, PROC_ICD_CD_15, 
PROC_ICD_CD_16, PROC_ICD_CD_17, PROC_ICD_CD_18, PROC_ICD_CD_19, PROC_ICD_CD_20, PROC_ICD_CD_21, PROC_ICD_CD_22,
PROC_ICD_CD_23, PROC_ICD_CD_24, bill
  from MEDICAID.dbo.ENC_PROC_19 
union all 
select mem_id, derv_enc, PRIM_PROC_CD,PROC_ICD_CD_1, PROC_ICD_CD_2, PROC_ICD_CD_3, PROC_ICD_CD_4, 
PROC_ICD_CD_5, PROC_ICD_CD_6, PROC_ICD_CD_7, PROC_ICD_CD_8, PROC_ICD_CD_9, 
PROC_ICD_CD_10, PROC_ICD_CD_11, PROC_ICD_CD_12, PROC_ICD_CD_13, PROC_ICD_CD_14, PROC_ICD_CD_15, 
PROC_ICD_CD_16, PROC_ICD_CD_17, PROC_ICD_CD_18, PROC_ICD_CD_19, PROC_ICD_CD_20, PROC_ICD_CD_21, PROC_ICD_CD_22,
PROC_ICD_CD_23, PROC_ICD_CD_24, bill
from MEDICAID.dbo.ENC_PROC_20
union all 
select mem_id, derv_enc, PRIM_PROC_CD, PROC_ICD_CD_1, PROC_ICD_CD_2, PROC_ICD_CD_3, PROC_ICD_CD_4, 
PROC_ICD_CD_5, PROC_ICD_CD_6, PROC_ICD_CD_7, PROC_ICD_CD_8, PROC_ICD_CD_9, 
PROC_ICD_CD_10, PROC_ICD_CD_11, PROC_ICD_CD_12, PROC_ICD_CD_13, PROC_ICD_CD_14, PROC_ICD_CD_15, 
PROC_ICD_CD_16, PROC_ICD_CD_17, PROC_ICD_CD_18, PROC_ICD_CD_19, PROC_ICD_CD_20, PROC_ICD_CD_21, PROC_ICD_CD_22,
PROC_ICD_CD_23, PROC_ICD_CD_24, bill
from MEDICAID.dbo.ENC_PROC_21
union all
select mem_id, derv_enc , PRIM_PROC_CD, PROC_ICD_CD_1, PROC_ICD_CD_2, PROC_ICD_CD_3, PROC_ICD_CD_4, 
PROC_ICD_CD_5, PROC_ICD_CD_6, PROC_ICD_CD_7, PROC_ICD_CD_8, PROC_ICD_CD_9, 
PROC_ICD_CD_10, PROC_ICD_CD_11, PROC_ICD_CD_12, PROC_ICD_CD_13, PROC_ICD_CD_14, PROC_ICD_CD_15, 
PROC_ICD_CD_16, PROC_ICD_CD_17, PROC_ICD_CD_18, PROC_ICD_CD_19, PROC_ICD_CD_20, PROC_ICD_CD_21, PROC_ICD_CD_22,
PROC_ICD_CD_23, PROC_ICD_CD_24, bill
from MEDICAID.dbo.ENC_PROC_22
union all 
select mem_id, derv_enc, PRIM_PROC_CD, PROC_ICD_CD_1, PROC_ICD_CD_2, PROC_ICD_CD_3, PROC_ICD_CD_4, 
PROC_ICD_CD_5, PROC_ICD_CD_6, PROC_ICD_CD_7, PROC_ICD_CD_8, PROC_ICD_CD_9, 
PROC_ICD_CD_10, PROC_ICD_CD_11, PROC_ICD_CD_12, PROC_ICD_CD_13, PROC_ICD_CD_14, PROC_ICD_CD_15, 
PROC_ICD_CD_16, PROC_ICD_CD_17, PROC_ICD_CD_18, PROC_ICD_CD_19, PROC_ICD_CD_20, PROC_ICD_CD_21, PROC_ICD_CD_22,
PROC_ICD_CD_23, PROC_ICD_CD_24, bill
from MEDICAID.dbo.ENC_PROC_23
) a;

update statistics CHCDWORK.dbo.enc_proc;

---------------------------------------------
--- Enrollment Tables  ----------------------
---------------------------------------------

--- enrl 
drop table if exists CHCDWORK.dbo.enrl;

select * 
into CHCDWORK.dbo.enrl
from 
(
select * from MEDICAID.dbo.ENRL_2019 
union all 
select * from MEDICAID.dbo.ENRL_2020
union all 
select * from MEDICAID.dbo.ENRL_2021
union all
select * from MEDICAID.dbo.ENRL_2022
union all 
select * from MEDICAID.dbo.ENRL_2023
) a
where sex = 'F';


---chip enrl
drop table if exists CHCDWORK.dbo.chip_enrl;

select * 
into CHCDWORK.dbo.chip_enrl
from 
(
select * from MEDICAID.dbo.CHIP_ENRL_FY19 
union all 
select * from MEDICAID.dbo.CHIP_ENRL_FY20
union all 
select * from MEDICAID.dbo.CHIP_ENRL_FY21
union all
select * from MEDICAID.dbo.CHIP_ENRL_FY22
union all 
select * from MEDICAID.dbo.CHIP_ENRL_FY23
) a 
where gender_cd = 'F';


select * from CHCDWORK.dbo.enrl;


---------------------------------------------
--- Detail Tables  ----------------------
---------------------------------------------

drop table if exists CHCDWORK.dbo.clm_detail;

select trim(icn) as icn, 
       cast(TO_DOS as date) as to_dos, 
       trim(PROC_CD) as proc_cd
into  CHCDWORK.dbo.clm_detail
from (
select icn, TO_DOS, PROC_CD  from MEDICAID.dbo.CLM_DETAIL_19
union all 
select icn, TO_DOS, PROC_CD  from MEDICAID.dbo.CLM_DETAIL_20
union all
select icn, TO_DOS, PROC_CD  from MEDICAID.dbo.CLM_DETAIL_21
union all
select icn, TO_DOS, PROC_CD  from MEDICAID.dbo.CLM_DETAIL_22
union all
select icn, TO_DOS, PROC_CD  from MEDICAID.dbo.CLM_DETAIL_23
) a
where proc_cd <> ''
;

--- enc 
drop table if exists CHCDWORK.dbo.enc_detail;


select trim(derv_enc) as derv_enc, 
       cast(TDOS_CSL as date) as to_date, 
       trim(PROC_CD) as proc_cd
into  CHCDWORK.dbo.enc_detail
from (
select derv_enc, TDOS_CSL, PROC_CD  from MEDICAID.dbo.ENC_DET_19
union all 
select derv_enc, TDOS_CSL, PROC_CD  from MEDICAID.dbo.ENC_DET_20
union all
select derv_enc, TDOS_CSL, PROC_CD  from MEDICAID.dbo.ENC_DET_21
union all
select derv_enc, TDOS_CSL, PROC_CD  from MEDICAID.dbo.ENC_DET_22
union all
select derv_enc, TDOS_CSL, PROC_CD  from MEDICAID.dbo.ENC_DET_23
) a
where proc_cd <> ''
;

