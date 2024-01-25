-- Q01 | Sale price per sqft by community
-- Question: Which communities are most expensive per sqft, split by apartment vs landed home?
-- Technique: price per sqft is a RATIO, so it is not averaged row by row. SUM(price) / SUM(size)
--            gives the size-weighted figure; AVG(price / size) over-weights small units and is
--            shown alongside to make the gap visible. Restricted to SALE (rent is annual, not comparable).
SELECT
    l.emirate,
    l.community,
    pt.property_group,
    COUNT(*)                                            AS listings,
    ROUND(SUM(f.current_price_aed) / SUM(f.size_sqft))  AS price_per_sqft_aed,
    ROUND(AVG(f.current_price_aed / f.size_sqft))       AS avg_of_ratios_aed
FROM fact_listings f
JOIN dim_location      l  ON l.location_key       = f.location_key
JOIN dim_property_type pt ON pt.property_type_key = f.property_type_key
WHERE f.purpose = 'SALE'
  AND f.location_key <> -1
GROUP BY l.emirate, l.community, pt.property_group
HAVING COUNT(*) >= 40
ORDER BY price_per_sqft_aed DESC
LIMIT 12;
