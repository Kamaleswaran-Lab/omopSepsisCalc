-- 45_create_sepsis3_outcomes.sql
-- Sepsis-3 outcomes - corrected variables
DROP TABLE IF EXISTS :results_schema.sepsis3_cases_with_outcomes;
CREATE TABLE :results_schema.sepsis3_cases_with_outcomes AS
WITH episodes AS (
    SELECT DISTINCT ON (person_id, infection_onset)
        person_id, infection_onset, baseline_sofa, peak_sofa, delta_sofa
    FROM :results_schema.sepsis3_cases
    ORDER BY person_id, infection_onset
),
ep48 AS (
    SELECT *, SUM(CASE WHEN LAG(infection_onset) OVER (PARTITION BY person_id ORDER BY infection_onset) IS NULL 
                  OR infection_onset - LAG(infection_onset) OVER (PARTITION BY person_id ORDER BY infection_onset) >= interval '48 hours'
                 THEN 1 ELSE 0 END) OVER (PARTITION BY person_id ORDER BY infection_onset) AS episode_num
    FROM episodes
)
SELECT f.person_id, f.infection_onset AS t_sepsis3, f.baseline_sofa, f.peak_sofa, f.delta_sofa,
       d.death_date,
       CASE WHEN d.death_date BETWEEN f.infection_onset::date AND f.infection_onset::date + interval '30 days' THEN 1 ELSE 0 END AS died_30d,
       v.visit_occurrence_id, v.visit_start_date, v.visit_end_date
FROM (SELECT DISTINCT ON (person_id, episode_num) * FROM ep48 ORDER BY person_id, episode_num, infection_onset) f
LEFT JOIN :cdm_schema.visit_occurrence v ON v.person_id=f.person_id AND f.infection_onset BETWEEN v.visit_start_datetime AND v.visit_end_datetime
LEFT JOIN :cdm_schema.death d ON d.person_id=f.person_id;
