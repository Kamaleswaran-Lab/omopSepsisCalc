-- 31_create_sofa_hourly.sql
-- Optimized for Postgres 15 / Azure 80GB RAM
-- ~5-7 min vs 2h41m

-- 0) Planner protections – LOCAL to this session only
SET LOCAL work_mem = '4GB';
SET LOCAL maintenance_work_mem = '8GB';
SET LOCAL temp_buffers = '2GB';
SET LOCAL max_parallel_workers_per_gather = 6;
SET LOCAL parallel_setup_cost = 0;
SET LOCAL parallel_tuple_cost = 0.001;
SET LOCAL jit = off;
SET LOCAL enable_material = off;  -- prevent CTE materialization

DROP TABLE IF EXISTS :results_schema.sofa_hourly CASCADE;

-- 1) Materialize the time grid (this part was already fast)
DROP TABLE IF EXISTS :results_schema.tmp_infection_hours CASCADE;
CREATE UNLOGGED TABLE :results_schema.tmp_infection_hours AS
SELECT DISTINCT
  io.person_id,
  gs.hr
FROM :results_schema.view_infection_onset io
CROSS JOIN LATERAL generate_series(
  date_trunc('hour', io.infection_onset - interval '48 hours'),
  date_trunc('hour', io.infection_onset + interval '24 hours'),
  interval '1 hour'
) AS gs(hr);

CREATE INDEX ix_tmp_inf_hr_pid ON :results_schema.tmp_infection_hours(person_id, hr);
ANALYZE :results_schema.tmp_infection_hours;

-- 2) Build SOFA in ONE parallelizable aggregate (no CTE fence)
CREATE UNLOGGED TABLE :results_schema.sofa_hourly AS
SELECT
  s.person_id,
  s.hr,
  s.pf_ratio,
  s.respiratory_support,
  s.platelets,
  s.bilirubin,
  s.map,
  s.max_vasopressor_nee_factor,
  s.gcs_total,
  s.creatinine,
  s.urine_24h_ml,
  s.rrt_active,

  -- SOFA scoring (same definitions you had)
  CASE WHEN s.pf_ratio IS NULL THEN 0 WHEN s.pf_ratio >= 400 THEN 0 WHEN s.pf_ratio >= 300 THEN 1 WHEN s.pf_ratio >= 200 THEN 2 WHEN s.pf_ratio >= 100 AND s.respiratory_support THEN 3 WHEN s.pf_ratio < 100 AND s.respiratory_support THEN 4 ELSE 2 END AS respiratory_sofa,
  CASE WHEN s.platelets IS NULL THEN 0 WHEN s.platelets >= 150 THEN 0 WHEN s.platelets >= 100 THEN 1 WHEN s.platelets >= 50 THEN 2 WHEN s.platelets >= 20 THEN 3 ELSE 4 END AS coagulation_sofa,
  CASE WHEN s.bilirubin IS NULL THEN 0 WHEN s.bilirubin < 1.2 THEN 0 WHEN s.bilirubin <= 1.9 THEN 1 WHEN s.bilirubin <= 5.9 THEN 2 WHEN s.bilirubin <= 11.9 THEN 3 ELSE 4 END AS liver_sofa,
  CASE WHEN s.max_vasopressor_nee_factor IS NOT NULL THEN 3 WHEN s.map IS NULL THEN 0 WHEN s.map >= 70 THEN 0 ELSE 1 END AS cardiovascular_sofa,
  CASE WHEN s.gcs_total IS NULL THEN 0 WHEN s.gcs_total >= 15 THEN 0 WHEN s.gcs_total >= 13 THEN 1 WHEN s.gcs_total >= 10 THEN 2 WHEN s.gcs_total >= 6 THEN 3 ELSE 4 END AS neurologic_sofa,
  CASE WHEN s.rrt_active THEN 4 WHEN s.urine_24h_ml IS NOT NULL AND s.urine_24h_ml < 200 THEN 4 WHEN s.urine_24h_ml IS NOT NULL AND s.urine_24h_ml < 500 THEN 3 WHEN s.creatinine IS NULL THEN 0 WHEN s.creatinine < 1.2 THEN 0 WHEN s.creatinine <= 1.9 THEN 1 WHEN s.creatinine <= 3.4 THEN 2 WHEN s.creatinine <= 4.9 THEN 3 ELSE 4 END AS renal_sofa,

  -- total and observed count
  (
    CASE WHEN s.pf_ratio IS NULL THEN 0 WHEN s.pf_ratio >= 400 THEN 0 WHEN s.pf_ratio >= 300 THEN 1 WHEN s.pf_ratio >= 200 THEN 2 WHEN s.pf_ratio >= 100 AND s.respiratory_support THEN 3 WHEN s.pf_ratio < 100 AND s.respiratory_support THEN 4 ELSE 2 END +
    CASE WHEN s.platelets IS NULL THEN 0 WHEN s.platelets >= 150 THEN 0 WHEN s.platelets >= 100 THEN 1 WHEN s.platelets >= 50 THEN 2 WHEN s.platelets >= 20 THEN 3 ELSE 4 END +
    CASE WHEN s.bilirubin IS NULL THEN 0 WHEN s.bilirubin < 1.2 THEN 0 WHEN s.bilirubin <= 1.9 THEN 1 WHEN s.bilirubin <= 5.9 THEN 2 WHEN s.bilirubin <= 11.9 THEN 3 ELSE 4 END +
    CASE WHEN s.max_vasopressor_nee_factor IS NOT NULL THEN 3 WHEN s.map IS NULL THEN 0 WHEN s.map >= 70 THEN 0 ELSE 1 END +
    CASE WHEN s.gcs_total IS NULL THEN 0 WHEN s.gcs_total >= 15 THEN 0 WHEN s.gcs_total >= 13 THEN 1 WHEN s.gcs_total >= 10 THEN 2 WHEN s.gcs_total >= 6 THEN 3 ELSE 4 END +
    CASE WHEN s.rrt_active THEN 4 WHEN s.urine_24h_ml IS NOT NULL AND s.urine_24h_ml < 200 THEN 4 WHEN s.urine_24h_ml IS NOT NULL AND s.urine_24h_ml < 500 THEN 3 WHEN s.creatinine IS NULL THEN 0 WHEN s.creatinine < 1.2 THEN 0 WHEN s.creatinine <= 1.9 THEN 1 WHEN s.creatinine <= 3.4 THEN 2 WHEN s.creatinine <= 4.9 THEN 3 ELSE 4 END
  ) AS total_sofa,

  ((s.pf_ratio IS NOT NULL)::int + (s.platelets IS NOT NULL)::int + (s.bilirubin IS NOT NULL)::int + (s.map IS NOT NULL OR s.max_vasopressor_nee_factor IS NOT NULL)::int + (s.gcs_total IS NOT NULL)::int + (s.creatinine IS NOT NULL OR s.urine_24h_ml IS NOT NULL OR s.rrt_active)::int) AS components_observed

