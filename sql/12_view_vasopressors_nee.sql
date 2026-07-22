-- 12_view_vasopressors_nee.sql
-- Vasopressor exposure windows using canonical drug concept sets.

CREATE OR REPLACE VIEW :results_schema.view_vasopressors_nee AS
SELECT
  de.person_id,
  de.visit_occurrence_id,
  COALESCE(de.drug_exposure_start_datetime, de.drug_exposure_start_date::timestamp) AS start_datetime,
  COALESCE(
    de.drug_exposure_end_datetime,
    de.drug_exposure_end_date::timestamp,
    COALESCE(de.drug_exposure_start_datetime, de.drug_exposure_start_date::timestamp) + interval '1 hour'
  ) AS end_datetime,
  vf.nee_factor
FROM :cdm_schema.drug_exposure de
JOIN :results_schema.vasopressor_nee_factors vf
  ON vf.concept_id = de.drug_concept_id
WHERE COALESCE(de.drug_exposure_start_datetime, de.drug_exposure_start_date::timestamp) IS NOT NULL;
