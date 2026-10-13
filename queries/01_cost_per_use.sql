-- Indicator 1: Cost-per-use, naive vs subscription-only (TA refinement)
SELECT
    d.database_name,
    c.report_year,
    c.cost_eur,
    SUM(u.total_item_requests) AS total_requests,
    SUM(CASE WHEN u.access_type = 'Controlled'
             THEN u.total_item_requests ELSE 0 END) AS controlled_requests,
    ROUND(c.cost_eur * 1.0 / SUM(u.total_item_requests), 2) AS cpu_naive,
    ROUND(c.cost_eur * 1.0 /
          NULLIF(SUM(CASE WHEN u.access_type = 'Controlled'
                          THEN u.total_item_requests ELSE 0 END), 0), 2) AS cpu_controlled
FROM annual_cost AS c
JOIN database_subscription AS d
    ON d.database_id = c.database_id
JOIN counter_usage AS u
    ON u.database_id = c.database_id
   AND u.report_year = c.report_year
WHERE c.report_year = 2024
GROUP BY d.database_name, c.report_year, c.cost_eur
ORDER BY cpu_controlled DESC;