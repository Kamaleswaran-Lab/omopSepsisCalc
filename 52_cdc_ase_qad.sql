-- 52_cdc_ase_qad.sql
-- CDC ASE qualifying antimicrobial days. Allows one missed calendar day inside
-- a course and evaluates duration by calendar span, not raw administration rows.

DROP TABLE IF EXISTS :results_schema.ase_qad CASCADE;
CREATE TABLE :results_schema.ase_qad AS
WITH abx_days AS (
  SELECT DISTINCT
    de.person_id,
    COALESCE(de.visit_occurrence_id, inferred_visit.visit_occurrence_id) AS visit_occurrence_id,
    COALESCE(de.drug_exposure_start_datetime, de.drug_exposure_start_date::timestamp)::date AS abx_day,
    'drug_exposure'::text AS src_name
  FROM :cdm_schema.drug_exposure de
  JOIN :results_schema.concept_set_members cs
    ON cs.concept_id = de.drug_concept_id
   AND cs.concept_set_name = 'antibiotic'
  LEFT JOIN LATERAL (
    SELECT v.visit_occurrence_id
    FROM :cdm_schema.visit_occurrence v
    WHERE de.visit_occurrence_id IS NULL
      AND v.person_id = de.person_id
      AND COALESCE(de.drug_exposure_start_datetime, de.drug_exposure_start_date::timestamp)
          BETWEEN v.visit_start_datetime
              AND COALESCE(v.visit_end_datetime, v.visit_start_datetime + INTERVAL '30 days')
    ORDER BY v.visit_start_datetime DESC
    LIMIT 1
  ) inferred_visit ON TRUE
  WHERE COALESCE(de.drug_exposure_start_datetime, de.drug_exposure_start_date::timestamp) IS NOT NULL
),
ordered_days AS (
  SELECT *,
    LAG(abx_day) OVER (PARTITION BY person_id, visit_occurrence_id ORDER BY abx_day) AS prev_day
  FROM abx_days
),
course_flags AS (
  SELECT *,
    CASE
      WHEN prev_day IS NULL
        OR abx_day - prev_day > (SELECT qad_max_gap_days + 1 FROM :results_schema.cdc_ase_parameters)
      THEN 1 ELSE 0
    END AS is_new_course
  FROM ordered_days
),
course_ids AS (
  SELECT *,
    SUM(is_new_course) OVER (
      PARTITION BY person_id, visit_occurrence_id
      ORDER BY abx_day
      ROWS UNBOUNDED PRECEDING
    ) AS course_id
  FROM course_flags
)
SELECT
  person_id,
  visit_occurrence_id,
  MIN(abx_day) AS qad_start,
  MAX(abx_day) AS qad_end,
  MIN(src_name) AS src_name,
  COUNT(*) AS antimicrobial_days_observed,
  ((MAX(abx_day) - MIN(abx_day)) + 1)::integer AS qad_days,
  ((MAX(abx_day) - MIN(abx_day)) + 1)::integer AS qad_duration
FROM course_ids
GROUP BY person_id, visit_occurrence_id, course_id
HAVING ((MAX(abx_day) - MIN(abx_day)) + 1) >= (SELECT qad_min_days FROM :results_schema.cdc_ase_parameters);
