-- Q06 | Agency listing counts: SCD Type 2 vs "current agency only"
-- Question: What would agency league tables look like if agent history were overwritten (Type 1)?
-- Technique: dim_agent is Type 2 and the fact stores the agent version valid on the listed date, so
--            grouping on dim_agent.agency_name credits each listing to the agency that actually
--            held it. Re-attributing every listing to the agent's CURRENT agency (what a Type 1
--            dimension would give) misstates agencies that gained or lost agents.
WITH as_was AS (
    SELECT a.agency_name, COUNT(*) AS listings
    FROM fact_listings f
    JOIN dim_agent a ON a.agent_key = f.agent_key
    WHERE a.agent_id <> 'UNKNOWN'
    GROUP BY a.agency_name
),
current_agency AS (
    SELECT agent_id, agency_name FROM dim_agent WHERE is_current
),
as_is AS (
    SELECT c.agency_name, COUNT(*) AS listings
    FROM fact_listings f
    JOIN dim_agent      a ON a.agent_key = f.agent_key
    JOIN current_agency c ON c.agent_id  = a.agent_id
    WHERE a.agent_id <> 'UNKNOWN'
    GROUP BY c.agency_name
),
compared AS (
    SELECT
        COALESCE(w.agency_name, i.agency_name)             AS agency,
        COALESCE(w.listings, 0)                            AS listings_correct_scd2,
        COALESCE(i.listings, 0)                            AS listings_if_type1,
        COALESCE(i.listings, 0) - COALESCE(w.listings, 0)  AS type1_error
    FROM as_was w
    FULL JOIN as_is i ON i.agency_name = w.agency_name
)
SELECT *
FROM compared
ORDER BY ABS(type1_error) DESC, agency
LIMIT 10;
