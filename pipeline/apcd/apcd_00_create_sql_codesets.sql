DROP TABLE IF EXISTS research_dev.poem_codeset_births;

CREATE TABLE research_dev.poem_codeset_births (
    outcome_type   VARCHAR(50),
    cd             VARCHAR(50),
    code_type      VARCHAR(50),
    definition     VARCHAR(255),
    sb_flag        INTEGER,
    multiple_flag  INTEGER
);

INSERT INTO research_dev.poem_codeset_births
    (outcome_type, cd, code_type, definition, sb_flag, multiple_flag)
VALUES
('LB', 'Z370',   'ICD10CM', 'Single live birth', 0, 0),
('LB', 'Z372',   'ICD10CM', 'Twins, both liveborn', 0, 0),
('LB', 'Z3750',  'ICD10CM', 'Multiple births, unspecified, all liveborn', 0, 0),
('LB', 'Z3751',  'ICD10CM', 'Triplets, all liveborn', 0, 0),
('LB', 'Z3752',  'ICD10CM', 'Quadruplets, all liveborn', 0, 0),
('LB', 'Z3753',  'ICD10CM', 'Quintuplets, all liveborn', 0, 0),
('LB', 'Z3754',  'ICD10CM', 'Sextuplets, all liveborn', 0, 0),
('LB', 'Z3759',  'ICD10CM', 'Other multiple births, all liveborn', 0, 0),
('LB', 'O80',    'ICD10CM', 'Encounter for full-term uncomplicated delivery', 0, 0),
('LB', 'Z373',   'ICD10CM', 'Twins, one liveborn and one stillborn', 0, 1),
('LB', 'Z3760',  'ICD10CM', 'Multiple births, unspecified, some liveborn', 0, 1),
('LB', 'Z3761',  'ICD10CM', 'Triplets, some liveborn', 0, 1),
('LB', 'Z3762',  'ICD10CM', 'Quadruplets, some liveborn', 0, 1),
('LB', 'Z3763',  'ICD10CM', 'Quintuplets, some liveborn', 0, 1),
('LB', 'Z3764',  'ICD10CM', 'Sextuplets, some liveborn', 0, 1),
('SB', 'Z371',   'ICD10CM', 'Single stillbirth', 1, 0),
('SB', 'Z374',   'ICD10CM', 'Twins, both stillborn', 1, 1),
('SB', 'Z377',   'ICD10CM', 'Other multiple births, all stillborn', 1, 1),
('SB', 'O364XX0','ICD10CM', 'Maternal care for intrauterine death, not applicable or unspecified', 1, 1),
('SB', 'O364XX1','ICD10CM', 'Maternal care for intrauterine death, fetus 1', 1, 1),
('SB', 'O364XX2','ICD10CM', 'Maternal care for intrauterine death, fetus 2', 1, 1),
('SB', 'O364XX3','ICD10CM', 'Maternal care for intrauterine death, fetus 3', 1, 1),
('SB', 'O364XX4','ICD10CM', 'Maternal care for intrauterine death, fetus 4', 1, 1),
('SB', 'O364XX5','ICD10CM', 'Maternal care for intrauterine death, fetus 5', 1, 1),
('SB', 'O364XX9','ICD10CM', 'Maternal care for intrauterine death, other fetus', 1, 1);


/*
 * Create Covariate Index Codeset (Greenplum/Postgres)
 */

DROP TABLE IF EXISTS research_dev.poem_comorbid_index;

CREATE TABLE research_dev.poem_comorbid_index (
    condition              VARCHAR(100),
    dx                     VARCHAR(20),
    smm_weight             INTEGER,
    no_transfusion_weight  INTEGER
);