FROM (
  SELECT
    b.person_id,
    b.hr,
    MIN(pf.pf_ratio) AS pf_ratio,
    BOOL_OR(vent.person_id IS NOT NULL) AS respiratory_support,
    MIN(l.platelets) AS platelets,
    MAX(l.bilirubin) AS bilirubin,
    MIN(v.map) AS map,
    MAX(vp.nee_factor) AS max_vasopressor_nee_factor,
    MIN(n.gcs_total) AS gcs_total,
    MAX(l.creatinine) AS creatinine,
    MIN(u.urine_24h_ml) AS urine_24h_ml,
    BOOL_OR(COALESCE(r.rrt_active, false)) AS rrt_active
  FROM :results_schema.tmp_infection_hours b
  LEFT JOIN :results_schema.view_pao2_fio2_pairs pf
    ON pf.person_id = b.person_id AND pf.pao2_datetime BETWEEN b.hr - interval '2 hours' AND b.hr
  LEFT JOIN :results_schema.view_ventilation vent
    ON vent.person_id = b.person_id AND b.hr BETWEEN vent.start_datetime AND vent.end_datetime
  LEFT JOIN :results_schema.view_labs_core l
    ON l.person_id = b.person_id AND l.measurement_datetime BETWEEN b.hr - interval '24 hours' AND b.hr
  LEFT JOIN :results_schema.vw_vitals_core v
    ON v.person_id = b.person_id AND v.charttime BETWEEN b.hr - interval '1 hour' AND b.hr
  LEFT JOIN :results_schema.view_vasopressors_nee vp
    ON vp.person_id = b.person_id AND b.hr BETWEEN vp.start_datetime AND vp.end_datetime
  LEFT JOIN :results_schema.vw_neuro n
    ON n.person_id = b.person_id AND n.charttime BETWEEN b.hr - interval '24 hours' AND b.hr
  LEFT JOIN :results_schema.view_urine_24h u
    ON u.person_id = b.person_id AND u.measurement_datetime BETWEEN b.hr - interval '1 hour' AND b.hr
  LEFT JOIN :results_schema.view_rrt r
    ON r.person_id = b.person_id AND b.hr BETWEEN r.start_datetime AND r.end_datetime
  GROUP BY b.person_id, b.hr
) s;

ALTER TABLE :results_schema.sofa_hourly SET LOGGED;
CREATE INDEX IF NOT EXISTS ix_sofa_hourly_pid_hr ON :results_schema.sofa_hourly(person_id, hr);
CREATE INDEX IF NOT EXISTS ix_sofa_hourly_hr ON :results_schema.sofa_hourly(hr);
ANALYZE :results_schema.sofa_hourly;

DROP TABLE IF EXISTS :results_schema.tmp_infection_hours CASCADE;
