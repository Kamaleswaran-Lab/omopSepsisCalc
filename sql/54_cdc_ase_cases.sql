DROP TABLE IF EXISTS :results_schema.ase_cases CASCADE;
CREATE TABLE :results_schema.ase_cases AS
SELECT
  od.person_id,
  COALESCE(od.visit_occurrence_id, qad.visit_occurrence_id) AS visit_occurrence_id,
  od.culture_datetime AS infection_onset,
  qad.qad_start,
  qad.qad_end,
  qad.qad_days,
  qad.qad_duration
FROM :results_schema.ase_organ_dysfunction od
JOIN :results_schema.ase_qad qad
  ON qad.person_id = od.person_id
 AND (
      qad.visit_occurrence_id IS NOT DISTINCT FROM od.visit_occurrence_id
      OR od.visit_occurrence_id IS NULL
      OR qad.visit_occurrence_id IS NULL
 )
 AND qad.qad_start BETWEEN (od.culture_datetime::date - INTERVAL '2 days')::date
                       AND (od.culture_datetime::date + INTERVAL '2 days')::date
WHERE (
  od.vaso_init
  OR od.vent_init
  OR od.lactate_high
  OR od.renal_dysfunction
  OR od.hepatic_dysfunction
  OR od.hematologic_dysfunction
);