INSERT INTO research_dev.poem_comorbid_index (condition, dx, smm_weight, no_transfusion_weight) VALUES
('advanced maternal age, 35+', 'nan', 2, 1),
('anemia, preexisting', 'O9901', 20, 7),
('anemia, preexisting', 'O9902', 20, 7),
('anemia, preexisting', 'D50', 20, 7),
('anemia, preexisting', 'D571', 20, 7),
('anemia, preexisting', 'D5720', 20, 7),
('anemia, preexisting', 'D573', 20, 7),
('anemia, preexisting', 'D5740', 20, 7),
('anemia, preexisting', 'D5780', 20, 7),
('anemia, preexisting', 'D58', 20, 7),
('anemia, preexisting', 'D59', 20, 7),
('asthma', 'O995', 11, 9),
('asthma', 'J4521', 11, 9),
('asthma', 'J4522', 11, 9),
('asthma', 'J4531', 11, 9),
('asthma', 'J4532', 11, 9),
('asthma', 'J454', 11, 9),
('asthma', 'J455', 11, 9),
('asthma', 'J45901', 11, 9),
('asthma', 'J45902', 11, 9),
('bariatric surgery', 'O9984', 0, 0),
('bleeding disorder, preexisting', 'D66', 34, 23),
('bleeding disorder, preexisting', 'D67', 34, 23),
('bleeding disorder, preexisting', 'D68', 34, 23),
('bleeding disorder, preexisting', 'D69', 34, 23),
('bmi, 40+ ', 'Z684', 5, 4),
('cardiac disease, preexisting', 'I05', 31, 22),
('cardiac disease, preexisting', 'I06', 31, 22),
('cardiac disease, preexisting', 'I07', 31, 22),
('cardiac disease, preexisting', 'I08', 31, 22),
('cardiac disease, preexisting', 'I09', 31, 22),
('cardiac disease, preexisting', 'I11', 31, 22),
('cardiac disease, preexisting', 'I12', 31, 22),
('cardiac disease, preexisting', 'I13', 31, 22),
('cardiac disease, preexisting', 'I15', 31, 22),
('cardiac disease, preexisting', 'I16', 31, 22),
('cardiac disease, preexisting', 'I20', 31, 22),
('cardiac disease, preexisting', 'I25', 31, 22),
('cardiac disease, preexisting', 'I278', 31, 22),
('cardiac disease, preexisting', 'I30', 31, 22),
('cardiac disease, preexisting', 'I31', 31, 22),
('cardiac disease, preexisting', 'I32', 31, 22),
('cardiac disease, preexisting', 'I33', 31, 22),
('cardiac disease, preexisting', 'I34', 31, 22),
('cardiac disease, preexisting', 'I35', 31, 22),
('cardiac disease, preexisting', 'I36', 31, 22),
('cardiac disease, preexisting', 'I37', 31, 22),
('cardiac disease, preexisting', 'I38', 31, 22),
('cardiac disease, preexisting', 'I39', 31, 22),
('cardiac disease, preexisting', 'I40', 31, 22),
('cardiac disease, preexisting', 'I41', 31, 22),
('cardiac disease, preexisting', 'I44', 31, 22),
('cardiac disease, preexisting', 'I45', 31, 22),
('cardiac disease, preexisting', 'I46', 31, 22),
('cardiac disease, preexisting', 'I47', 31, 22),
('cardiac disease, preexisting', 'I48', 31, 22),
('cardiac disease, preexisting', 'I49', 31, 22),
('cardiac disease, preexisting', 'I5022', 31, 22),
('cardiac disease, preexisting', 'I5023', 31, 22),
('cardiac disease, preexisting', 'I5032', 31, 22),
('cardiac disease, preexisting', 'I5033', 31, 22),
('cardiac disease, preexisting', 'I5042', 31, 22),
('cardiac disease, preexisting', 'I5043', 31, 22),
('cardiac disease, preexisting', 'I50812', 31, 22),
('cardiac disease, preexisting', 'I50813', 31, 22),
('cardiac disease, preexisting', 'O9941', 31, 22),
('cardiac disease, preexisting', 'O9942', 31, 22),
('cardiac disease, preexisting', 'Q20', 31, 22),
('cardiac disease, preexisting', 'Q21', 31, 22),
('cardiac disease, preexisting', 'Q22', 31, 22),
('cardiac disease, preexisting', 'Q23', 31, 22),
('cardiac disease, preexisting', 'Q24', 31, 22),
('chronic hypertension', 'O10', 10, 7),
('chronic hypertension', 'O11', 10, 7),
('chronic hypertension', 'I10', 10, 7),
('chronic renal disease', 'O2683', 38, 26),
('chronic renal disease', 'I12', 38, 26),
('chronic renal disease', 'I13', 38, 26),
('chronic renal disease', 'N03', 38, 26),
('chronic renal disease', 'N05', 38, 26),
('chronic renal disease', 'N07', 38, 26),
('chronic renal disease', 'N08', 38, 26),
('chronic renal disease', 'N111', 38, 26),
('chronic renal disease', 'N118', 38, 26),
('chronic renal disease', 'N119', 38, 26),
('chronic renal disease', 'N18', 38, 26),
('chronic renal disease', 'N250', 38, 26),
('chronic renal disease', 'N251', 38, 26),
('chronic renal disease', 'N2581', 38, 26),
('chronic renal disease', 'N2589', 38, 26),
('chronic renal disease', 'N259', 38, 26),
('chronic renal disease', 'N269', 38, 26),
('connective tissue, autoimmune disease', 'M30', 10, 7),
('connective tissue, autoimmune disease', 'M31', 10, 7),
('connective tissue, autoimmune disease', 'M32', 10, 7),
('connective tissue, autoimmune disease', 'M33', 10, 7),
('connective tissue, autoimmune disease', 'M34', 10, 7),
('connective tissue, autoimmune disease', 'M35', 10, 7),
('connective tissue, autoimmune disease', 'M36', 10, 7),
('gastrointestinal disease', 'K', 12, 8),
('gastrointestinal disease', 'O996', 12, 8),
('gastrointestinal disease', 'O266', 12, 8),
('gestational diabetes mellitus', 'O244', 1, 1),
('hiv/aids', 'O987', 30, 13),
('hiv/aids', 'B20', 30, 13),
('major mental health disorder', 'O9934', 7, 4),
('major mental health disorder', 'F20', 7, 4),
('major mental health disorder', 'F21', 7, 4),
('major mental health disorder', 'F22', 7, 4),
('major mental health disorder', 'F23', 7, 4),
('major mental health disorder', 'F24', 7, 4),
('major mental health disorder', 'F25', 7, 4),
('major mental health disorder', 'F26', 7, 4),
('major mental health disorder', 'F27', 7, 4),
('major mental health disorder', 'F28', 7, 4),
('major mental health disorder', 'F29', 7, 4),
('major mental health disorder', 'F30', 7, 4),
('major mental health disorder', 'F31', 7, 4),
('major mental health disorder', 'F32', 7, 4),
('major mental health disorder', 'F33', 7, 4),
('major mental health disorder', 'F34', 7, 4),
('major mental health disorder', 'F35', 7, 4),
('major mental health disorder', 'F36', 7, 4),
('major mental health disorder', 'F37', 7, 4),
('major mental health disorder', 'F38', 7, 4),
('major mental health disorder', 'F39', 7, 4),
('neuromuscular disease', 'O9935', 9, 8),
('neuromuscular disease', 'G40', 9, 8),
('neuromuscular disease', 'G70', 9, 8),
('non-singleton pregnancy', 'O30 ', 20, 8),
('non-singleton pregnancy', 'O31 ', 20, 8),
('non-singleton pregnancy', 'Z372', 20, 8),
('non-singleton pregnancy', 'Z373', 20, 8),
('non-singleton pregnancy', 'Z374', 20, 8),
('non-singleton pregnancy', 'Z375', 20, 8),
('non-singleton pregnancy', 'Z376', 20, 8),
('non-singleton pregnancy', 'Z377', 20, 8),
('placenta accreta spectrum', 'O432', 59, 36),
('placenta previa', 'O4403', 27, 13),
('placenta previa', 'O4413', 27, 13),
('placenta previa', 'O4423', 27, 13),
('placenta previa', 'O4433', 27, 13),
('placental abruption', 'O45', 18, 7),
('preeclampsia with severe features', 'O141', 26, 16),
('preeclampsia with severe features', 'O142', 26, 16),
('preeclampsia with severe features', 'O11', 26, 16),
('preeclampsia without severe features or gestational hypertension', 'O13', 11, 6),
('preeclampsia without severe features or gestational hypertension', 'O140', 11, 6),
('preeclampsia without severe features or gestational hypertension', 'O149', 11, 6),
('preexisting diabetes mellitus', 'E08', 9, 6),
('preexisting diabetes mellitus', 'E09', 9, 6),
('preexisting diabetes mellitus', 'E10', 9, 6),
('preexisting diabetes mellitus', 'E11', 9, 6),
('preexisting diabetes mellitus', 'E12', 9, 6),
('preexisting diabetes mellitus', 'E13', 9, 6),
('preexisting diabetes mellitus', 'O240 ', 9, 6),
('preexisting diabetes mellitus', 'O241 ', 9, 6),
('preexisting diabetes mellitus', 'O243 ', 9, 6),
('preexisting diabetes mellitus', 'O248 ', 9, 6),
('preexisting diabetes mellitus', 'O249 ', 9, 6),
('preexisting diabetes mellitus', 'Z794', 9, 6),
('preterm birth', 'Z3A2', 18, 12),
('preterm birth', 'Z3A30', 18, 12),
('preterm birth', 'Z3A31', 18, 12),
('preterm birth', 'Z3A32', 18, 12),
('preterm birth', 'Z3A33', 18, 12),
('preterm birth', 'Z3A34', 18, 12),
('preterm birth', 'Z3A35', 18, 12),
('preterm birth', 'Z3A36', 18, 12),
('previous cesarean birth', 'O3421', 4, 0),
('pulmonary hypertension', 'I270', 50, 32),
('pulmonary hypertension', 'I272', 50, 32),
('substance use disorder', 'F10', 10, 5),
('substance use disorder', 'F11', 10, 5),
('substance use disorder', 'F12', 10, 5),
('substance use disorder', 'F13', 10, 5),
('substance use disorder', 'F14', 10, 5),
('substance use disorder', 'F15', 10, 5),
('substance use disorder', 'F16', 10, 5),
('substance use disorder', 'F17', 10, 5),
('substance use disorder', 'F18', 10, 5),
('substance use disorder', 'F19', 10, 5),
('substance use disorder', 'O9931', 10, 5),
('substance use disorder', 'O9932', 10, 5),
('thyrotoxicosis', 'E05', 6, 0);

