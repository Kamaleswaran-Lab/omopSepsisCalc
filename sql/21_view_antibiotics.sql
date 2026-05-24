-- 21_view_antibiotics.sql
-- Filtered for systemic/severe infections only to prevent Sepsis-3 over-calling

CREATE OR REPLACE VIEW :results_schema.view_antibiotics AS
SELECT
  de.person_id,
  COALESCE(de.drug_exposure_start_datetime, de.drug_exposure_start_date::timestamp) AS drug_exposure_start_datetime,
  de.visit_occurrence_id,
  de.route_concept_id,
  de.drug_exposure_id
FROM :cdm_schema.drug_exposure de
JOIN :results_schema.concept_set_members cs
  ON cs.concept_id = de.drug_concept_id
 AND cs.concept_set_name = 'antibiotic'
LEFT JOIN :cdm_schema.visit_occurrence v 
  ON v.visit_occurrence_id = de.visit_occurrence_id
WHERE COALESCE(de.drug_exposure_start_datetime, de.drug_exposure_start_date::timestamp) IS NOT NULL
  -- FIX: Exclude explicit Oral, Gastrostomy, and Nasogastric routes
  AND COALESCE(de.route_concept_id, 0) NOT IN (4132161, 4132254, 4132711)
  -- FIX: If route is NULL or 0, mandate that it occurred during an Inpatient (9201) or ER (9203) visit
  AND (
    de.route_concept_id IN (4171047, 4302612) -- Explicit IV/IM
    OR 
    v.visit_concept_id IN (9201, 9203, 32037) -- Inpatient, ER, or Intensive Care
  );
