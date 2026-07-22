-- 03_create_concept_sets.sql
-- Canonical concept sets and vocabulary validation for the OMOP SOFA pipeline.
-- UPDATED 2026-05-02 Site A: 
--   - removed invalid 37026905 (FiO2) and 4145896 (ventilation)
--   - added FiO2 3024882, ventilation B2AI, RRT B2AI, ECMO
--   - antibiotic expansion now excludes non-systemic routes via dose form + route relationships
--   - validation now uses portable SQL cast exception instead of DO block or psql \if

DROP TABLE IF EXISTS :results_schema.concept_set_members CASCADE;

CREATE TABLE :results_schema.concept_set_members (
    concept_set_name text NOT NULL,
    concept_id bigint NOT NULL,
    expected_domain_id text,
    require_standard boolean NOT NULL DEFAULT true,
    local_allowed boolean NOT NULL DEFAULT false,
    source text NOT NULL,
    note text,
    PRIMARY KEY (concept_set_name, concept_id)
);

INSERT INTO :results_schema.concept_set_members (concept_set_name, concept_id, expected_domain_id, require_standard, local_allowed, source, note)
VALUES
    -- Labs
    ('platelets', 3024929, 'Measurement', true, false, 'ATHENA', 'Platelets [#/volume] in Blood by Automated count'),
    ('platelets', 3016682, 'Measurement', true, false, 'ATHENA', 'Platelets in Plasma'),
    ('platelets', 3013290, 'Measurement', false, false, 'MGH validated', 'Platelet count fallback'),
    ('platelets', 3000812, 'Measurement', false, false, 'MGH validated', 'Platelet count fallback'),
    ('lactate', 3047181, 'Measurement', true, false, 'ATHENA', 'Lactate [Moles/volume] in Blood'),
    ('lactate', 3014111, 'Measurement', true, false, 'ATHENA', 'Lactate in Serum or Plasma'),
    ('lactate', 3008037, 'Measurement', true, false, 'ATHENA', 'Lactate in Venous blood'),
    ('bilirubin', 3024128, 'Measurement', true, false, 'ATHENA', 'Bilirubin.total'),
    ('bilirubin', 3035616, 'Measurement', false, false, 'MGH validated', 'Bilirubin total fallback'),
    ('bilirubin', 3014661, 'Measurement', false, false, 'MGH validated', 'Bilirubin total fallback'),
    ('bilirubin', 3013721, 'Measurement', false, false, 'MGH validated', 'Bilirubin total fallback'),
    ('bilirubin', 3013682, 'Measurement', false, false, 'CHORUS fallback', 'Bilirubin fallback'),
    ('creatinine', 3016723, 'Measurement', true, false, 'ATHENA', 'Creatinine'),
    ('creatinine', 3020564, 'Measurement', false, false, 'MGH validated', 'Creatinine fallback'),
    ('creatinine', 3051825, 'Measurement', false, false, 'MGH validated', 'Creatinine fallback'),
    ('creatinine', 3004327, 'Measurement', false, false, 'MGH validated', 'Creatinine fallback'),
    ('urine_output', 3014315, 'Measurement', true, false, 'ATHENA', 'Urine output volume'),

    -- Vitals and neuro
    ('map', 4108290, 'Measurement', true, false, 'ATHENA', 'Invasive mean arterial pressure'),
    ('map', 3027598, 'Measurement', true, false, 'ATHENA', 'Mean blood pressure'),
    ('sbp', 3004249, 'Measurement', true, false, 'ATHENA', 'Systolic blood pressure'),
    ('dbp', 3012888, 'Measurement', true, false, 'ATHENA', 'Diastolic blood pressure'),
    ('dbp', 3034703, 'Measurement', true, false, 'ATHENA', 'Diastolic blood pressure--sitting'),
    ('dbp', 3019962, 'Measurement', true, false, 'ATHENA', 'Diastolic blood pressure--standing'),
    ('heart_rate', 3027018, 'Measurement', true, false, 'ATHENA', 'Heart rate'),
    ('gcs', 4093836, 'Measurement', false, false, 'ATHENA', 'Glasgow coma score total'),
    ('gcs', 3016335, NULL, true, false, 'ATHENA', 'GCS eye'),
    ('gcs', 3009094, NULL, true, false, 'ATHENA', 'GCS verbal'),
    ('gcs', 3008223, NULL, true, false, 'ATHENA', 'GCS motor'),

    -- PaO2 and FiO2
    ('pao2', 3027801, NULL, true, false, 'ATHENA', 'O2 partial pressure arterial blood'),
    ('pao2', 3007461, NULL, true, false, 'ATHENA', 'O2 partial pressure blood arterial'),
    ('pao2', 3023091, NULL, true, false, 'ATHENA', 'O2 partial pressure adjusted arterial'),
    ('pao2', 3031717, NULL, true, false, 'ATHENA', 'Calculated arterial oxygen pressure'),
    ('pao2', 40772940, 'Measurement', false, false, 'ATHENA', 'Arterial oxygen tension'),
    ('fio2', 3020716, NULL, true, false, 'ATHENA', 'Inhaled oxygen concentration'),
    ('fio2', 4353936, NULL, true, false, 'ATHENA', 'Inspired oxygen concentration'),
    ('fio2', 3036277, NULL, true, false, 'ATHENA', 'FiO2'),
    ('fio2', 37547367, 'Measurement', false, false, 'ATHENA', 'Fraction of Inspired Oxygen'),
    ('fio2', 45508326, 'Measurement', false, false, 'ATHENA', 'FIO2 - Inspired fraction'),
    ('fio2', 3026238, NULL, true, false, 'ATHENA', 'O2/Inspired gas on ventilator'),
    ('fio2', 3025408, NULL, true, false, 'ATHENA', 'O2/Inspired gas by analyzer on ventilator'),
    -- ('fio2', 37026905, 'Observation', false, false, 'ATHENA', 'Oxygen/Inspired gas setting'), -- REMOVED: invalid_reason='D'
    ('fio2', 37040455, 'Observation', false, false, 'ATHENA', 'Oxygen/Inspired gas'),
    ('fio2', 2147482989, NULL, false, true, 'LOCAL', 'Site-local FiO2 concept'),
    ('fio2', 3024882, NULL, true, false, 'CUSTOM', 'Oxygen/Total gas setting [Volume Fraction] Ventilator - Site A'),

    -- Support therapies
    ('ventilation', 4202832, 'Procedure', true, false, 'ATHENA', 'Intubation'),
    ('ventilation', 42738694, 'Procedure', true, false, 'ATHENA', 'Mechanical ventilation procedure'),
    -- ('ventilation', 4145896, 'Condition', false, false, 'ATHENA', 'Ventilation support'), -- REMOVED: maps to epilepsy
    ('ventilation', 2147482986, 'Procedure', true, false, 'CUSTOM', 'Mechanical Ventilation | ETT Double Lumen - Site A'),
    ('ventilation', 2147482987, 'Procedure', true, false, 'CUSTOM', 'Mechanical Ventilation | ETT Comment - Site A'),
    ('rrt', 4197217, 'Procedure', true, false, 'ATHENA', 'Dialysis procedure'),
    ('rrt', 37018292, 'Procedure', true, false, 'ATHENA', 'Continuous renal replacement therapy'),
    ('rrt', 2147483064, 'Measurement', true, false, 'CUSTOM', 'CRRT Desired Fluid Loss - Site A'),
    ('rrt', 2147483187, 'Measurement', true, false, 'CUSTOM', 'CRRT warming device - Site A'),
    ('rrt', 2147483188, 'Measurement', true, false, 'CUSTOM', 'CRRT volume to be removed - Site A'),
    ('rrt', 2147483189, 'Measurement', true, false, 'CUSTOM', 'CRRT volume not to be removed - Site A'),
    ('rrt', 2147483190, 'Measurement', true, false, 'CUSTOM', 'CRRT venous pressure (mmHg) - Site A'),
    ('rrt', 2147483191, 'Measurement', true, false, 'CUSTOM', 'CRRT Venous chamber blood level - Site A'),
    ('rrt', 2147483192, 'Measurement', true, false, 'CUSTOM', 'CRRT ultrafiltrate rate less than zero - Site A'),
    ('rrt', 2147483193, 'Measurement', true, false, 'CUSTOM', 'CRRT tubing change date - Site A'),
    ('rrt', 2147483194, 'Measurement', true, false, 'CUSTOM', 'CRRT Total previous hour intake - Site A'),
    ('rrt', 2147483195, 'Measurement', true, false, 'CUSTOM', 'CRRT temp management - Site A'),
    ('vasopressor', 1321341, 'Drug', true, false, 'ATHENA', 'Norepinephrine'),
    ('vasopressor', 1343916, 'Drug', true, false, 'ATHENA', 'Epinephrine'),
    ('vasopressor', 1507835, 'Drug', true, false, 'ATHENA', 'Vasopressin'),
    ('vasopressor', 1135766, 'Drug', true, false, 'ATHENA', 'Phenylephrine'),
    ('vasopressor', 1337860, 'Drug', true, false, 'ATHENA', 'Dopamine'),
    ('vasopressor', 1337720, 'Drug', true, false, 'ATHENA', 'Dobutamine');

