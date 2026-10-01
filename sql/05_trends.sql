-- =====================================================================
-- 05_trends.sql
-- Business question: "Are Britain's roads getting safer?"
-- KSI = Killed or Seriously Injured, the headline road safety metric.
-- Adjusted KSI = fatalities + sum of adjusted "serious" probabilities.
-- =====================================================================

-- Q6. Casualties per year: total, killed, KSI (adjusted), and YoY change
WITH yearly AS (
    SELECT
        EXTRACT(YEAR FROM k.collision_date)::INT          AS yr,
        COUNT(*)                                          AS casualties,
        COUNT(*) FILTER (WHERE c.severity = 1)            AS killed,
        COUNT(*) FILTER (WHERE c.severity = 1)
          + SUM(c.adj_serious)                            AS ksi_adjusted
    FROM casualties c
    JOIN collisions k USING (collision_id)
    GROUP BY 1
)
SELECT
    yr,
    casualties,
    killed,
    ROUND(ksi_adjusted)::INT                              AS ksi_adjusted,
    ROUND(100.0 * (killed - LAG(killed) OVER w) / LAG(killed) OVER w, 1) AS killed_yoy_pct,
    ROUND(100.0 * ksi_adjusted / casualties, 1)           AS ksi_pct_of_casualties
FROM yearly
WINDOW w AS (ORDER BY yr)            -- define the window once, reuse it
ORDER BY yr;

-- Q7. Change 2021 -> 2025 by road user group. Who is getting safer, who isn't?
WITH g AS (
    SELECT
        c.road_user_group,
        COUNT(*) FILTER (WHERE EXTRACT(YEAR FROM k.collision_date) = 2021 AND c.severity = 1)
          + SUM(c.adj_serious) FILTER (WHERE EXTRACT(YEAR FROM k.collision_date) = 2021) AS ksi_2021,
        COUNT(*) FILTER (WHERE EXTRACT(YEAR FROM k.collision_date) = 2025 AND c.severity = 1)
          + SUM(c.adj_serious) FILTER (WHERE EXTRACT(YEAR FROM k.collision_date) = 2025) AS ksi_2025
    FROM casualties c JOIN collisions k USING (collision_id)
    GROUP BY 1
)
SELECT
    road_user_group,
    ROUND(ksi_2021)::INT AS ksi_2021,
    ROUND(ksi_2025)::INT AS ksi_2025,
    ROUND(100.0 * (ksi_2025 - ksi_2021) / ksi_2021, 1) AS change_pct
FROM g
ORDER BY change_pct DESC;