/*
 * Outpatient Visits (Greenplum/Postgres)
 */

DROP TABLE IF EXISTS research_dev.poem_codes_any_out;

CREATE TABLE research_dev.poem_codes_any_out (
    code_type VARCHAR(50),
    code      VARCHAR(20),
    category  VARCHAR(100)
);

-- CPT codes
INSERT INTO research_dev.poem_codes_any_out (code_type, code, category)
VALUES 
('cpt', '99201', 'Any Outpatient Visit'), ('cpt', '99202', 'Any Outpatient Visit'),
('cpt', '99203', 'Any Outpatient Visit'), ('cpt', '99204', 'Any Outpatient Visit'),
('cpt', '99205', 'Any Outpatient Visit'), ('cpt', '99211', 'Any Outpatient Visit'),
('cpt', '99212', 'Any Outpatient Visit'), ('cpt', '99213', 'Any Outpatient Visit'),
('cpt', '99214', 'Any Outpatient Visit'), ('cpt', '99215', 'Any Outpatient Visit'),
('cpt', '99241', 'Any Outpatient Visit'), ('cpt', '99242', 'Any Outpatient Visit'),
('cpt', '99243', 'Any Outpatient Visit'), ('cpt', '99244', 'Any Outpatient Visit'),
('cpt', '99245', 'Any Outpatient Visit'), ('cpt', '99341', 'Any Outpatient Visit'),
('cpt', '99342', 'Any Outpatient Visit'), ('cpt', '99343', 'Any Outpatient Visit'),
('cpt', '99344', 'Any Outpatient Visit'), ('cpt', '99345', 'Any Outpatient Visit'),
('cpt', '99347', 'Any Outpatient Visit'), ('cpt', '99348', 'Any Outpatient Visit'),
('cpt', '99349', 'Any Outpatient Visit'), ('cpt', '99350', 'Any Outpatient Visit'),
('cpt', '99381', 'Any Outpatient Visit'), ('cpt', '99382', 'Any Outpatient Visit'),
('cpt', '99383', 'Any Outpatient Visit'), ('cpt', '99384', 'Any Outpatient Visit'),
('cpt', '99385', 'Any Outpatient Visit'), ('cpt', '99386', 'Any Outpatient Visit'),
('cpt', '99387', 'Any Outpatient Visit'), ('cpt', '99391', 'Any Outpatient Visit'),
('cpt', '99392', 'Any Outpatient Visit'), ('cpt', '99393', 'Any Outpatient Visit'),
('cpt', '99394', 'Any Outpatient Visit'), ('cpt', '99395', 'Any Outpatient Visit'),
('cpt', '99396', 'Any Outpatient Visit'), ('cpt', '99397', 'Any Outpatient Visit'),
('cpt', '99401', 'Any Outpatient Visit'), ('cpt', '99402', 'Any Outpatient Visit'),
('cpt', '99403', 'Any Outpatient Visit'), ('cpt', '99404', 'Any Outpatient Visit'),
('cpt', '99411', 'Any Outpatient Visit'), ('cpt', '99412', 'Any Outpatient Visit'),
('cpt', '99429', 'Any Outpatient Visit'), ('cpt', '92002', 'Any Outpatient Visit'),
('cpt', '92004', 'Any Outpatient Visit'), ('cpt', '92012', 'Any Outpatient Visit'),
('cpt', '92014', 'Any Outpatient Visit'), ('cpt', '99304', 'Any Outpatient Visit'),
('cpt', '99305', 'Any Outpatient Visit'), ('cpt', '99306', 'Any Outpatient Visit'),
('cpt', '99307', 'Any Outpatient Visit'), ('cpt', '99308', 'Any Outpatient Visit'),
('cpt', '99309', 'Any Outpatient Visit'), ('cpt', '99310', 'Any Outpatient Visit'),
('cpt', '99315', 'Any Outpatient Visit'), ('cpt', '99316', 'Any Outpatient Visit'),
('cpt', '99318', 'Any Outpatient Visit'), ('cpt', '99324', 'Any Outpatient Visit'),
('cpt', '99325', 'Any Outpatient Visit'), ('cpt', '99326', 'Any Outpatient Visit'),
('cpt', '99327', 'Any Outpatient Visit'), ('cpt', '99328', 'Any Outpatient Visit'),
('cpt', '99334', 'Any Outpatient Visit'), ('cpt', '99335', 'Any Outpatient Visit'),
('cpt', '99336', 'Any Outpatient Visit'), ('cpt', '99337', 'Any Outpatient Visit'),
('cpt', '98966', 'Any Outpatient Visit'), ('cpt', '98967', 'Any Outpatient Visit'),
('cpt', '98968', 'Any Outpatient Visit'), ('cpt', '99441', 'Any Outpatient Visit'),
('cpt', '99442', 'Any Outpatient Visit'), ('cpt', '99443', 'Any Outpatient Visit'),
('cpt', '98969', 'Any Outpatient Visit'), ('cpt', '99444', 'Any Outpatient Visit'),
('cpt', '99483', 'Any Outpatient Visit');

