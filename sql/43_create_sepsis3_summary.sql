-- 43_create_sepsis3_summary.sql
-- Summary of the final collapsed Sepsis-3 cohort

DROP TABLE IF EXISTS :results_schema.sepsis3_summary CASCADE;

CREATE TABLE :results_schema.sepsis3_summary AS 
SELECT 
  COUNT(DISTINCT person_id) AS total_patients,
  COUNT(*) AS total_episodes,
  ROUND(COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT person_id), 0), 2) AS episodes_per_patient,
  ROUND(AVG(max_sofa), 1) AS avg_max_sofa,
  MIN(infection_onset) AS cohort_start_date,
  MAX(infection_onset) AS cohort_end_date
FROM :results_schema.sepsis3_enhanced_collapsed;
