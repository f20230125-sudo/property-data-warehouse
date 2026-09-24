-- Q04 | Time to removal by purpose and property type (2025 listing cohort)
-- Question: How long do listings stay up before an agent takes them down?
-- Technique: median and p90 instead of a mean (durations are right-skewed). Only REMOVED listings count:
--            EXPIRED lapsed on their own and ACTIVE have no end yet. Restricting to listings posted in
--            2025 gives every listing 8+ months to close, which limits the right-censoring bias that
--            would otherwise pull recent cohorts' medians down.
SELECT
    f.purpose,
    pt.property_type,
    COUNT(*)                                     AS removed_listings,
    MEDIAN(f.days_on_market)                     AS median_days,
    ROUND(AVG(f.days_on_market), 1)              AS mean_days,
    ROUND(quantile_cont(f.days_on_market, 0.9))  AS p90_days
FROM fact_listings f
JOIN dim_property_type pt ON pt.property_type_key = f.property_type_key
WHERE f.listing_status = 'REMOVED'
  AND f.listed_date_key BETWEEN 20250101 AND 20251231
GROUP BY f.purpose, pt.property_type
ORDER BY f.purpose, median_days;