-- HCPCS codes
INSERT INTO research_dev.poem_codes_any_out (code_type, code, category)
VALUES 
('hcpcs', 'G0402', 'Any Outpatient Visit'), ('hcpcs', 'G0438', 'Any Outpatient Visit'),
('hcpcs', 'G0439', 'Any Outpatient Visit'), ('hcpcs', 'G0463', 'Any Outpatient Visit'),
('hcpcs', 'T1015', 'Any Outpatient Visit'), ('hcpcs', 'S0620', 'Any Outpatient Visit'),
('hcpcs', 'S0621', 'Any Outpatient Visit');

-- Modifiers
INSERT INTO research_dev.poem_codes_any_out (code_type, code, category)
VALUES 
('modifier', '95', 'Any Outpatient Visit'), ('modifier', 'GT', 'Any Outpatient Visit');

-- Place of Service
INSERT INTO research_dev.poem_codes_any_out (code_type, code, category)
VALUES 
('place_of_service', '02', 'Any Outpatient Visit');

-- ICD-10 codes
INSERT INTO research_dev.poem_codes_any_out (code_type, code, category)
VALUES 
('icd10', 'Z0000', 'Any Outpatient Visit'), ('icd10', 'Z0001', 'Any Outpatient Visit'),
('icd10', 'Z00121', 'Any Outpatient Visit'), ('icd10', 'Z00129', 'Any Outpatient Visit'),
('icd10', 'Z003', 'Any Outpatient Visit'), ('icd10', 'Z005', 'Any Outpatient Visit'),
('icd10', 'Z008', 'Any Outpatient Visit'), ('icd10', 'Z020', 'Any Outpatient Visit'),
('icd10', 'Z021', 'Any Outpatient Visit'), ('icd10', 'Z022', 'Any Outpatient Visit'),
('icd10', 'Z023', 'Any Outpatient Visit'), ('icd10', 'Z024', 'Any Outpatient Visit'),
('icd10', 'Z025', 'Any Outpatient Visit'), ('icd10', 'Z026', 'Any Outpatient Visit'),
('icd10', 'Z0271', 'Any Outpatient Visit'), ('icd10', 'Z0279', 'Any Outpatient Visit'),
('icd10', 'Z0281', 'Any Outpatient Visit'), ('icd10', 'Z0282', 'Any Outpatient Visit'),
('icd10', 'Z0283', 'Any Outpatient Visit'), ('icd10', 'Z0289', 'Any Outpatient Visit'),
('icd10', 'Z029', 'Any Outpatient Visit'), ('icd10', 'Z761', 'Any Outpatient Visit'),
('icd10', 'Z762', 'Any Outpatient Visit');

