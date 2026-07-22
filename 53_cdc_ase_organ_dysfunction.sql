-- 53_cdc_ase_organ_dysfunction.sql
-- CDC ASE organ dysfunction flags using canonical concept sets.

DROP TABLE IF EXISTS :results_schema.ase_organ_dysfunction CASCADE;
CREATE TABLE :results_schema.ase_organ_dysfunction AS
WITH lab_windows AS (
  SELECT
    bc.person_id,
    bc.visit_occurrence_id,
    bc.culture_datetime,
    bc.src_name,
    MAX(l.lactate) FILTER (
      WHERE l.measurement_datetime BETWEEN bc.culture_datetime - INTERVAL '2 days'
                                       AND bc.culture_datetime + INTERVAL '2 days'
    ) AS max_lactate,
    MAX(l.creatinine) FILTER (
      WHERE l.measurement_datetime BETWEEN bc.culture_datetime - INTERVAL '2 days'
                                       AND bc.culture_datetime + INTERVAL '2 days'
    ) AS max_creatinine,
    MIN(l.creatinine) FILTER (
      WHERE l.measurement_datetime < bc.culture_datetime - INTERVAL '2 days'
        AND l.measurement_datetime >= bc.culture_datetime - INTERVAL '365 days'
    ) AS baseline_creatinine,
    MAX(l.bilirubin) FILTER (
      WHERE l.measurement_datetime BETWEEN bc.culture_datetime - INTERVAL '2 days'
                                       AND bc.culture_datetime + INTERVAL '2 days'
    ) AS max_bilirubin,
    MIN(l.bilirubin) FILTER (
      WHERE l.measurement_datetime < bc.culture_datetime - INTERVAL '2 days'
        AND l.measurement_datetime >= bc.culture_datetime - INTERVAL '365 days'
    ) AS baseline_bilirubin,
    MIN(l.platelets) FILTER (
      WHERE l.measurement_datetime BETWEEN bc.culture_datetime - INTERVAL '2 days'
                                       AND bc.culture_datetime + INTERVAL '2 days'
    ) AS min_platelets,
    MAX(l.platelets) FILTER (
      WHERE l.measurement_datetime < bc.culture_datetime - INTERVAL '2 days'
        AND l.measurement_datetime >= bc.culture_datetime - INTERVAL '365 days'
    ) AS baseline_platelets
  FROM :results_schema.cdc_ase_cultures bc
  LEFT JOIN :results_schema.view_labs_core l
    ON l.person_id = bc.person_id
   AND l.measurement_datetime BETWEEN bc.culture_datetime - INTERVAL '365 days'
                                  AND bc.culture_datetime + INTERVAL '2 days'
  GROUP BY bc.person_id, bc.visit_occurrence_id, bc.culture_datetime, bc.src_name
)
SELECT
  bc.person_id,
  bc.visit_occurrence_id,
  bc.culture_datetime,
  bc.src_name,

  -- 1. Vasopressors (+/-2 days)
  EXISTS (
    SELECT 1
    FROM :results_schema.view_vasopressors_nee de
    WHERE de.person_id = bc.person_id
      AND (bc.visit_occurrence_id IS NULL OR de.visit_occurrence_id IS NULL OR de.visit_occurrence_id = bc.visit_occurrence_id)
      AND de.start_datetime BETWEEN bc.culture_datetime - INTERVAL '2 days'
                                AND bc.culture_datetime + INTERVAL '2 days'
  ) AS vaso_init,

  -- 2. Ventilation (+/-2 days)
  EXISTS (
    SELECT 1
    FROM :results_schema.view_ventilation vent
    WHERE vent.person_id = bc.person_id
      AND (bc.visit_occurrence_id IS NULL OR vent.visit_occurrence_id IS NULL OR vent.visit_occurrence_id = bc.visit_occurrence_id)
      AND vent.start_datetime BETWEEN bc.culture_datetime - INTERVAL '2 days'
                                  AND bc.culture_datetime + INTERVAL '2 days'
  ) AS vent_init,

  -- 3. Lactate >= 2.0 mmol/L (+/-2 days)
  (COALESCE(lw.max_lactate, 0) >= 2.0) AS lactate_high,

  -- 4. Renal: creatinine at least doubled from baseline or rises by >= 0.5 mg/dL.
  COALESCE(
    lw.baseline_creatinine > 0
    AND (
      lw.max_creatinine >= 2.0 * lw.baseline_creatinine
      OR lw.max_creatinine - lw.baseline_creatinine >= 0.5
    ),
    false
  ) AS renal_dysfunction,

  -- 5. Hepatic: bilirubin >= 2.0 mg/dL and at least doubled from baseline.
  COALESCE(
    lw.baseline_bilirubin > 0
    AND lw.max_bilirubin >= 2.0
    AND lw.max_bilirubin >= 2.0 * lw.baseline_bilirubin,
    false
  ) AS hepatic_dysfunction,

  -- 6. Hematologic: platelets < 100 and at least 50% decline from baseline.
  COALESCE(
    lw.baseline_platelets >= 100
    AND lw.min_platelets < 100
    AND lw.min_platelets <= 0.5 * lw.baseline_platelets,
    false
  ) AS hematologic_dysfunction,

  COALESCE(
    lw.baseline_creatinine > 0
    AND (
      lw.max_creatinine >= 2.0 * lw.baseline_creatinine
      OR lw.max_creatinine - lw.baseline_creatinine >= 0.5
    ),
    false
  ) AS aki_init,
  COALESCE(
    lw.baseline_bilirubin > 0
    AND lw.max_bilirubin >= 2.0
    AND lw.max_bilirubin >= 2.0 * lw.baseline_bilirubin,
    false
  ) AS hepatic_init,
  COALESCE(
    lw.baseline_platelets >= 100
    AND lw.min_platelets < 100
    AND lw.min_platelets <= 0.5 * lw.baseline_platelets,
    false
  ) AS hematologic_init,

  lw.max_lactate,
  lw.max_creatinine,
  lw.baseline_creatinine,
  lw.max_creatinine - lw.baseline_creatinine AS creatinine_delta,
  lw.max_bilirubin,
  lw.baseline_bilirubin,
  lw.max_bilirubin - lw.baseline_bilirubin AS bilirubin_delta,
  lw.min_platelets,
  lw.baseline_platelets,
  lw.baseline_platelets - lw.min_platelets AS platelet_drop

FROM :results_schema.cdc_ase_cultures bc
JOIN lab_windows lw
  ON lw.person_id = bc.person_id
 AND lw.culture_datetime = bc.culture_datetime
 AND lw.src_name = bc.src_name
 AND lw.visit_occurrence_id IS NOT DISTINCT FROM bc.visit_occurrence_id;
