-- 13_view_ventilation.sql
-- Respiratory support windows. Duration is approximated when source end time is absent.

CREATE OR REPLACE VIEW :results_schema.view_ventilation AS
SELECT
  po.person_id,
  po.visit_occurrence_id,
  COALESCE(po.procedure_datetime, po.procedure_date::timestamp) AS start_datetime,
  COALESCE(po.procedure_datetime, po.procedure_date::timestamp) + interval '1 day' AS end_datetime
FROM :cdm_schema.procedure_occurrence po
JOIN :results_schema.concept_set_members cs
  ON cs.concept_id = po.procedure_concept_id
 AND cs.concept_set_name = 'ventilation'
WHERE COALESCE(po.procedure_datetime, po.procedure_date::timestamp) IS NOT NULL;
