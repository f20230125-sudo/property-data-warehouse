-- 04_load_dim_location_property_type.sql
-- Type 1 dimensions. Each carries a -1 "Unknown" member so fact rows whose business
-- key cannot be resolved still load (and are countable) instead of being dropped or
-- given a NULL foreign key.

-- ----- dim_location -----
INSERT INTO dim_location VALUES (-1, 'UNKNOWN', 'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown');

INSERT INTO dim_location (location_id, emirate, city, community, sub_community, market_tier)
SELECT
    location_id,
    emirate,
    city,
    community,
    COALESCE(NULLIF(trim(sub_community), ''), 'N/A'),
    market_tier
FROM stg.locations
ORDER BY location_id;

-- ----- dim_property_type -----
-- Derived from what actually appears in the listings, so the dimension has no
-- combinations nobody has listed.
INSERT INTO dim_property_type VALUES (-1, 'Unknown', 'Unknown', -1, 'Unknown', 'Unknown');

INSERT INTO dim_property_type (property_type, property_group, bedrooms, bedroom_label, property_type_label)
SELECT
    property_type,
    CASE
        WHEN property_type IN ('Apartment', 'Penthouse') THEN 'Apartment building'
        WHEN property_type IN ('Villa', 'Townhouse')     THEN 'Landed home'
        ELSE 'Other'
    END AS property_group,
    bedrooms,
    bedroom_label,
    bedroom_label || ' ' || property_type AS property_type_label
FROM (
    SELECT
        property_type,
        bedrooms,
        CASE
            WHEN bedrooms = 0 THEN 'Studio'
            WHEN bedrooms >= 5 THEN '5+ BR'
            ELSE bedrooms || ' BR'
        END AS bedroom_label
    FROM (SELECT DISTINCT property_type, bedrooms FROM stg.listings_clean)
)
ORDER BY property_type, bedrooms;
