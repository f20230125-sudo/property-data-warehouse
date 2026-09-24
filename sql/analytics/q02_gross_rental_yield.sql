-- Q02 | Gross rental yield by community and bedroom count
-- Question: Where does a 1- or 2-bedroom apartment earn the best gross yield?
-- Technique: conditional aggregation (FILTER) pivots SALE and RENT listings of the same segment onto
--            one row, so the yield is like-for-like: median annual rent / median sale price.
--            Segments need enough listings on both sides to be meaningful.
WITH segment AS (
    SELECT
        l.community,
        pt.bedroom_label,
        COUNT(*)                    FILTER (WHERE f.purpose = 'SALE') AS sale_listings,
        COUNT(*)                    FILTER (WHERE f.purpose = 'RENT') AS rent_listings,
        MEDIAN(f.current_price_aed) FILTER (WHERE f.purpose = 'SALE') AS median_sale_price_aed,
        MEDIAN(f.current_price_aed) FILTER (WHERE f.purpose = 'RENT') AS median_annual_rent_aed
    FROM fact_listings f
    JOIN dim_location      l  ON l.location_key       = f.location_key
    JOIN dim_property_type pt ON pt.property_type_key = f.property_type_key
    WHERE pt.property_type = 'Apartment'
      AND pt.bedrooms IN (1, 2)
      AND f.location_key <> -1
    GROUP BY l.community, pt.bedroom_label
)
SELECT
    community,
    bedroom_label,
    sale_listings,
    rent_listings,
    ROUND(median_sale_price_aed)                                     AS median_sale_price_aed,
    ROUND(median_annual_rent_aed)                                    AS median_annual_rent_aed,
    ROUND(100.0 * median_annual_rent_aed / median_sale_price_aed, 2) AS gross_yield_pct
FROM segment
WHERE sale_listings >= 15 AND rent_listings >= 15
ORDER BY gross_yield_pct DESC
LIMIT 12;
