-- 10_view_labs_core.sql
-- Core lab values normalized to SOFA units: bilirubin/creatinine in mg/dL.

CREATE OR REPLACE VIEW :results_schema.view_labs_core AS
SELECT
  m.person_id,
  COALESCE(m.measurement_datetime, m.measurement_date::timestamp) AS measurement_datetime,
  MAX(CASE WHEN cs.concept_set_name = 'platelets' THEN m.value_as_number END) AS platelets,
  MAX(CASE WHEN cs.concept_set_name = 'lactate' THEN m.value_as_number END) AS lactate,
  MAX(CASE WHEN cs.concept_set_name = 'bilirubin' THEN
    CASE
      WHEN m.unit_concept_id = 8753 THEN m.value_as_number / 17.1
      ELSE m.value_as_number
    END
  END) AS bilirubin,
  MAX(CASE WHEN cs.concept_set_name = 'creatinine' THEN
    CASE
      WHEN m.unit_concept_id = 8753 THEN m.value_as_number / 88.4
      ELSE m.value_as_number
    END
  END) AS creatinine
FROM :cdm_schema.measurement m
JOIN :results_schema.concept_set_members cs
  ON cs.concept_id = m.measurement_concept_id
 AND cs.concept_set_name IN ('platelets', 'lactate', 'bilirubin', 'creatinine')
WHERE COALESCE(m.measurement_datetime, m.measurement_date::timestamp) IS NOT NULL
  AND m.value_as_number IS NOT NULL
GROUP BY 1,2;
