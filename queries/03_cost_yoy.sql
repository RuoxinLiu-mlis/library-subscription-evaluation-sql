-- Year-over-year subscription cost change (real UAlberta-based cost data)
WITH cost_trend AS (
    SELECT
        d.database_name,
        c.report_year,
        c.cost_eur,
        LAG(c.cost_eur) OVER (PARTITION BY c.database_id ORDER BY c.report_year) AS prev_cost_eur
    FROM annual_cost AS c
    JOIN database_subscription AS d ON d.database_id = c.database_id
    WHERE c.cost_eur > 0
)
SELECT
    database_name,
    report_year,
    cost_eur,
    prev_cost_eur,
    ROUND(100.0 * (cost_eur - prev_cost_eur) / prev_cost_eur, 1) AS yoy_change_pct
FROM cost_trend
WHERE prev_cost_eur IS NOT NULL
ORDER BY ABS(cost_eur - prev_cost_eur) * 1.0 / prev_cost_eur DESC;