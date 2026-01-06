-- 03_load_dim_date.sql
-- Generate the calendar (2025-2026) instead of loading it from a source system.

INSERT INTO dim_date
SELECT
    year(d) * 10000 + month(d) * 100 + day(d)  AS date_key,
    d                                          AS full_date,
    isodow(d)                                  AS day_of_week,
    dayname(d)                                 AS day_name,
    day(d)                                     AS day_of_month,
    CAST(date_trunc('week', d) AS DATE)        AS week_start_date,
    month(d)                                   AS month_num,
    monthname(d)                               AS month_name,
    strftime(d, '%Y-%m')                       AS year_month,
    quarter(d)                                 AS quarter_num,
    year(d) || '-Q' || quarter(d)              AS year_quarter,
    year(d)                                    AS year_num,
    isodow(d) IN (6, 7)                        AS is_weekend,
    d = last_day(d)                            AS is_month_end,
    FALSE                                      AS is_placeholder
FROM (
    SELECT CAST(g AS DATE) AS d
    FROM generate_series(DATE '2025-01-01', DATE '2026-12-31', INTERVAL 1 DAY) AS t(g)
);

-- "Not yet occurred" member: every fact date key must resolve, including for events
-- that have not happened. Using a far-future date means predicates like
-- "removed_date_key > 20260331" correctly include still-active listings.
INSERT INTO dim_date VALUES (
    99991231, DATE '9999-12-31', 0, 'N/A', 0, DATE '9999-12-31',
    0, 'N/A', 'N/A', 0, 'N/A', 9999, FALSE, FALSE, TRUE
);
