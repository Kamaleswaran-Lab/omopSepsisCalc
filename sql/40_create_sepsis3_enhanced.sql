-- 40_create_sepsis3_enhanced.sql
-- Build Sepsis-3 windows from infection onset and materialized SOFA scores.

DROP TABLE IF EXISTS :results_schema.sepsis3_windows CASCADE;
DROP TABLE IF EXISTS :results_schema.sepsis3_enhanced CASCADE;
DROP TABLE IF EXISTS :results_schema.sepsis3_cohort CASCADE;
DROP TABLE IF EXISTS :results_schema.sepsis3 CASCADE;

-- 1) Build infection windows
CREATE UNLOGGED TABLE :results_schema.sepsis3_windows AS
SELECT
  io.person_id,
  io.infection_onset,
  io.infection_onset - INTERVAL '24 hours' AS baseline_start,
  io.infection_onset - INTERVAL '48 hours' AS window_start,
  io.infection_onset + INTERVAL '24 hours' AS window_end,
  io.antibiotic_time,
  io.culture_time,
  io.visit_occurrence_id
FROM :results_schema.view_infection_onset io;

CREATE INDEX idx_sepsis3_windows_pid_window
  ON :results_schema.sepsis3_windows (person_id, window_start, window_end);
CLUSTER :results_schema.sepsis3_windows USING idx_sepsis3_windows_pid_window;
ANALYZE :results_schema.sepsis3_windows;

-- 2) Filter time windows first, then aggregate already-scored SOFA rows.
CREATE UNLOGGED TABLE :results_schema.sepsis3_enhanced AS
WITH time_filtered_sofa AS (
  SELECT 
    w.person_id,
    w.infection_onset,
    w.baseline_start,
    w.window_start,
    w.window_end,
    w.antibiotic_time,
    w.culture_time,
    w.visit_occurrence_id,
    sh.hr,
    sh.total_sofa,
    sh.components_observed
  FROM :results_schema.sepsis3_windows w
  LEFT JOIN :results_schema.sofa_hourly sh
    ON sh.person_id = w.person_id
   AND sh.hr BETWEEN w.window_start AND w.window_end
)
SELECT
  person_id,
  visit_occurrence_id,
  infection_onset,
  baseline_start,
  window_end,
  antibiotic_time,
  culture_time,
  'culture_antibiotic_pair'::text AS infection_type,
  
  -- FIX 3: Baseline extended to onset + 2 hours to catch ED admit labs
  COALESCE(MIN(total_sofa) FILTER (WHERE hr BETWEEN baseline_start AND infection_onset + INTERVAL '2 hours'), 0) AS baseline_sofa,
  
  -- FIX 2: Max SOFA must only be calculated AFTER the infection onset, not looking backwards 48 hours
  COALESCE(MAX(total_sofa) FILTER (WHERE hr BETWEEN infection_onset AND window_end), 0) AS max_sofa,
  COALESCE(MAX(total_sofa) FILTER (WHERE hr BETWEEN infection_onset AND window_end), 0) AS peak_sofa,
  
  -- Recalculated delta
  COALESCE(MAX(total_sofa) FILTER (WHERE hr BETWEEN infection_onset AND window_end), 0) - 
  COALESCE(MIN(total_sofa) FILTER (WHERE hr BETWEEN baseline_start AND infection_onset + INTERVAL '2 hours'), 0) AS sofa_delta,
  
  COALESCE(MAX(components_observed), 0) AS max_components_observed,
  
  -- Recalculated boolean flag
  (
    COALESCE(MAX(total_sofa) FILTER (WHERE hr BETWEEN infection_onset AND window_end), 0) - 
    COALESCE(MIN(total_sofa) FILTER (WHERE hr BETWEEN baseline_start AND infection_onset + INTERVAL '2 hours'), 0)
  ) >= 2 AS meets_sepsis3
FROM time_filtered_sofa
GROUP BY person_id, visit_occurrence_id, infection_onset, baseline_start, window_start, window_end, antibiotic_time, culture_time;

ALTER TABLE :results_schema.sepsis3_enhanced SET LOGGED;
CREATE INDEX idx_sepsis3_enhanced_pid_onset ON :results_schema.sepsis3_enhanced (person_id, infection_onset);
ANALYZE :results_schema.sepsis3_enhanced;

-- 3) Sepsis-3 cohort
CREATE TABLE :results_schema.sepsis3_cohort AS
SELECT * FROM :results_schema.sepsis3_enhanced WHERE sofa_delta >= 2;

CREATE INDEX idx_sepsis3_cohort_pid_onset ON :results_schema.sepsis3_cohort (person_id, infection_onset);

-- 4) Compatibility
CREATE TABLE :results_schema.sepsis3 AS SELECT * FROM :results_schema.sepsis3_cohort;

ANALYZE :results_schema.sepsis3_cohort;
ANALYZE :results_schema.sepsis3;

-- validation
SELECT 'windows' AS tbl, COUNT(*) FROM :results_schema.sepsis3_windows
UNION ALL SELECT 'enhanced', COUNT(*) FROM :results_schema.sepsis3_enhanced
UNION ALL SELECT 'cohort_delta_ge2', COUNT(*) FROM :results_schema.sepsis3_cohort;
