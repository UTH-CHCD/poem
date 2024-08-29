drop table if exists CHCDWORK.dbo.poem_codeset_births;

CREATE TABLE CHCDWORK.dbo.poem_codeset_births (
    outcome_type VARCHAR(50),
    cd VARCHAR(50),
    code_type VARCHAR(50),
    definition VARCHAR(255),
    sb_flag INT,
    multiple_flag INT
);

INSERT INTO CHCDWORK.dbo.poem_codeset_births (outcome_type, cd, code_type, definition, sb_flag, multiple_flag) VALUES
('LB', 'Z370', 'ICD10CM', 'Single live birth', 0, 0),
('LB', 'Z372', 'ICD10CM', 'Twins, both liveborn', 0, 0),
('LB', 'Z3750', 'ICD10CM', 'Multiple births, unspecified, all liveborn', 0, 0),
('LB', 'Z3751', 'ICD10CM', 'Triplets, all liveborn', 0, 0),
('LB', 'Z3752', 'ICD10CM', 'Quadruplets, all liveborn', 0, 0),
('LB', 'Z3753', 'ICD10CM', 'Quintuplets, all liveborn', 0, 0),
('LB', 'Z3754', 'ICD10CM', 'Sextuplets, all liveborn', 0, 0),
('LB', 'Z3759', 'ICD10CM', 'Other multiple births, all liveborn', 0, 0),
('LB', 'O80', 'ICD10CM', 'Encounter for full-term uncomplicated delivery', 0, 0),
('LB', 'Z373', 'ICD10CM', 'Twins, one liveborn and one stillborn', 0, 1),
('LB', 'Z3760', 'ICD10CM', 'Multiple births, unspecified, some liveborn', 0, 1),
('LB', 'Z3761', 'ICD10CM', 'Triplets, some liveborn', 0, 1),
('LB', 'Z3762', 'ICD10CM', 'Quadruplets, some liveborn', 0, 1),
('LB', 'Z3763', 'ICD10CM', 'Quintuplets, some liveborn', 0, 1),
('LB', 'Z3764', 'ICD10CM', 'Sextuplets, some liveborn', 0, 1),
('SB', 'Z371', 'ICD10CM', 'Single stillbirth', 1, 0),
('SB', 'Z374', 'ICD10CM', 'Twins, both stillborn', 1, 1),
('SB', 'Z377', 'ICD10CM', 'Other multiple births, all stillborn', 1, 1),
('SB', 'O364XX0', 'ICD10CM', 'Maternal care for intrauterine death, not applicable or unspecified', 1, 1),
('SB', 'O364XX1', 'ICD10CM', 'Maternal care for intrauterine death, fetus 1', 1, 1),
('SB', 'O364XX2', 'ICD10CM', 'Maternal care for intrauterine death, fetus 2', 1, 1),
('SB', 'O364XX3', 'ICD10CM', 'Maternal care for intrauterine death, fetus 3', 1, 1),
('SB', 'O364XX4', 'ICD10CM', 'Maternal care for intrauterine death, fetus 4', 1, 1),
('SB', 'O364XX5', 'ICD10CM', 'Maternal care for intrauterine death, fetus 5', 1, 1),
('SB', 'O364XX9', 'ICD10CM', 'Maternal care for intrauterine death, other fetus', 1, 1);


--- Delivery Codeset

DROP TABLE IF EXISTS chcdwork.dbo.poem_codeset_delivery;

CREATE TABLE chcdwork.dbo.poem_codeset_delivery (
    code_set VARCHAR(50) NOT NULL,
    code VARCHAR(50) NOT NULL,
    description VARCHAR(255) NOT NULL,
    cd_cleaned VARCHAR(50) NOT NULL
);

