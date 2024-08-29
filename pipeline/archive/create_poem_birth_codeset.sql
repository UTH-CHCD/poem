
drop table if exists dev.poem_codeset_births;

CREATE TABLE dev.poem_codeset_births (
    outcome_type text,
    cd text,
    code_type text,
    definition TEXT,
    sb_flag INT,
    multiple_flag INT
);

INSERT INTO dev.poem_codeset_births (outcome_type, cd, code_type, definition, sb_flag, multiple_flag) VALUES
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