-- ECMO (new concept set)
INSERT INTO :results_schema.concept_set_members (concept_set_name, concept_id, expected_domain_id, require_standard, local_allowed, source, note)
VALUES
    ('ecmo', 46257397, 'Procedure', true, false, 'CUSTOM', 'ECMO insertion central cannula, birth-5y - Site A'),
    ('ecmo', 46257398, 'Procedure', true, false, 'CUSTOM', 'ECMO insertion central cannula, 6y+ - Site A');

ALTER TABLE :results_schema.concept_set_members ADD COLUMN expected_concept_code text;

UPDATE :results_schema.concept_set_members
SET expected_concept_code = expected.code
FROM (VALUES
    (4108290::bigint, '251075007'),
    (3027598::bigint, '8478-0'),
    (3004249::bigint, '8480-6'),
    (3012888::bigint, '8462-4'),
    (3034703::bigint, '8453-3'),
    (3019962::bigint, '8454-1')
) AS expected(concept_id, code)
WHERE concept_set_members.concept_id = expected.concept_id;

INSERT INTO :results_schema.concept_set_members (concept_set_name, concept_id, expected_domain_id, require_standard, local_allowed, source, note)
SELECT 'culture_measurement', concept_id, 'Measurement', true, false, 'ATHENA', 'Culture measurement'
FROM (VALUES
    (3023368),(3013867),(3026008),(3025099),(3039355),(40762243),
    (3003714),(3000494),(3005702),(3025941),(3011298),(3016727),
    (3027005),(3016114),(3016914),(3015479),(3045330),(40765191),
    (3037692),(3023419),(3033740),(3010254),(3019902),(3004840),
    (3017611),(3023601),(3023207),(3024461),(3015409),(3036000),
    (43533857),(3025468),(3012568),(3005988)
) AS t(concept_id)
UNION ALL
SELECT 'culture_specimen', concept_id, 'Specimen', false, false, 'ATHENA', 'Culture specimen'
FROM (VALUES
    (618898),(1447635),(3516065),(3667301),(3667306)
) AS t(concept_id);

