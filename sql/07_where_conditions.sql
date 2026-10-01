-- =====================================================================
-- 07_where_conditions.sql
-- Business question: "Which roads and conditions make collisions deadlier?"
-- Severity rate = fatal collisions per 1,000 collisions. This controls for
-- volume: busy 30mph roads have the most collisions, but are they deadly?
-- =====================================================================

-- Q11. Speed limit vs severity
SELECT
    speed_limit || ' mph'                                            AS speed_limit,
    COUNT(*)                                                         AS collisions,
    COUNT(*) FILTER (WHERE severity = 1)                             AS fatal,
    ROUND(1000.0 * COUNT(*) FILTER (WHERE severity = 1) / COUNT(*), 1) AS fatal_per_1000
FROM collisions
WHERE speed_limit IS NOT NULL
GROUP BY speed_limit
ORDER BY speed_limit;

-- Q12. Urban vs rural
SELECT
    urban_rural,
    COUNT(*)                                                         AS collisions,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)               AS pct_of_collisions,
    ROUND(100.0 * COUNT(*) FILTER (WHERE severity = 1)
          / SUM(COUNT(*) FILTER (WHERE severity = 1)) OVER (), 1)    AS pct_of_fatal,
    ROUND(1000.0 * COUNT(*) FILTER (WHERE severity = 1) / COUNT(*), 1) AS fatal_per_1000
FROM collisions
WHERE urban_rural IN ('Urban', 'Rural')
GROUP BY urban_rural;

-- Q13. Light conditions: darkness without street lighting
SELECT
    light_conditions,
    COUNT(*)                                                         AS collisions,
    ROUND(1000.0 * COUNT(*) FILTER (WHERE severity = 1) / COUNT(*), 1) AS fatal_per_1000
FROM collisions
WHERE light_conditions NOT ILIKE '%missing%' AND light_conditions NOT ILIKE '%unknown%'
GROUP BY light_conditions
ORDER BY fatal_per_1000 DESC;

-- Q14. Highway authorities with the highest share of collisions that
--      are fatal or serious (min 1,000 collisions for a reliable rate)
SELECT
    h.la_name,
    COUNT(*)                                                         AS collisions,
    ROUND(COUNT(*) FILTER (WHERE k.severity = 1) + SUM(k.adj_serious))::INT AS ksi_adjusted,
    ROUND(100.0 * (COUNT(*) FILTER (WHERE k.severity = 1) + SUM(k.adj_serious))
          / COUNT(*), 1)                                             AS ksi_pct,
    RANK() OVER (ORDER BY (COUNT(*) FILTER (WHERE k.severity = 1) + SUM(k.adj_serious))
                          / COUNT(*) DESC)                           AS rank_ksi_pct
FROM collisions k
JOIN highway_authorities h USING (la_code)
GROUP BY h.la_name
HAVING COUNT(*) >= 1000
ORDER BY rank_ksi_pct
LIMIT 15;

-- Q15. Newcastle upon Tyne vs Great Britain: same metrics side by side.
--      GROUPING SETS computes both levels in one pass.
SELECT
    COALESCE(h.la_name, 'Great Britain')                             AS area,
    COUNT(*)                                                         AS collisions,
    ROUND(100.0 * (COUNT(*) FILTER (WHERE k.severity = 1) + SUM(k.adj_serious))
          / COUNT(*), 1)                                             AS ksi_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE k.speed_limit <= 30) / COUNT(*), 1) AS pct_on_30mph_or_less,
    ROUND(100.0 * COUNT(*) FILTER (WHERE k.light_conditions ILIKE 'Darkness%') / COUNT(*), 1) AS pct_in_darkness
FROM collisions k
JOIN highway_authorities h USING (la_code)
GROUP BY GROUPING SETS ((h.la_name), ())       -- () = the grand total row
-- Keep Newcastle's row plus the grand total. GROUPING() = 1 flags the
-- total row, where la_name is NULL.
HAVING h.la_name = 'Newcastle upon Tyne' OR GROUPING(h.la_name) = 1
ORDER BY GROUPING(h.la_name) DESC;
