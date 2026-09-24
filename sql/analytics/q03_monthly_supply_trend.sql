-- Q03 | New-listing supply per month in Dubai, with month-over-month change
-- Question: How is new supply trending for sale vs rent?
-- Technique: dim_date supplies the sortable year_month grouping key; LAG() over a named window
--            computes MoM change without a self-join.
WITH monthly AS (
    SELECT
        d.year_month,
        COUNT(*) FILTER (WHERE f.purpose = 'SALE') AS sale_listings,
        COUNT(*) FILTER (WHERE f.purpose = 'RENT') AS rent_listings
    FROM fact_listings f
    JOIN dim_date     d ON d.date_key     = f.listed_date_key
    JOIN dim_location l ON l.location_key = f.location_key
    WHERE l.emirate = 'Dubai'
    GROUP BY d.year_month
)
SELECT
    year_month,
    sale_listings,
    ROUND(100.0 * (sale_listings - LAG(sale_listings) OVER w) / NULLIF(LAG(sale_listings) OVER w, 0), 1) AS sale_mom_pct,
    rent_listings,
    ROUND(100.0 * (rent_listings - LAG(rent_listings) OVER w) / NULLIF(LAG(rent_listings) OVER w, 0), 1) AS rent_mom_pct
FROM monthly
WINDOW w AS (ORDER BY year_month)
ORDER BY year_month;
