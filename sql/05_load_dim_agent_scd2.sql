-- 05_load_dim_agent_scd2.sql
-- Slowly Changing Dimension Type 2.
-- The source is a change log: one row each time an agent's agency or verification
-- status changed, stamped with the date it took effect. We turn that into validity
-- intervals with LEAD(): each version ends the day before the next one begins, and
-- the last version is open-ended (9999-12-31, is_current = TRUE).

INSERT INTO dim_agent VALUES (-1, 'UNKNOWN', 'Unknown', 'Unknown', FALSE, DATE '1900-01-01', DATE '9999-12-31', TRUE);

INSERT INTO dim_agent (agent_id, agent_name, agency_name, is_verified, effective_from, effective_to, is_current)
SELECT
    agent_id,
    agent_name,
    agency_name,
    is_verified,
    effective_from,
    COALESCE(next_from - 1, DATE '9999-12-31') AS effective_to,
    next_from IS NULL                          AS is_current
FROM (
    SELECT
        *,
        LEAD(effective_from) OVER (PARTITION BY agent_id ORDER BY effective_from) AS next_from
    FROM stg.agent_history
)
ORDER BY agent_id, effective_from;
