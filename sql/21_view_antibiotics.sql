-- 21_view_antibiotics.sql
-- Candidate systemic antibiotics for Sepsis-3 infection onset. Keep unknown
-- routes/visits because several sites, including MGH, have sparse route
-- mapping. Explicit non-systemic routes are still excluded.

CREATE OR REPLACE VIEW :results_schema.view_antibiotics AS
SELECT
  de.person_id,
  COALESCE(de.drug_exposure_start_datetime, de.drug_exposure_start_date::timestamp) AS drug_exposure_start_datetime,
  de.visit_occurrence_id,
  de.route_concept_id,
  de.drug_exposure_id,
  'drug_exposure'::text AS src_name
FROM :cdm_schema.drug_exposure de
JOIN :results_schema.concept_set_members cs
  ON cs.concept_id = de.drug_concept_id
 AND cs.concept_set_name = 'antibiotic'
WHERE COALESCE(de.drug_exposure_start_datetime, de.drug_exposure_start_date::timestamp) IS NOT NULL
  -- Exclude explicit oral/enteral routes. Do not require visit_concept_id:
  -- 32037 is an ICU visit_detail_concept_id, and NULL visits are common.
  AND COALESCE(de.route_concept_id, 0) NOT IN (4132161, 4132254, 4132711);
