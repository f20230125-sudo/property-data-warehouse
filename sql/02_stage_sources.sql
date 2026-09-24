-- 02_stage_sources.sql
-- Land the raw extracts in the stg schema, then split listings into clean vs rejected.
-- Paths are relative to the project root, so run scripts from there.
-- Columns are typed explicitly instead of auto-detected, so a malformed file fails
-- loudly here rather than silently mis-typing a column.

CREATE TABLE stg.locations AS
SELECT *
FROM read_csv('data/raw/locations.csv', header = true, columns = {
    'location_id':   'VARCHAR',
    'emirate':       'VARCHAR',
    'city':          'VARCHAR',
    'community':     'VARCHAR',
    'sub_community': 'VARCHAR',
    'market_tier':   'VARCHAR'
});

CREATE TABLE stg.agent_history AS
SELECT *
FROM read_csv('data/raw/agent_history.csv', header = true, columns = {
    'agent_id':       'VARCHAR',
    'agent_name':     'VARCHAR',
    'agency_name':    'VARCHAR',
    'is_verified':    'BOOLEAN',
    'effective_from': 'DATE'
});

CREATE TABLE stg.listings_raw AS
SELECT *
FROM read_csv('data/raw/listings.csv', header = true, columns = {
    'listing_id':         'VARCHAR',
    'agent_id':           'VARCHAR',
    'location_id':        'VARCHAR',
    'property_type':      'VARCHAR',
    'bedrooms':           'SMALLINT',
    'purpose':            'VARCHAR',
    'size_sqft':          'DECIMAL(10, 2)',
    'initial_price_aed':  'DECIMAL(14, 2)',
    'current_price_aed':  'DECIMAL(14, 2)',
    'price_change_count': 'SMALLINT',
    'listed_date':        'DATE',
    'last_updated_date':  'DATE',
    'removed_date':       'DATE',      -- empty in the CSV = still active = NULL
    'listing_status':     'VARCHAR',
    'view_count':         'INTEGER',
    'lead_count':         'INTEGER'
});

-- One pass to decide validity; NULL reject_reason = the row is loadable.
CREATE TABLE stg.listings_checked AS
SELECT
    *,
    CASE
        WHEN size_sqft <= 0                                   THEN 'non_positive_size'
        WHEN initial_price_aed <= 0 OR current_price_aed <= 0 THEN 'non_positive_price'
        WHEN removed_date < listed_date                       THEN 'removed_before_listed'
        WHEN last_updated_date < listed_date                  THEN 'updated_before_listed'
    END AS reject_reason
FROM stg.listings_raw;

CREATE TABLE stg.listings_clean AS
SELECT * EXCLUDE (reject_reason) FROM stg.listings_checked WHERE reject_reason IS NULL;

CREATE TABLE stg.listings_rejected AS
SELECT * FROM stg.listings_checked WHERE reject_reason IS NOT NULL;
