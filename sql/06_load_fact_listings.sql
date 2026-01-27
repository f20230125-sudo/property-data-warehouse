-- 06_load_fact_listings.sql
-- Build the fact table by swapping business keys for surrogate keys.
--
-- Two things worth noticing:
--   1. Agent lookup is a POINT-IN-TIME join: we take the agent version whose validity
--      interval contains the listing's listed date. That is what makes SCD2 pay off:
--      a listing stays attributed to the agency the agent worked for at the time.
--   2. Every lookup is a LEFT JOIN with COALESCE(..., -1), so an unmatched business
--      key lands on the Unknown member rather than dropping the row.

INSERT INTO fact_listings (
    listing_id, property_type_key, location_key, agent_key,
    listed_date_key, last_updated_date_key, removed_date_key,
    purpose, listing_status,
    initial_price_aed, current_price_aed, size_sqft,
    price_change_count, view_count, lead_count, days_on_market
)
SELECT
    s.listing_id,
    COALESCE(pt.property_type_key, -1)  AS property_type_key,
    COALESCE(l.location_key, -1)        AS location_key,
    COALESCE(a.agent_key, -1)           AS agent_key,
    year(s.listed_date) * 10000 + month(s.listed_date) * 100 + day(s.listed_date)                       AS listed_date_key,
    year(s.last_updated_date) * 10000 + month(s.last_updated_date) * 100 + day(s.last_updated_date)     AS last_updated_date_key,
    COALESCE(year(s.removed_date) * 10000 + month(s.removed_date) * 100 + day(s.removed_date), 99991231) AS removed_date_key,
    s.purpose,
    s.listing_status,
    s.initial_price_aed,
    s.current_price_aed,
    s.size_sqft,
    s.price_change_count,
    s.view_count,
    s.lead_count,
    s.removed_date - s.listed_date      AS days_on_market   -- NULL while active
FROM stg.listings_clean s
LEFT JOIN dim_property_type pt
       ON pt.property_type = s.property_type AND pt.bedrooms = s.bedrooms
LEFT JOIN dim_location l
       ON l.location_id = s.location_id
LEFT JOIN dim_agent a
       ON a.agent_id = s.agent_id
      AND s.listed_date BETWEEN a.effective_from AND a.effective_to
ORDER BY s.listing_id;
