-- Q08 | Active inventory at each month-end (point-in-time snapshot)
-- Question: How many listings were live at the end of each month?
-- Technique: the accumulating snapshot stores lifecycle dates, so any past date can be reconstructed:
--            a listing is live on D if listed_date_key <= D AND removed_date_key > D. Because active
--            listings carry the 99991231 "not yet occurred" member, they satisfy the second test with
--            no special-casing or NULL handling. dim_date acts as the calendar spine of the join.
SELECT
    d.year_month,
    COUNT(*)                                    AS active_listings,
    COUNT(*) FILTER (WHERE f.purpose = 'SALE')  AS active_sale,
    COUNT(*) FILTER (WHERE f.purpose = 'RENT')  AS active_rent
FROM dim_date d
JOIN fact_listings f
  ON f.listed_date_key  <= d.date_key
 AND f.removed_date_key >  d.date_key
WHERE d.is_month_end
  AND d.date_key <= (SELECT MAX(listed_date_key) FROM fact_listings)  -- stop at the data horizon
GROUP BY d.year_month
ORDER BY d.year_month;
