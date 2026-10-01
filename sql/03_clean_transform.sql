-- =====================================================================
-- 03_clean_transform.sql
-- Staging (TEXT codes) -> clean typed tables with readable labels.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Patch a gap in DfT's code list. casualty_type 33 appears ~5,700
--    times but has no label in the 2025 data guide. 98.5% of those rows
--    have escooter_flag = 1, so we label it as e-scooter / PPT.
--    (Found by the unlabelled-codes check in 04_data_quality_checks.sql.)
-- ---------------------------------------------------------------------
INSERT INTO lookups (field, code, label)
VALUES ('casualty_type', '33', 'E-scooter / personal powered transporter rider')
ON CONFLICT (field, code) DO NOTHING;

-- ---------------------------------------------------------------------
-- A. Highway authority dimension
-- We use local_authority_highway_current: every collision mapped to the
-- council responsible for that road TODAY. This keeps 5-year trends
-- consistent despite boundary changes (Cumbria, North Yorkshire and
-- Somerset in 2023; Barnsley/Sheffield recoded in 2025).
-- DfT's highway lookup is missing names for the newest councils, so we
-- fall back to the district lookup, then a small manual patch.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS public.highway_authorities CASCADE;
CREATE TABLE public.highway_authorities AS
WITH codes AS (
    SELECT DISTINCT local_authority_highway_current AS la_code
    FROM staging.collision_raw
    WHERE local_authority_highway_current NOT IN ('-1', '')
),
manual_patch (code, label) AS (
    VALUES ('E08000038', 'Barnsley'),      -- recoded 1 April 2025 (was E08000016)
           ('E08000039', 'Sheffield')      -- recoded 1 April 2025 (was E08000019)
)
SELECT
    c.la_code,
    COALESCE(h.label, d.label, m.label, 'Unknown (' || c.la_code || ')') AS la_name,
    CASE LEFT(c.la_code, 1)
        WHEN 'E' THEN 'England' WHEN 'W' THEN 'Wales' WHEN 'S' THEN 'Scotland'
    END AS nation
FROM codes c
LEFT JOIN lookups h ON h.field = 'local_authority_highway'     AND h.code = c.la_code
LEFT JOIN lookups d ON d.field = 'local_authority_ons_district' AND d.code = c.la_code
LEFT JOIN manual_patch m ON m.code = c.la_code;

ALTER TABLE public.highway_authorities ADD PRIMARY KEY (la_code);

-- Helper: decode a code for a given field. Keeps the INSERTs readable.
CREATE OR REPLACE FUNCTION lookup_label(p_field TEXT, p_code TEXT)
RETURNS TEXT LANGUAGE sql STABLE AS $$
    SELECT label FROM public.lookups WHERE field = p_field AND code = p_code
$$;

-- ---------------------------------------------------------------------
-- B. Collisions
-- ---------------------------------------------------------------------
TRUNCATE public.collisions CASCADE;
INSERT INTO public.collisions
SELECT
    collision_index,
    TO_DATE(date, 'DD/MM/YYYY'),                              -- '03/10/2024' -> 2024-10-03
    NULLIF(SPLIT_PART(time, ':', 1), '')::SMALLINT,           -- '16:06' -> 16
    day_of_week::SMALLINT,
    NULLIF(NULLIF(local_authority_highway_current, '-1'), ''),
    NULLIF(latitude, '')::NUMERIC,                            -- 53 rows have no location
    NULLIF(longitude, '')::NUMERIC,
    collision_severity::SMALLINT,
    NULLIF(collision_adjusted_severity_serious, '')::NUMERIC,
    number_of_vehicles::SMALLINT,
    number_of_casualties::SMALLINT,
    lookup_label('road_type', road_type),
    NULLIF(speed_limit, '-1')::SMALLINT,                      -- -1 = missing -> NULL
    lookup_label('light_conditions', light_conditions),
    lookup_label('weather_conditions', weather_conditions),
    lookup_label('road_surface_conditions', road_surface_conditions),
    lookup_label('urban_or_rural_area', urban_or_rural_area)
FROM staging.collision_raw;

-- ---------------------------------------------------------------------
-- C. Vehicles
-- ---------------------------------------------------------------------
INSERT INTO public.vehicles
SELECT
    collision_index,
    vehicle_reference::SMALLINT,
    lookup_label('vehicle_type', vehicle_type),
    lookup_label('sex_of_driver', sex_of_driver),
    lookup_label('age_band_of_driver', age_band_of_driver)
FROM staging.vehicle_raw;

-- ---------------------------------------------------------------------
-- D. Casualties
-- ---------------------------------------------------------------------
INSERT INTO public.casualties
SELECT
    collision_index,
    vehicle_reference::SMALLINT,
    casualty_reference::SMALLINT,
    lookup_label('casualty_class', casualty_class),
    lookup_label('casualty_type', casualty_type),
    lookup_label('sex_of_casualty', sex_of_casualty),
    NULLIF(age_of_casualty, '-1')::SMALLINT,
    lookup_label('age_band_of_casualty', age_band_of_casualty),
    casualty_severity::SMALLINT,
    NULLIF(casualty_adjusted_severity_serious, '')::NUMERIC
FROM staging.casualty_raw;

-- ---------------------------------------------------------------------
-- E. Road user group: collapse ~25 casualty types into 7 groups that
--    road safety teams actually report on.
-- ---------------------------------------------------------------------
ALTER TABLE public.casualties ADD COLUMN IF NOT EXISTS road_user_group TEXT;
UPDATE public.casualties SET road_user_group = CASE
    WHEN casualty_type = 'Pedestrian'              THEN 'Pedestrian'
    WHEN casualty_type = 'Cyclist'                 THEN 'Cyclist'
    WHEN casualty_type ILIKE 'E-scooter%'          THEN 'E-scooter rider'
    WHEN casualty_type ILIKE '%motorcycle%'        THEN 'Motorcyclist'
    WHEN casualty_type = 'Car occupant'
      OR casualty_type ILIKE 'Taxi%'               THEN 'Car occupant'
    WHEN casualty_type ILIKE '%goods%'
      OR casualty_type ILIKE 'Van%'                THEN 'Van/goods vehicle occupant'
    ELSE 'Other'
END;

-- ---------------------------------------------------------------------
-- F. Indexes + stats
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_coll_date ON collisions (collision_date);
CREATE INDEX IF NOT EXISTS idx_coll_la   ON collisions (la_code);
CREATE INDEX IF NOT EXISTS idx_cas_coll  ON casualties (collision_id);
ANALYZE collisions; ANALYZE vehicles; ANALYZE casualties;

SELECT 'collisions' AS tbl, COUNT(*) AS clean_rows FROM collisions
UNION ALL SELECT 'vehicles',   COUNT(*) FROM vehicles
UNION ALL SELECT 'casualties', COUNT(*) FROM casualties
UNION ALL SELECT 'highway_authorities', COUNT(*) FROM highway_authorities;