-- Antibiotics: ATC J01 systemic only, exclude non-systemic by dose form AND route
INSERT INTO :results_schema.concept_set_members (concept_set_name, concept_id, expected_domain_id, require_standard, local_allowed, source, note)
SELECT DISTINCT 'antibiotic', ca.descendant_concept_id, 'Drug', true, false, 'ATHENA concept_ancestor 21602796', c.concept_name
FROM :vocab_schema.concept_ancestor ca
JOIN :vocab_schema.concept c ON c.concept_id = ca.descendant_concept_id
WHERE ca.ancestor_concept_id = 21602796
  AND c.domain_id = 'Drug'
  AND c.standard_concept = 'S'
  AND c.invalid_reason IS NULL
  AND c.concept_name !~* '(topical|ophthalm|otic|eye|ear|cream|ointment|gel|nasal|inhal|dermal|cutan|vaginal|rectal|shampoo|spray|drops|lotion|irrigation|intravitreal|suppository|enema)'
  AND NOT EXISTS (
    SELECT 1 FROM :vocab_schema.concept_relationship cr
    JOIN :vocab_schema.concept df ON df.concept_id = cr.concept_id_2
    WHERE cr.concept_id_1 = c.concept_id
      AND cr.relationship_id IN ('RxNorm has dose form','Has dose form')
      AND df.concept_name ~* '(topical|ophthalmic|otic|cream|ointment|gel|nasal|inhalation|dermal|vaginal|rectal|shampoo|spray|drops|lotion|irrigation|suppository|enema)'
  )
  AND NOT EXISTS (
    SELECT 1 FROM :vocab_schema.concept_relationship cr2
    JOIN :vocab_schema.concept rt ON rt.concept_id = cr2.concept_id_2
    WHERE cr2.concept_id_1 = c.concept_id
      AND cr2.relationship_id IN ('Has route','RxNorm has route')
      AND rt.concept_name ~* '(ophthalmic|otic|topical|nasal|inhalation|vaginal|rectal|intravitreal|ear|eye)'
  );

