-- 51_cdc_ase_blood_cultures.sql
-- CDC ASE blood-culture anchors. This intentionally does not use the
-- Sepsis-3 infection-onset view because that view applies IV/systemic
-- antibiotic restrictions that are not valid for CDC QAD construction.

DROP TABLE IF EXISTS :results_schema.cdc_ase_cultures CASCADE;
CREATE TABLE :results_schema.cdc_ase_cultures AS
WITH culture_candidates AS (
  SELECT
    c.person_id,
    c.specimen_id,
    c.specimen_datetime,
    c.source_concept_id,
    COALESCE(c.visit_occurrence_id, inferred_visit.visit_occurrence_id) AS visit_occurrence_id
  FROM :results_schema.view_cultures c
  LEFT JOIN LATERAL (
    SELECT v.visit_occurrence_id
    FROM :cdm_schema.visit_occurrence v
    WHERE c.visit_occurrence_id IS NULL
      AND v.person_id = c.person_id
      AND c.specimen_datetime BETWEEN v.visit_start_datetime
                                  AND COALESCE(v.visit_end_datetime, v.visit_start_datetime + INTERVAL '30 days')
    ORDER BY v.visit_start_datetime DESC
    LIMIT 1
  ) inferred_visit ON TRUE
  WHERE c.specimen_datetime IS NOT NULL
)
SELECT
  person_id,
  visit_occurrence_id,
  specimen_id,
  specimen_datetime AS culture_time,
  specimen_datetime AS culture_datetime,
  specimen_datetime AS culture_start,
  NULL::timestamp AS antibiotic_start,
  source_concept_id,
  'blood_culture'::text AS culture_site
FROM culture_candidates;
