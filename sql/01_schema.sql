-- 01_schema.sql
-- Star schema for real-estate listings (DuckDB dialect, PostgreSQL-flavoured).
-- Re-runnable: everything is dropped first, children before parents.
--
--   fact_listings  --< dim_date          (x3: listed / last-updated / removed, role-playing)
--                  --< dim_location
--                  --< dim_agent         (SCD Type 2)
--                  --< dim_property_type

DROP TABLE IF EXISTS fact_listings;
DROP TABLE IF EXISTS dim_agent;
DROP TABLE IF EXISTS dim_property_type;
DROP TABLE IF EXISTS dim_location;
DROP TABLE IF EXISTS dim_date;
DROP SEQUENCE IF EXISTS seq_location_key;
DROP SEQUENCE IF EXISTS seq_property_type_key;
DROP SEQUENCE IF EXISTS seq_agent_key;
DROP SCHEMA IF EXISTS stg CASCADE;

CREATE SCHEMA stg;  -- staging area: raw extracts land here before being modelled

CREATE SEQUENCE seq_location_key START 1;
CREATE SEQUENCE seq_property_type_key START 1;
CREATE SEQUENCE seq_agent_key START 1;

-- ---------------------------------------------------------------------------
-- dim_date: one row per calendar day, plus a placeholder member.
-- date_key is a YYYYMMDD integer (the one place a smart key is worth it: it sorts
-- and range-filters correctly). 99991231 is the "not yet occurred" member that
-- active listings use for removed_date_key, so no foreign key is ever NULL.
-- ---------------------------------------------------------------------------
CREATE TABLE dim_date (
    date_key         INTEGER  PRIMARY KEY,
    full_date        DATE     NOT NULL UNIQUE,
    day_of_week      SMALLINT NOT NULL,       -- ISO: 1 = Monday ... 7 = Sunday
    day_name         VARCHAR  NOT NULL,
    day_of_month     SMALLINT NOT NULL,
    week_start_date  DATE     NOT NULL,       -- Monday of the week; unambiguous weekly grouping
    month_num        SMALLINT NOT NULL,
    month_name       VARCHAR  NOT NULL,
    year_month       VARCHAR  NOT NULL,       -- 'YYYY-MM', sorts chronologically
    quarter_num      SMALLINT NOT NULL,
    year_quarter     VARCHAR  NOT NULL,       -- 'YYYY-Qn'
    year_num         SMALLINT NOT NULL,
    is_weekend       BOOLEAN  NOT NULL,       -- UAE weekend: Saturday and Sunday
    is_month_end     BOOLEAN  NOT NULL,
    is_placeholder   BOOLEAN  NOT NULL        -- TRUE only for the 99991231 member
);

-- ---------------------------------------------------------------------------
-- dim_location: grain = one row per sub-community. Hierarchy is flattened
-- (emirate > city > community > sub_community) so no snowflaking is needed.
-- SCD Type 1: attribute changes overwrite.
-- ---------------------------------------------------------------------------
CREATE TABLE dim_location (
    location_key   INTEGER PRIMARY KEY DEFAULT nextval('seq_location_key'),
    location_id    VARCHAR NOT NULL UNIQUE,   -- business key from the source system
    emirate        VARCHAR NOT NULL,
    city           VARCHAR NOT NULL,
    community      VARCHAR NOT NULL,
    sub_community  VARCHAR NOT NULL,          -- 'N/A' where the community has no sub-areas
    market_tier    VARCHAR NOT NULL CHECK (market_tier IN ('Prime', 'Mid-market', 'Affordable', 'Unknown'))
);

-- ---------------------------------------------------------------------------
-- dim_property_type: grain = property type x bedroom count (e.g. "2 BR Apartment"),
-- because that is the unit buyers and renters actually compare. SCD Type 1.
-- ---------------------------------------------------------------------------
CREATE TABLE dim_property_type (
    property_type_key    INTEGER  PRIMARY KEY DEFAULT nextval('seq_property_type_key'),
    property_type        VARCHAR  NOT NULL,   -- Apartment, Penthouse, Townhouse, Villa
    property_group       VARCHAR  NOT NULL,   -- 'Apartment building' | 'Landed home'
    bedrooms             SMALLINT NOT NULL,   -- 0 = studio
    bedroom_label        VARCHAR  NOT NULL,   -- 'Studio', '1 BR' ... '5+ BR'
    property_type_label  VARCHAR  NOT NULL,   -- '2 BR Apartment'
    UNIQUE (property_type, bedrooms)
);

