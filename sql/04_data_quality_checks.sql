-- =====================================================================
-- 04_data_quality_checks.sql
-- Do the three tables agree with each other, and what's missing?
-- =====================================================================

-- Q1. Coverage by year
SELECT EXTRACT(YEAR FROM collision_date)::INT AS yr, COUNT(*) AS collisions
FROM collisions GROUP BY 1 ORDER BY 1;

-- Q2. Referential integrity: every casualty and vehicle must belong to a
--     collision. (The foreign keys enforce this; this proves it.)
SELECT
    (SELECT COUNT(*) FROM casualties c
      WHERE NOT EXISTS (SELECT 1 FROM collisions k WHERE k.collision_id = c.collision_id)) AS orphan_casualties,
    (SELECT COUNT(*) FROM vehicles v
      WHERE NOT EXISTS (SELECT 1 FROM collisions k WHERE k.collision_id = v.collision_id)) AS orphan_vehicles;

-- Q3. Internal consistency: does number_of_casualties on each collision
--     match the actual casualty rows? Mismatches would mean double counting.
WITH actual AS (
    SELECT collision_id, COUNT(*) AS n FROM casualties GROUP BY collision_id
)
SELECT
    COUNT(*)                                        AS collisions_checked,
    COUNT(*) FILTER (WHERE k.number_of_casualties <> a.n) AS mismatches
FROM collisions k JOIN actual a USING (collision_id);

-- Q4. Missing values in fields used for analysis
SELECT
    COUNT(*) FILTER (WHERE latitude IS NULL)     AS no_location,
    COUNT(*) FILTER (WHERE speed_limit IS NULL)  AS no_speed_limit,
    COUNT(*) FILTER (WHERE la_code IS NULL)      AS no_authority,
    COUNT(*) FILTER (WHERE light_conditions ILIKE '%missing%'
                        OR light_conditions ILIKE '%unknown%') AS light_unknown,
    COUNT(*) FILTER (WHERE weather_conditions IN ('Unknown', 'Other')
                        OR weather_conditions ILIKE '%missing%') AS weather_unknown
FROM collisions;

-- Q5. Why we use ADJUSTED severity. Police forces moved to injury-based
--     reporting (CRASH) at different times, which records more injuries as
--     "serious". Raw serious counts therefore rise partly due to recording.
--     DfT's adjusted figures estimate what each force would have reported
--     under injury-based recording, making years comparable.
SELECT
    EXTRACT(YEAR FROM collision_date)::INT          AS yr,
    COUNT(*) FILTER (WHERE severity = 2)            AS serious_as_reported,
    ROUND(SUM(adj_serious))::INT                    AS serious_adjusted
FROM collisions
GROUP BY 1 ORDER BY 1;

-- Q6. Codes with no label in the lookup table. After the patch in
--     03_clean_transform.sql this should return zero rows.
SELECT 'casualty_type' AS field, COUNT(*) AS unlabelled
FROM casualties WHERE casualty_type IS NULL
UNION ALL SELECT 'vehicle_type', COUNT(*) FROM vehicles WHERE vehicle_type IS NULL
UNION ALL SELECT 'road_type',    COUNT(*) FROM collisions WHERE road_type IS NULL
UNION ALL SELECT 'light_conditions', COUNT(*) FROM collisions WHERE light_conditions IS NULL;