-- Revenue codes
INSERT INTO research_dev.poem_codes_any_out (code_type, code, category)
VALUES 
('revenue_code', '0510', 'Any Outpatient Visit'), ('revenue_code', '0511', 'Any Outpatient Visit'),
('revenue_code', '0512', 'Any Outpatient Visit'), ('revenue_code', '0513', 'Any Outpatient Visit'),
('revenue_code', '0514', 'Any Outpatient Visit'), ('revenue_code', '0515', 'Any Outpatient Visit'),
('revenue_code', '0516', 'Any Outpatient Visit'), ('revenue_code', '0517', 'Any Outpatient Visit'),
('revenue_code', '0519', 'Any Outpatient Visit'), ('revenue_code', '0520', 'Any Outpatient Visit'),
('revenue_code', '0521', 'Any Outpatient Visit'), ('revenue_code', '0522', 'Any Outpatient Visit'),
('revenue_code', '0523', 'Any Outpatient Visit'), ('revenue_code', '0526', 'Any Outpatient Visit'),
('revenue_code', '0527', 'Any Outpatient Visit'), ('revenue_code', '0528', 'Any Outpatient Visit'),
('revenue_code', '0529', 'Any Outpatient Visit'), ('revenue_code', '0982', 'Any Outpatient Visit'),
('revenue_code', '0983', 'Any Outpatient Visit'), ('revenue_code', '0524', 'Any Outpatient Visit'),
('revenue_code', '0525', 'Any Outpatient Visit');



/* -------------------------------
 * Diabetes Test Screen
 * -------------------------------
 */
/* Create a lookup table for test types */
DROP TABLE IF EXISTS research_dev.test_type_lookup;

CREATE TABLE research_dev.test_type_lookup (
    code_type VARCHAR(10),
    code VARCHAR(10),
    test_type VARCHAR(50)
);

INSERT INTO research_dev.test_type_lookup (code_type, code, test_type)
VALUES
    ('CPT', '83036', 'HbA1c'),
    ('CPT', '83037', 'HbA1c'),
    ('CPT', '80047', 'GTT'),
    ('CPT', '80048', 'GTT'),
    ('CPT', '80050', 'GTT'),
    ('CPT', '80053', 'GTT'),
    ('CPT', '80069', 'GTT'),
    ('CPT', '82947', 'GTT'),
    ('CPT', '82950', 'GTT'),
    ('CPT', '82951', 'GTT');
