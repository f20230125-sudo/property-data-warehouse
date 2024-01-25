-- Q05 | Price-cut behaviour by market tier
-- Question: How often do sellers and landlords cut their asking price, and by how much?
-- Technique: average cut depth is a ratio, so it is computed as 1 - SUM(current) / SUM(initial)
--            over only the listings that were cut (FILTER), not as an average of per-row percentages.
SELECT
    f.purpose,
    l.market_tier,
    COUNT(*)                                                                       AS listings,
    ROUND(100.0 * COUNT(*) FILTER (WHERE f.price_change_count > 0) / COUNT(*), 1)  AS pct_with_price_cut,
    ROUND(100.0 * (1 - SUM(f.current_price_aed) FILTER (WHERE f.price_change_count > 0)
                     / SUM(f.initial_price_aed) FILTER (WHERE f.price_change_count > 0)), 1) AS avg_cut_depth_pct
FROM fact_listings f
JOIN dim_location l ON l.location_key = f.location_key
WHERE f.location_key <> -1
GROUP BY f.purpose, l.market_tier
ORDER BY f.purpose,
         CASE l.market_tier WHEN 'Prime' THEN 1 WHEN 'Mid-market' THEN 2 ELSE 3 END;