DROP TABLE IF EXISTS :results_schema.vasopressor_nee_factors CASCADE;
CREATE TABLE :results_schema.vasopressor_nee_factors (
    concept_id bigint PRIMARY KEY,
    vasopressor_name text NOT NULL,
    nee_factor numeric NOT NULL
);

INSERT INTO :results_schema.vasopressor_nee_factors (concept_id, vasopressor_name, nee_factor)
VALUES
    (1321341, 'norepinephrine', 1.0),
    (1343916, 'epinephrine', 1.0),
    (1507835, 'vasopressin', 2.5),
    (1135766, 'phenylephrine', 0.1),
    (1337860, 'dopamine', 0.01),
    (1337720, 'dobutamine', 0.01);

DROP TABLE IF EXISTS :results_schema.concept_set_validation_failures CASCADE;
CREATE TABLE :results_schema.concept_set_validation_failures AS
SELECT
    m.concept_set_name,
    m.concept_id,
    m.source,
    m.expected_domain_id,
    m.expected_concept_code,
    c.concept_code AS actual_concept_code,
    c.domain_id AS actual_domain_id,
    c.standard_concept,
    c.invalid_reason,
    CASE
        WHEN c.concept_id IS NULL AND NOT m.local_allowed THEN 'missing_from_vocabulary'
        WHEN c.concept_id IS NOT NULL AND NOT m.local_allowed AND c.invalid_reason IS NOT NULL THEN 'invalid_concept'
        WHEN c.concept_id IS NOT NULL AND NOT m.local_allowed AND m.expected_domain_id IS NOT NULL AND c.domain_id <> m.expected_domain_id THEN 'wrong_domain'
        WHEN c.concept_id IS NOT NULL AND NOT m.local_allowed AND m.expected_concept_code IS NOT NULL AND c.concept_code <> m.expected_concept_code THEN 'wrong_concept_code'
        WHEN c.concept_id IS NOT NULL AND NOT m.local_allowed AND m.require_standard AND COALESCE(c.standard_concept, '') <> 'S' THEN 'non_standard'
    END AS failure_reason
FROM :results_schema.concept_set_members m
LEFT JOIN :vocab_schema.concept c ON c.concept_id = m.concept_id
WHERE
    (c.concept_id IS NULL AND NOT m.local_allowed)
    OR (c.concept_id IS NOT NULL AND NOT m.local_allowed AND c.invalid_reason IS NOT NULL)
    OR (c.concept_id IS NOT NULL AND NOT m.local_allowed AND m.expected_domain_id IS NOT NULL AND c.domain_id <> m.expected_domain_id)
    OR (c.concept_id IS NOT NULL AND NOT m.local_allowed AND m.expected_concept_code IS NOT NULL AND c.concept_code <> m.expected_concept_code)
    OR (c.concept_id IS NOT NULL AND NOT m.local_allowed AND m.require_standard AND COALESCE(c.standard_concept, '') <> 'S');

-- Show the exact failures before forcing a fatal data exception.
SELECT *
FROM :results_schema.concept_set_validation_failures
ORDER BY concept_set_name, concept_id
LIMIT 50;

-- Portable validation: Forces a fatal data exception if validation fails.
SELECT 
    1 / (CASE WHEN COUNT(*) > 0 THEN 0 ELSE 1 END) AS validation_check
FROM :results_schema.concept_set_validation_failures;

CREATE INDEX idx_concept_set_members_name_id ON :results_schema.concept_set_members(concept_set_name, concept_id);
