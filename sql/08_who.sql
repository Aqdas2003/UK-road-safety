-- =====================================================================
-- 08_who.sql
-- Business question: "Who is most at risk?"
-- =====================================================================

-- Q16. Vulnerable road users: share of all casualties vs share of deaths.
--      A group whose share of deaths far exceeds its share of casualties
--      is more likely to die when hurt.
SELECT
    road_user_group,
    COUNT(*)                                                         AS casualties,
    COUNT(*) FILTER (WHERE severity = 1)                             AS killed,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)               AS pct_of_casualties,
    ROUND(100.0 * COUNT(*) FILTER (WHERE severity = 1)
          / SUM(COUNT(*) FILTER (WHERE severity = 1)) OVER (), 1)    AS pct_of_deaths,
    ROUND(1000.0 * COUNT(*) FILTER (WHERE severity = 1) / COUNT(*), 1) AS deaths_per_1000_casualties
FROM casualties
GROUP BY road_user_group
ORDER BY deaths_per_1000_casualties DESC;

-- Q17. Age: casualties and death rate by age band
SELECT
    age_band,
    COUNT(*)                                                         AS casualties,
    ROUND(1000.0 * COUNT(*) FILTER (WHERE severity = 1) / COUNT(*), 1) AS deaths_per_1000_casualties
FROM casualties
WHERE age_band NOT ILIKE '%missing%'
GROUP BY age_band
ORDER BY MIN(age);

-- Q18. Child pedestrians (under 16): what time of day are they hurt?
--      A school-run peak would support targeted interventions.
SELECT
    k.collision_hour                                                 AS hour,
    COUNT(*)                                                         AS child_pedestrian_casualties
FROM casualties c
JOIN collisions k USING (collision_id)
WHERE c.road_user_group = 'Pedestrian' AND c.age < 16
  AND EXTRACT(ISODOW FROM k.collision_date) <= 5        -- weekdays only
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5;
