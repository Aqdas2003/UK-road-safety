-- =====================================================================
-- 02_load_data.sql
-- Bulk-load the CSVs into staging. HEADER skips the first row, because
-- these files (unlike Land Registry) DO include column names.
-- Run from the project root so the relative 'data/...' paths resolve.
-- =====================================================================
SET client_encoding = 'UTF8';

TRUNCATE staging.collision_raw, staging.vehicle_raw, staging.casualty_raw;
TRUNCATE public.lookups CASCADE;

\copy staging.collision_raw FROM 'data/collision.csv' WITH (FORMAT csv, HEADER)
\copy staging.vehicle_raw   FROM 'data/vehicle.csv'   WITH (FORMAT csv, HEADER)
\copy staging.casualty_raw  FROM 'data/casualty.csv'  WITH (FORMAT csv, HEADER)
\copy public.lookups        FROM 'data/lookups.csv'   WITH (FORMAT csv, HEADER)

SELECT 'collisions' AS file, COUNT(*) AS rows_loaded FROM staging.collision_raw
UNION ALL SELECT 'vehicles',   COUNT(*) FROM staging.vehicle_raw
UNION ALL SELECT 'casualties', COUNT(*) FROM staging.casualty_raw
UNION ALL SELECT 'lookups',    COUNT(*) FROM public.lookups;