INSERT INTO chcdwork.dbo.poem_codeset_delivery (code_set, code, description, cd_cleaned) VALUES
('CPT', '59400', 'Routine obstetric care including antepartum care, vaginal delivery (with or without episiotomy, and/or forceps) and postpartum care', '59400'),
('CPT', '59409', 'Vaginal delivery only (with or without episiotomy and/or forceps)', '59409'),
('CPT', '59410', 'Vaginal delivery only (with or without episiotomy and/or forceps) including postpartum care', '59410'),
('CPT', '59510', 'Routine obstetric care including antepartum care, cesarean delivery and postpartum care', '59510'),
('CPT', '59514', 'Cesarean delivery only', '59514'),
('CPT', '59515', 'Cesarean delivery only including postpartum care', '59515'),
('CPT', '59610', 'Routine obstetric care including antepartum care, vaginal delivery (with or without episiotomy and/or forceps) and postpartum care, after previous cesarean delivery', '59610'),
('CPT', '59612', 'Vaginal delivery only, after previous cesarean delivery (with or without episiotomy and/or forceps)', '59612'),
('CPT', '59614', 'Vaginal delivery only, after previous cesarean delivery (with or without episiotomy and/or forceps) including postpartum care', '59614'),
('CPT', '59618', 'Routine obstetric care including antepartum care, cesarean delivery and postpartum care, following attempted vaginal delivery after previous cesarean delivery', '59618'),
('CPT', '59620', 'Cesarean delivery only, following attempted vaginal delivery after previous cesarean delivery', '59620'),
('CPT', '59622', 'Cesarean delivery only, following attempted vaginal delivery after previous cesarean delivery including postpartum care', '59622'),
('ICD10PCS', '10D00Z0', 'Extraction of Products of Conception, Classical, Open Approach', '10D00Z0'),
('ICD10PCS', '10D00Z1', 'Extraction of Products of Conception, Low Cervical, Open Approach', '10D00Z1'),
('ICD10PCS', '10D00Z2', 'Extraction of Products of Conception, Extraperitoneal, Open Approach', '10D00Z2'),
('ICD10PCS', '10D07Z3', 'Extraction of Products of Conception, Low Forceps, Via Natural or Artificial Opening', '10D07Z3'),
('ICD10PCS', '10D07Z4', 'Extraction of Products of Conception, Mid Forceps, Via Natural or Artificial Opening', '10D07Z4'),
('ICD10PCS', '10D07Z5', 'Extraction of Products of Conception, High Forceps, Via Natural or Artificial Opening', '10D07Z5'),
('ICD10PCS', '10D07Z6', 'Extraction of Products of Conception, Vacuum, Via Natural or Artificial Opening', '10D07Z6'),
('ICD10PCS', '10D07Z7', 'Extraction of Products of Conception, Internal Version, Via Natural or Artificial Opening', '10D07Z7'),
('ICD10PCS', '10D07Z8', 'Extraction of Products of Conception, Other, Via Natural or Artificial Opening', '10D07Z8'),
('ICD10PCS', '10E0XZZ', 'Delivery of Products of Conception, External Approach', '10E0XZZ'),
('ICD10PCS', '10A00ZZ', 'Abortion of Products of Conception, Open Approach', '10A00ZZ'),
('ICD10PCS', '10A03ZZ', 'Abortion of Products of Conception, Percutaneous Approach', '10A03ZZ'),
('ICD10PCS', '10A04ZZ', 'Abortion of Products of Conception, Percutaneous Endoscopic Approach', '10A04ZZ'),
('ICD10PCS', '10A07Z6', 'Abortion of Products of Conception, Vacuum, Via Natural or Artificial Opening', '10A07Z6'),
('ICD10PCS', '10A07ZW', 'Abortion of Products of Conception, Laminaria, Via Natural or Artificial Opening', '10A07ZW'),
('ICD10PCS', '10A07ZX', 'Abortion of Products of Conception, Abortifacient, Via Natural or Artificial Opening', '10A07ZX'),
('ICD10PCS', '10A07ZZ', 'Abortion of Products of Conception, Via Natural or Artificial Opening', '10A07ZZ'),
('ICD10PCS', '10A08ZZ', 'Abortion of Products of Conception, Via Natural or Artificial Opening Endoscopic', '10A08ZZ'),
('ICD10PCS', '10D20ZZ', 'Extraction of Products of Conception, Ectopic, Open Approach', '10D20ZZ'),
('ICD10PCS', '10D24ZZ', 'Extraction of Products of Conception, Ectopic, Percutaneous Endoscopic Approach', '10D24ZZ'),
('ICD10PCS', '10D27ZZ', 'Extraction of Products of Conception, Ectopic, Via Natural or Artificial Opening', '10D27ZZ'),
('ICD10PCS', '10D28ZZ', 'Extraction of Products of Conception, Ectopic, Via Natural or Artificial Opening Endoscopic', '10D28ZZ'),
('ICD10PCS', '10J20ZZ', 'Inspection of Products of Conception, Ectopic, Open Approach', '10J20ZZ'),
('ICD10PCS', '10J23ZZ', 'Inspection of Products of Conception, Ectopic, Percutaneous Approach', '10J23ZZ'),
('ICD10PCS', '10J24ZZ', 'Inspection of Products of Conception, Ectopic, Percutaneous Endoscopic Approach', '10J24ZZ'),
('ICD10PCS', '10J27ZZ', 'Inspection of Products of Conception, Ectopic, Via Natural or Artificial Opening Endoscopic', '10J27ZZ'),
('ICD10PCS', '10J2XZZ', 'Inspection of Products of Conception, Ectopic, External Approach', '10J2XZZ'),
('ICD10PCS', '10S20ZZ', 'Reposition Products of Conception, Ectopic, Open Approach', '10S20ZZ'),
('ICD10PCS', '10S23ZZ', 'Reposition Products of Conception, Ectopic, Percutaneous Approach', '10S23ZZ'),
('ICD10PCS', '10S24ZZ', 'Reposition Products of Conception, Ectopic, Percutaneous Endoscopic Approach', '10S24ZZ'),
('ICD10PCS', '10S27ZZ', 'Reposition Products of Conception, Ectopic, Via Natural or Artificial Opening', '10S27ZZ'),
('ICD10PCS', '10S28ZZ', 'Reposition Products of Conception, Ectopic, Via Natural or Artificial Opening Endoscopic', '10S28ZZ'),
('ICD10PCS', '10T20ZZ', 'Resection of Products of Conception, Ectopic, Open Approach', '10T20ZZ'),
('ICD10PCS', '10T23ZZ', 'Resection of Products of Conception, Ectopic, Percutaneous Approach', '10T23ZZ'),
('ICD10PCS', '10T24ZZ', 'Resection of Products of Conception, Ectopic, Percutaneous Endoscopic Approach', '10T24ZZ'),
('ICD10PCS', '10T27ZZ', 'Resection of Products of Conception, Ectopic, Via Natural or Artificial Opening', '10T27ZZ'),
('ICD10PCS', '10T28ZZ', 'Resection of Products of Conception, Ectopic, Via Natural or Artificial Opening Endoscopic', '10T28ZZ');