-- ---------------------------------------------------------------------------
-- dim_agent: SCD Type 2. An agent who changes agency or gets verified gets a NEW
-- row; history is never overwritten. effective_to is inclusive (the day before the
-- next version starts) and 9999-12-31 for the current version.
-- Analyse an agent over time by agent_id (business key), never by agent_key.
-- ---------------------------------------------------------------------------
CREATE TABLE dim_agent (
    agent_key       INTEGER PRIMARY KEY DEFAULT nextval('seq_agent_key'),
    agent_id        VARCHAR NOT NULL,         -- business key
    agent_name      VARCHAR NOT NULL,
    agency_name     VARCHAR NOT NULL,         -- tracked (Type 2)
    is_verified     BOOLEAN NOT NULL,         -- tracked (Type 2)
    effective_from  DATE    NOT NULL,
    effective_to    DATE    NOT NULL,
    is_current      BOOLEAN NOT NULL,
    UNIQUE (agent_id, effective_from),
    CHECK (effective_from <= effective_to)
);

-- ---------------------------------------------------------------------------
-- fact_listings: accumulating snapshot.
-- Grain: ONE ROW PER LISTING. The row is updated as the listing moves through its
-- lifecycle (posted -> price changes -> removed/expired), which is why there are
-- three date roles and why removed_date_key holds the 99991231 member until then.
--
-- Prices are AED. For purpose = 'RENT' the price is the ANNUAL rent (UAE convention),
-- so never sum or average prices across purposes.
-- ---------------------------------------------------------------------------
CREATE TABLE fact_listings (
    listing_id             VARCHAR PRIMARY KEY,  -- degenerate dimension (source listing reference)

    -- foreign keys to dimensions (never NULL: unmatched rows use the -1 "Unknown" member)
    property_type_key      INTEGER NOT NULL REFERENCES dim_property_type (property_type_key),
    location_key           INTEGER NOT NULL REFERENCES dim_location (location_key),
    agent_key              INTEGER NOT NULL REFERENCES dim_agent (agent_key),  -- version valid on the listed date
    listed_date_key        INTEGER NOT NULL REFERENCES dim_date (date_key),
    last_updated_date_key  INTEGER NOT NULL REFERENCES dim_date (date_key),
    removed_date_key       INTEGER NOT NULL REFERENCES dim_date (date_key),    -- 99991231 while ACTIVE

    -- low-cardinality descriptors kept on the fact (see README: would be a junk dimension at scale)
    purpose                VARCHAR NOT NULL CHECK (purpose IN ('SALE', 'RENT')),
    listing_status         VARCHAR NOT NULL CHECK (listing_status IN ('ACTIVE', 'REMOVED', 'EXPIRED')),

    -- measures
    initial_price_aed      DECIMAL(14, 2) NOT NULL CHECK (initial_price_aed > 0),
    current_price_aed      DECIMAL(14, 2) NOT NULL CHECK (current_price_aed > 0),
    size_sqft              DECIMAL(10, 2) NOT NULL CHECK (size_sqft > 0),
    price_change_count     SMALLINT       NOT NULL CHECK (price_change_count >= 0),
    view_count             INTEGER        NOT NULL CHECK (view_count >= 0),
    lead_count             INTEGER        NOT NULL CHECK (lead_count >= 0),
    days_on_market         INTEGER        CHECK (days_on_market >= 0),  -- NULL until removed

    -- lifecycle invariants the load must respect
    CHECK ((listing_status = 'ACTIVE') = (removed_date_key = 99991231)),
    CHECK ((listing_status = 'ACTIVE') = (days_on_market IS NULL))
);

-- Self-documenting warehouse: descriptions travel with the schema.
COMMENT ON TABLE dim_date          IS 'Calendar dimension; role-played three times by fact_listings. Member 99991231 = not yet occurred.';
COMMENT ON TABLE dim_location      IS 'Location hierarchy flattened to sub-community grain. SCD Type 1. Key -1 = Unknown.';
COMMENT ON TABLE dim_property_type IS 'Property type x bedrooms. SCD Type 1. Key -1 = Unknown.';
COMMENT ON TABLE dim_agent         IS 'Agents, SCD Type 2 on agency_name and is_verified. Key -1 = Unknown.';
COMMENT ON TABLE fact_listings     IS 'Accumulating snapshot, one row per listing. Prices are AED; RENT prices are annual.';
COMMENT ON COLUMN fact_listings.current_price_aed IS 'Latest asking price. Additive only within one purpose; use SUM(price)/SUM(size), not AVG(price/size), for price per sqft.';
COMMENT ON COLUMN fact_listings.days_on_market    IS 'removed date minus listed date; NULL while the listing is ACTIVE.';
