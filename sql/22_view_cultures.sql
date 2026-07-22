DROP VIEW IF EXISTS :results_schema.view_cultures CASCADE;

CREATE OR REPLACE VIEW :results_schema.view_cultures AS
WITH meas_cult AS (
  SELECT
    m.person_id,
    m.measurement_id AS specimen_id,
    COALESCE(m.measurement_datetime, m.measurement_date::timestamp) AS specimen_datetime,
    m.measurement_concept_id AS source_concept_id,
    m.visit_occurrence_id,
    'measurement_concept'::text AS src_name
  FROM :cdm_schema.measurement m
  JOIN :results_schema.concept_set_members cs
    ON cs.concept_id = m.measurement_concept_id
   AND cs.concept_set_name = 'culture_measurement'
),
meas_source_cult AS (
  SELECT
    m.person_id,
    m.measurement_id AS specimen_id,
    COALESCE(m.measurement_datetime, m.measurement_date::timestamp) AS specimen_datetime,
    m.measurement_concept_id AS source_concept_id,
    m.visit_occurrence_id,
    'measurement_source_value'::text AS src_name
  FROM :cdm_schema.measurement m
  LEFT JOIN :vocab_schema.concept c
    ON c.concept_id = m.measurement_concept_id
  WHERE COALESCE(m.measurement_source_value, c.concept_name, '') ILIKE ANY (
    ARRAY['%blood culture%', '%blood cx%', '%bcx%', '%blood cult%']
  )
),
obs_cult AS (
  SELECT
    o.person_id,
    o.observation_id AS specimen_id,
    COALESCE(o.observation_datetime, o.observation_date::timestamp) AS specimen_datetime,
    o.observation_concept_id AS source_concept_id,
    o.visit_occurrence_id,
    'observation'::text AS src_name
  FROM :cdm_schema.observation o
  LEFT JOIN :results_schema.concept_set_members cs
    ON cs.concept_id = o.observation_concept_id
   AND cs.concept_set_name = 'culture_observation'
  LEFT JOIN :vocab_schema.concept c
    ON c.concept_id = o.observation_concept_id
  WHERE cs.concept_id IS NOT NULL
     OR COALESCE(o.observation_source_value, c.concept_name, '') ILIKE ANY (
       ARRAY['%blood culture%', '%blood cx%', '%bcx%', '%blood cult%']
     )
),
spec_cult AS (
  SELECT
    s.person_id,
    s.specimen_id,
    COALESCE(s.specimen_datetime, s.specimen_date::timestamp) AS specimen_datetime,
    s.specimen_concept_id AS source_concept_id,
    NULL::bigint AS visit_occurrence_id,
    'specimen_concept'::text AS src_name
  FROM :cdm_schema.specimen s
  JOIN :results_schema.concept_set_members cs
    ON cs.concept_id = s.specimen_concept_id
   AND cs.concept_set_name = 'culture_specimen'
),
spec_source_cult AS (
  SELECT
    s.person_id,
    s.specimen_id,
    COALESCE(s.specimen_datetime, s.specimen_date::timestamp) AS specimen_datetime,
    s.specimen_concept_id AS source_concept_id,
    NULL::bigint AS visit_occurrence_id,
    'specimen_source_value'::text AS src_name
  FROM :cdm_schema.specimen s
  LEFT JOIN :vocab_schema.concept c
    ON c.concept_id = s.specimen_concept_id
  WHERE COALESCE(s.specimen_source_value, c.concept_name, '') ILIKE ANY (
    ARRAY['%blood culture%', '%blood cx%', '%bcx%', '%blood cult%']
  )
),
proc_cult AS (
  SELECT
    po.person_id,
    po.procedure_occurrence_id AS specimen_id,
    COALESCE(po.procedure_datetime, po.procedure_date::timestamp) AS specimen_datetime,
    po.procedure_concept_id AS source_concept_id,
    po.visit_occurrence_id,
    'procedure'::text AS src_name
  FROM :cdm_schema.procedure_occurrence po
  WHERE po.procedure_source_value ILIKE '%blood culture%'
     OR po.procedure_source_value ILIKE '%blood cx%'
     OR po.procedure_source_value ILIKE '%bcx%'
     OR po.procedure_concept_id IN (
       SELECT concept_id FROM :vocab_schema.concept
       WHERE concept_name ILIKE '%blood culture%' AND domain_id='Procedure'
     )
)
SELECT DISTINCT ON (person_id, specimen_id, specimen_datetime, src_name)
  person_id,
  specimen_id,
  specimen_datetime,
  source_concept_id,
  visit_occurrence_id,
  src_name
FROM (
  SELECT * FROM meas_cult
  UNION ALL SELECT * FROM meas_source_cult
  UNION ALL SELECT * FROM obs_cult
  UNION ALL SELECT * FROM spec_cult
  UNION ALL SELECT * FROM spec_source_cult
  UNION ALL SELECT * FROM proc_cult
) u
WHERE specimen_datetime IS NOT NULL
ORDER BY person_id, specimen_id, specimen_datetime, src_name;
