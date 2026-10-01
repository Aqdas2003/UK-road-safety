-- =====================================================================
-- 09_powerbi_export.sql
-- Build dashboard-ready views, then export them to CSV for Power BI.
--
-- Model design (what Power BI will see):
--
--   pbi_authorities (1) ──< pbi_collisions (1) ──< pbi_casualties
--   Date table (made in Power BI with DAX) ──< pbi_collisions
--
-- Filters flow from dimensions -> collisions -> casualties, so a slicer
-- on authority, date or speed limit filters both fact tables.
-- =====================================================================

CREATE OR REPLACE VIEW pbi_authorities AS
SELECT la_code, la_name, nation
FROM highway_authorities;

CREATE OR REPLACE VIEW pbi_collisions AS
SELECT
    collision_id,
    collision_date,
    collision_hour,
    lookup_label('day_of_week', day_of_week::TEXT)          AS day_name,
    (day_of_week + 5) % 7 + 1                               AS day_sort,     -- Mon = 1 ... Sun = 7
    la_code,
    lookup_label('collision_severity', severity::TEXT)      AS severity,
    (severity = 1)::INT                                     AS is_fatal,
    CASE WHEN severity = 1 THEN 1 ELSE adj_serious END      AS ksi_adjusted,
    number_of_casualties,
    speed_limit,
    road_type,
    CASE
        WHEN light_conditions = 'Daylight'                  THEN 'Daylight'
        WHEN light_conditions = 'Darkness - lights lit'     THEN 'Dark - lit'
        WHEN light_conditions ILIKE 'Darkness%'
         AND light_conditions NOT ILIKE '%unknown%'         THEN 'Dark - unlit/no lighting'
        ELSE 'Unknown'
    END                                                     AS light,
    weather_conditions,
    road_surface,
    urban_rural,
    latitude,
    longitude
FROM collisions;

CREATE OR REPLACE VIEW pbi_casualties AS
SELECT
    collision_id,
    collision_id || '-' || vehicle_ref || '-' || casualty_ref AS casualty_key,
    road_user_group,
    casualty_class,
    sex,
    age_band,
    CASE WHEN age_band LIKE 'Over%' THEN 99                 -- sort key so bands order
         WHEN age_band ~ '^\d' THEN SPLIT_PART(age_band, ' ', 1)::INT  -- 0, 6, 11, 16...
    END                                                     AS age_band_sort,
    lookup_label('casualty_severity', severity::TEXT)       AS severity,
    (severity = 1)::INT                                     AS is_fatal,
    CASE WHEN severity = 1 THEN 1 ELSE adj_serious END      AS ksi_adjusted
FROM casualties;

-- ---------------------------------------------------------------------
-- Export for Power BI (large files, git-ignored: rebuild with run_all)
-- ---------------------------------------------------------------------
\copy (SELECT * FROM pbi_authorities) TO 'powerbi/data/authorities.csv' WITH (FORMAT csv, HEADER)
\copy (SELECT * FROM pbi_collisions) TO 'powerbi/data/collisions.csv' WITH (FORMAT csv, HEADER)
\copy (SELECT * FROM pbi_casualties) TO 'powerbi/data/casualties.csv' WITH (FORMAT csv, HEADER)

-- ---------------------------------------------------------------------
-- Small summary results (committed to GitHub, used for README charts)
-- ---------------------------------------------------------------------
\copy (SELECT speed_limit, COUNT(*) AS collisions, ROUND(1000.0 * SUM(is_fatal) / COUNT(*), 1) AS fatal_per_1000 FROM pbi_collisions WHERE speed_limit IS NOT NULL GROUP BY 1 ORDER BY 1) TO 'results/speed_limit_severity.csv' WITH (FORMAT csv, HEADER)
\copy (SELECT collision_hour AS hour, COUNT(*) AS collisions, ROUND(100.0 * SUM(ksi_adjusted) / COUNT(*), 1) AS ksi_pct FROM pbi_collisions GROUP BY 1 ORDER BY 1) TO 'results/hourly_profile.csv' WITH (FORMAT csv, HEADER)
\copy (SELECT road_user_group, COUNT(*) AS casualties, SUM(is_fatal) AS killed, ROUND(1000.0 * SUM(is_fatal) / COUNT(*), 1) AS deaths_per_1000 FROM pbi_casualties GROUP BY 1 ORDER BY 4 DESC) TO 'results/road_user_risk.csv' WITH (FORMAT csv, HEADER)
\copy (SELECT EXTRACT(YEAR FROM k.collision_date)::INT AS yr, COUNT(*) AS casualties, SUM(c.is_fatal) AS killed, ROUND(SUM(c.ksi_adjusted))::INT AS ksi_adjusted FROM pbi_casualties c JOIN pbi_collisions k USING (collision_id) GROUP BY 1 ORDER BY 1) TO 'results/yearly_casualties.csv' WITH (FORMAT csv, HEADER)

\echo 'Exported powerbi/data/*.csv and results/*.csv'
