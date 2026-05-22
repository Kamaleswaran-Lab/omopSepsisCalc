-- RUN_ALL_enhanced.sql
-- Canonical multi-site OMOP SOFA / Sepsis-3 / CDC ASE runner.
--
-- Override schemas from psql as needed:
-- psql ... -v results_schema=results_site_a -v cdm_schema=omopcdm -v vocab_schema=vocabulary -f sql/RUN_ALL_enhanced.sql

\if :{?results_schema}
\else
  \set results_schema results
\endif

\if :{?cdm_schema}
\else
  \set cdm_schema omopcdm
\endif

\if :{?vocab_schema}
\else
  \set vocab_schema vocabulary
\endif

-- Azure tuning (Removed unsafe hardcoded memory/parallelism limits)
-- SET work_mem = '4GB';
-- SET maintenance_work_mem = '2GB';
-- SET max_parallel_workers_per_gather = 0;
-- SET temp_buffers = '1GB';
-- SET synchronous_commit = off;

-- Keep this for long-running analytical queries
SET statement_timeout = 0;

-- core views (each \ir on its own line!)
\ir 00_create_schemas.sql
\ir 01_create_assumptions_table.sql
\ir 03_create_concept_sets.sql
\ir 02_create_indexes.sql

DROP VIEW IF EXISTS :results_schema.view_labs_core CASCADE;
\ir 10_view_labs_core.sql

DROP VIEW IF EXISTS :results_schema.view_vitals_core CASCADE;
\ir 11_view_vitals_core.sql

DROP VIEW IF EXISTS :results_schema.view_vasopressors_nee CASCADE;
\ir 12_view_vasopressors_nee.sql

DROP VIEW IF EXISTS :results_schema.view_ventilation CASCADE;
\ir 13_view_ventilation.sql

DROP VIEW IF EXISTS :results_schema.view_neuro CASCADE;
\ir 14_view_neuro.sql

DROP VIEW IF EXISTS :results_schema.view_urine_24h CASCADE;
\ir 15_view_urine_24h.sql

DROP VIEW IF EXISTS :results_schema.view_rrt CASCADE;
\ir 16_view_rrt.sql

-- infection windows
DROP VIEW IF EXISTS :results_schema.view_pao2_fio2_pairs CASCADE;
\ir 20_view_pao2_fio2_pairs.sql

DROP VIEW IF EXISTS :results_schema.view_antibiotics CASCADE;
\ir 21_view_antibiotics.sql

DROP VIEW IF EXISTS :results_schema.view_cultures CASCADE;
\ir 22_view_cultures.sql

DROP VIEW IF EXISTS :results_schema.view_infection_onset CASCADE;
\ir 23_view_infection_onset_enhanced.sql

-- SOFA components
DROP VIEW IF EXISTS :results_schema.vw_sofa_components CASCADE;
\ir 30_view_sofa_components.sql

\ir 31_create_sofa_hourly.sql

-- Sepsis-3
DROP TABLE IF EXISTS :results_schema.sepsis3_windows CASCADE;
DROP TABLE IF EXISTS :results_schema.sepsis3_enhanced CASCADE;
DROP TABLE IF EXISTS :results_schema.sepsis3_cohort CASCADE;
DROP TABLE IF EXISTS :results_schema.sepsis3 CASCADE;
\ir 40_create_sepsis3_enhanced.sql

DROP TABLE IF EXISTS :results_schema.sepsis3_enhanced_collapsed CASCADE;
\ir 41_create_sepsis3_collapsed_48h.sql

-- CDC ASE Tables
DROP TABLE IF EXISTS :results_schema.ase_parameters CASCADE;
\ir 50_cdc_ase_parameters.sql

DROP TABLE IF EXISTS :results_schema.ase_blood_cultures CASCADE;
\ir 51_cdc_ase_blood_cultures.sql

DROP TABLE IF EXISTS :results_schema.ase_qad CASCADE;
\ir 52_cdc_ase_qad.sql

DROP TABLE IF EXISTS :results_schema.ase_organ_dysfunction CASCADE;
\ir 53_cdc_ase_organ_dysfunction.sql

DROP TABLE IF EXISTS :results_schema.ase_cases CASCADE;
\ir 54_cdc_ase_cases.sql

DROP TABLE IF EXISTS :results_schema.ase_with_sofa CASCADE;
\ir 55_cdc_ase_with_sofa.sql

DROP TABLE IF EXISTS :results_schema.cdc_ase_cohort_final CASCADE;
\ir 56_cdc_ase_cohort_final.sql

-- Comparison
DROP TABLE IF EXISTS :results_schema.sepsis_cohort_comparison CASCADE;
\ir 61_create_sepsis_cohort_comparison.sql

-- Reset and analyze (Commented out resets matching the SETs above)
-- RESET work_mem;
-- RESET maintenance_work_mem;
-- RESET max_parallel_workers_per_gather;
-- RESET temp_buffers;
-- RESET synchronous_commit;

ANALYZE :results_schema.sofa_hourly;
ANALYZE :results_schema.sepsis3_cohort;
ANALYZE :results_schema.cdc_ase_cohort_final;

-- In-line Cohort Sanity Check
SELECT 
    'SOFA Missingness Check' AS metric,
    COUNT(*) AS total_sepsis3_episodes,
    ROUND(100.0 * SUM(CASE WHEN max_components_observed < 4 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_episodes_with_high_missingness
FROM :results_schema.sepsis3_enhanced
WHERE meets_sepsis3 = true;
