-- sql/23_view_infection_onset_enhanced.sql
-- Sepsis-3 infection onset. Explicit IV/IM routes are systemic; unknown routes
-- are treated as systemic because MGH and other sites often leave route NULL
-- after the drug concept set has already excluded topical/non-systemic drugs.

DROP VIEW IF EXISTS :results_schema.view_infection_onset CASCADE;

CREATE OR REPLACE VIEW :results_schema.view_infection_onset AS
WITH params AS (
  SELECT COALESCE(
    (SELECT value::int FROM :results_schema.assumptions WHERE domain='antibiotic' AND parameter='window_hours'),
    72
  ) AS window_hours
),
vocab_iv_routes AS (
  SELECT DISTINCT ca.descendant_concept_id AS route_concept_id
  FROM :vocab_schema.concept_ancestor ca
  WHERE ca.ancestor_concept_id = 4112421  -- Intravenous route
  UNION ALL SELECT 4112421
),
site_top_routes AS (
  SELECT route_concept_id
  FROM (
    SELECT de.route_concept_id, COUNT(*) AS use_count, ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) AS rn
    FROM :results_schema.view_antibiotics de
    WHERE de.route_concept_id IS NOT NULL
    GROUP BY de.route_concept_id
  ) ranked
  WHERE rn <= 15
),
effective_routes AS (
  SELECT route_concept_id FROM vocab_iv_routes
  UNION
  SELECT route_concept_id FROM site_top_routes WHERE NOT EXISTS (SELECT 1 FROM vocab_iv_routes)
  -- STRICT: only IV and IM, NO oral/enteral routes
  UNION ALL SELECT * FROM (VALUES (4171047),(4302612)) AS t(route_concept_id)
),
antibiotics AS (
  SELECT
    de.person_id,
    de.drug_exposure_id,
    de.visit_occurrence_id,
    de.drug_exposure_start_datetime AS abx_start,
    de.route_concept_id,
    CASE
      WHEN de.route_concept_id IS NULL OR de.route_concept_id = 0 THEN 1
      WHEN de.route_concept_id IN (SELECT route_concept_id FROM effective_routes) THEN 1
      ELSE 0
    END AS is_iv_systemic
  FROM :results_schema.view_antibiotics de
),
-- Retain explicit systemic routes and permissive unknown-route records.
filtered_antibiotics AS (
  SELECT a.*
  FROM antibiotics a
  WHERE a.is_iv_systemic = 1
),
paired AS (
  SELECT
    fa.person_id, fa.drug_exposure_id, fa.visit_occurrence_id, c.specimen_id,
    fa.abx_start, c.specimen_datetime AS culture_time,
    LEAST(fa.abx_start, c.specimen_datetime) AS infection_onset,
    ABS(EXTRACT(EPOCH FROM (fa.abx_start - c.specimen_datetime))/3600.0) AS hours_apart,
    fa.is_iv_systemic AS is_iv, fa.route_concept_id
  FROM filtered_antibiotics fa
  JOIN :results_schema.view_cultures c ON c.person_id = fa.person_id
  CROSS JOIN params p
  WHERE c.specimen_datetime IS NOT NULL
    AND (
      (c.specimen_datetime <= fa.abx_start AND EXTRACT(EPOCH FROM (fa.abx_start - c.specimen_datetime))/3600.0 <= p.window_hours)
      OR
      (fa.abx_start < c.specimen_datetime AND EXTRACT(EPOCH FROM (c.specimen_datetime - fa.abx_start))/3600.0 <= 24)
    )
)
SELECT DISTINCT ON (person_id, drug_exposure_id, specimen_id)
  person_id, infection_onset, abx_start AS antibiotic_time, culture_time, hours_apart, drug_exposure_id, specimen_id, is_iv, route_concept_id, visit_occurrence_id
FROM paired
ORDER BY person_id, drug_exposure_id, specimen_id, hours_apart;
