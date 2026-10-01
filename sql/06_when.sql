-- =====================================================================
-- 06_when.sql
-- Business question: "When do collisions happen, and when are they worst?"
-- =====================================================================

-- Q8. Collisions by hour of day, with the share that are fatal or serious.
--     Volume peaks at rush hour, but severity peaks at night.
SELECT
    collision_hour                                                   AS hour,
    COUNT(*)                                                         AS collisions,
    ROUND(100.0 * (COUNT(*) FILTER (WHERE severity = 1) + SUM(adj_serious))
          / COUNT(*), 1)                                             AS ksi_pct
FROM collisions
GROUP BY 1
ORDER BY 1;

-- Q9. Day x time-band grid (the heatmap in Power BI). Day names come
--     from the lookup; ordering uses the numeric code so Monday..Sunday
--     sort correctly rather than alphabetically.
SELECT
    lookup_label('day_of_week', day_of_week::TEXT)                   AS day,
    COUNT(*) FILTER (WHERE collision_hour BETWEEN 0  AND 5)          AS "00-05",
    COUNT(*) FILTER (WHERE collision_hour BETWEEN 6  AND 9)          AS "06-09",
    COUNT(*) FILTER (WHERE collision_hour BETWEEN 10 AND 14)         AS "10-14",
    COUNT(*) FILTER (WHERE collision_hour BETWEEN 15 AND 18)         AS "15-18",
    COUNT(*) FILTER (WHERE collision_hour BETWEEN 19 AND 23)         AS "19-23"
FROM collisions
GROUP BY day_of_week
ORDER BY (day_of_week + 5) % 7;          -- shifts Sunday (1) to the end

-- Q10. Seasonality: collisions by month, averaged across the 5 years
SELECT
    TO_CHAR(collision_date, 'Mon')                                   AS month,
    ROUND(COUNT(*) / 5.0)::INT                                       AS avg_collisions_per_year
FROM collisions
GROUP BY EXTRACT(MONTH FROM collision_date), 1
ORDER BY EXTRACT(MONTH FROM collision_date);
