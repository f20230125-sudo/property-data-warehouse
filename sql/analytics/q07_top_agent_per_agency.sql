-- Q07 | Best lead-converting agent in each agency
-- Question: Who converts views into leads best within each agency?
-- Technique: an agent spans several dim_agent rows, so analysis over time groups by the BUSINESS key
--            (agent_id), never the surrogate agent_key. Conversion is SUM(leads) / SUM(views), not an
--            average of per-listing rates. RANK() OVER (PARTITION BY ...) picks the winner per agency;
--            agents with fewer than 25 listings are excluded as too thin to rank.
WITH agent_stats AS (
    SELECT
        a.agent_id,
        MAX(a.agent_name)                                        AS agent_name,
        COUNT(*)                                                 AS listings,
        SUM(f.lead_count)                                        AS leads,
        ROUND(100.0 * SUM(f.lead_count) / SUM(f.view_count), 2)  AS leads_per_100_views
    FROM fact_listings f
    JOIN dim_agent a ON a.agent_key = f.agent_key
    WHERE a.agent_id <> 'UNKNOWN'
    GROUP BY a.agent_id
),
current_agency AS (
    SELECT agent_id, agency_name FROM dim_agent WHERE is_current
),
ranked AS (
    SELECT
        c.agency_name,
        s.*,
        RANK() OVER (PARTITION BY c.agency_name ORDER BY s.leads_per_100_views DESC) AS agency_rank
    FROM agent_stats s
    JOIN current_agency c ON c.agent_id = s.agent_id
    WHERE s.listings >= 25
)
SELECT agency_name, agent_name, listings, leads, leads_per_100_views
FROM ranked
WHERE agency_rank = 1
ORDER BY leads_per_100_views DESC, agency_name
LIMIT 10;
