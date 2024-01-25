-- 07_quality_checks.sql
-- Post-load assertions. Every row returned is (check_name, violations); the build
-- fails if any check reports violations > 0. These cover what table constraints
-- cannot express: reconciliation with staging, SCD2 interval integrity, and
-- cross-table date logic.

SELECT check_name, violations
FROM (
    SELECT 'fact rows = clean staging rows' AS check_name,
           ABS((SELECT COUNT(*) FROM fact_listings) - (SELECT COUNT(*) FROM stg.listings_clean)) AS violations

    UNION ALL
    SELECT 'listings in = fact rows + rejected rows',
           ABS((SELECT COUNT(*) FROM stg.listings_raw)
               - (SELECT COUNT(*) FROM fact_listings)
               - (SELECT COUNT(*) FROM stg.listings_rejected))

    UNION ALL
    SELECT 'total price by purpose reconciles to staging', COUNT(*)
    FROM (SELECT purpose, SUM(current_price_aed) AS total FROM stg.listings_clean GROUP BY purpose) s
    FULL JOIN (SELECT purpose, SUM(current_price_aed) AS total FROM fact_listings GROUP BY purpose) f
           ON f.purpose = s.purpose
    WHERE s.total IS DISTINCT FROM f.total

    UNION ALL
    SELECT 'agents without exactly one current version', COUNT(*)
    FROM (
        SELECT agent_id FROM dim_agent
        GROUP BY agent_id
        HAVING COUNT(*) FILTER (WHERE is_current) <> 1
    )

    UNION ALL
    SELECT 'agent versions with a gap or overlap', COUNT(*)
    FROM (
        SELECT effective_from,
               LAG(effective_to) OVER (PARTITION BY agent_id ORDER BY effective_from) AS prev_to
        FROM dim_agent
    )
    WHERE prev_to IS NOT NULL AND effective_from <> prev_to + 1

    UNION ALL
    SELECT 'facts pointing at an agent version not valid on the listed date', COUNT(*)
    FROM fact_listings f
    JOIN dim_agent a ON a.agent_key = f.agent_key
    JOIN dim_date  d ON d.date_key  = f.listed_date_key
    WHERE f.agent_key <> -1
      AND d.full_date NOT BETWEEN a.effective_from AND a.effective_to

    UNION ALL
    SELECT 'lifecycle dates out of order', COUNT(*)
    FROM fact_listings
    WHERE last_updated_date_key < listed_date_key
       OR removed_date_key < listed_date_key
       OR (removed_date_key <> 99991231 AND last_updated_date_key > removed_date_key)

    UNION ALL
    SELECT 'days_on_market disagrees with the date keys', COUNT(*)
    FROM fact_listings f
    JOIN dim_date l ON l.date_key = f.listed_date_key
    JOIN dim_date r ON r.date_key = f.removed_date_key
    WHERE f.days_on_market IS NOT NULL
      AND f.days_on_market <> r.full_date - l.full_date

    UNION ALL
    SELECT 'dim_date has missing days', COUNT(*)
    FROM (
        SELECT full_date, LAG(full_date) OVER (ORDER BY full_date) AS prev_date
        FROM dim_date
        WHERE NOT is_placeholder
    )
    WHERE prev_date IS NOT NULL AND full_date <> prev_date + 1

    UNION ALL
    -- A few unmatched keys are expected (that is what the Unknown member is for);
    -- a flood means the source or the mapping is broken.
    SELECT 'more than 1% of listings on the Unknown location',
           CASE WHEN COUNT(*) FILTER (WHERE location_key = -1) > 0.01 * COUNT(*) THEN 1 ELSE 0 END
    FROM fact_listings

    UNION ALL
    SELECT 'more than 1% of listings on the Unknown agent',
           CASE WHEN COUNT(*) FILTER (WHERE agent_key = -1) > 0.01 * COUNT(*) THEN 1 ELSE 0 END
    FROM fact_listings
)
ORDER BY check_name;
