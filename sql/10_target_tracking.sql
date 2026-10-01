-- =====================================================================
-- 10_target_tracking.sql
-- Business question: "Is Britain on track for the Road Safety Strategy
-- targets?" (Published January 2026.)
--   * All KSI:   -65% by 2035 vs the 2022-2024 average
--   * Child KSI: -70% by 2030 vs the 2022-2024 average (child = under 16)
-- =====================================================================

WITH yearly AS (
    SELECT
        EXTRACT(YEAR FROM k.collision_date)::INT                     AS yr,
        SUM(CASE WHEN c.severity = 1 THEN 1 ELSE c.adj_serious END)  AS ksi,
        SUM(CASE WHEN c.severity = 1 THEN 1 ELSE c.adj_serious END)
            FILTER (WHERE c.age < 16)                                AS child_ksi
    FROM casualties c
    JOIN collisions k USING (collision_id)
    GROUP BY 1
),
baseline AS (
    SELECT AVG(ksi) AS ksi_base, AVG(child_ksi) AS child_base
    FROM yearly
    WHERE yr BETWEEN 2022 AND 2024
)
SELECT
    y.yr,
    ROUND(y.ksi)::INT                                                AS ksi,
    ROUND(100.0 * (y.ksi - b.ksi_base) / b.ksi_base, 1)              AS ksi_vs_baseline_pct,
    ROUND(b.ksi_base * 0.35)::INT                                    AS ksi_2035_target,
    ROUND(y.child_ksi)::INT                                          AS child_ksi,
    ROUND(100.0 * (y.child_ksi - b.child_base) / b.child_base, 1)    AS child_vs_baseline_pct,
    ROUND(b.child_base * 0.30)::INT                                  AS child_2030_target
FROM yearly y CROSS JOIN baseline b      -- one baseline row attached to every year
ORDER BY y.yr;

-- Export for the README chart
\copy (WITH y AS (SELECT EXTRACT(YEAR FROM k.collision_date)::INT AS yr, SUM(CASE WHEN c.severity = 1 THEN 1 ELSE c.adj_serious END) AS ksi, SUM(CASE WHEN c.severity = 1 THEN 1 ELSE c.adj_serious END) FILTER (WHERE c.age < 16) AS child_ksi FROM casualties c JOIN collisions k USING (collision_id) GROUP BY 1), b AS (SELECT AVG(ksi) kb, AVG(child_ksi) cb FROM y WHERE yr BETWEEN 2022 AND 2024) SELECT yr, ROUND(ksi)::INT AS ksi, ROUND(kb)::INT AS ksi_baseline, ROUND(kb * 0.35)::INT AS ksi_2035_target, ROUND(child_ksi)::INT AS child_ksi, ROUND(cb)::INT AS child_baseline, ROUND(cb * 0.30)::INT AS child_2030_target FROM y CROSS JOIN b ORDER BY yr) TO 'results/target_tracking.csv' WITH (FORMAT csv, HEADER)
