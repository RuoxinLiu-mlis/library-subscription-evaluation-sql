-- ===== Indicator 1 as a reusable view: cost-per-use =====
CREATE VIEW IF NOT EXISTS v_cpu AS
SELECT
    c.database_id,
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
JOIN counter_usage AS u
    ON u.database_id = c.database_id
   AND u.report_year = c.report_year
GROUP BY c.database_id, c.report_year, c.cost_eur;

-- ===== Indicator 2: open access availability rate =====
CREATE VIEW IF NOT EXISTS v_oa_rate AS
SELECT
    database_id,
    report_year,
    ROUND(100.0 * SUM(CASE WHEN access_type = 'OA_Gold'
                           THEN total_item_requests ELSE 0 END)
          / SUM(total_item_requests), 1) AS oa_rate_pct
FROM counter_usage
GROUP BY database_id, report_year;

-- ===== Indicator 3: discipline concentration (window functions) =====
CREATE VIEW IF NOT EXISTS v_concentration AS
WITH shares AS (
    SELECT
        fu.database_id,
        fu.report_year,
        f.faculty_name,
        ROUND(100.0 * fu.attributed_requests
              / SUM(fu.attributed_requests) OVER (PARTITION BY fu.database_id, fu.report_year), 1) AS share_pct,
        RANK() OVER (PARTITION BY fu.database_id, fu.report_year
                     ORDER BY fu.attributed_requests DESC) AS faculty_rank
    FROM faculty_usage AS fu
    JOIN faculty AS f ON f.faculty_id = fu.faculty_id
)
SELECT database_id, report_year, faculty_name AS top_faculty, share_pct AS top_share_pct
FROM shares
WHERE faculty_rank = 1;

-- ===== Decision pathway layer + discipline safeguard (2024) =====
-- Illustrative thresholds: CPU review trigger EUR 5; safeguard at 60% single-faculty share.
-- The thesis leaves final thresholds to the Phase 2 pilot.
SELECT
    d.database_name,
    p.cost_eur,
    p.cpu_naive,
    p.cpu_controlled,
    o.oa_rate_pct,
    k.top_faculty,
    k.top_share_pct,
    CASE
        WHEN p.cost_eur = 0 THEN 'Continue (no-cost OA)'
        WHEN p.cpu_controlled <= 5 THEN 'Continue'
        WHEN t.database_id IS NOT NULL OR o.oa_rate_pct >= 20 THEN 'Transformative agreement review'
        WHEN k.top_share_pct >= 60 THEN 'Discipline safeguard: consult faculty'
        ELSE 'Cancellation review'
    END AS pathway
FROM v_cpu AS p
JOIN database_subscription AS d ON d.database_id = p.database_id
JOIN v_oa_rate AS o ON o.database_id = p.database_id AND o.report_year = p.report_year
JOIN v_concentration AS k ON k.database_id = p.database_id AND k.report_year = p.report_year
LEFT JOIN ta_transition AS t ON t.database_id = p.database_id AND t.ta_start_year <= p.report_year
WHERE p.report_year = 2024
ORDER BY p.cpu_controlled DESC;