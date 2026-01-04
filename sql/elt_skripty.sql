// Využívame našu databázu
USE WAREHOUSE PIRANHA_WH;
USE DATABASE PIRANHA_DB;

// Vytvorenie schémy pre tabuľky
CREATE OR REPLACE SCHEMA PIRANHA_PRODUCTS_ELT;
USE SCHEMA PIRANHA_PRODUCTS_ELT;

// ELT - Extract
-- Products Staging
CREATE OR REPLACE TABLE products_staging AS
SELECT * FROM GOOGLE_SHOPPING_PRODUCTS_PRICES_DATASET.PUBLIC.GOOGLE_SHOPPING;
-- kontrola
SELECT * FROM products_staging;

// ELT - Load
-- Dim Product (SCD 1)
CREATE OR REPLACE TABLE dim_product AS
SELECT DISTINCT
    ean,
    url,
    currency,
    country,
    verified,
    directly_sold_on_google
FROM products_staging;
-- kontrola
SELECT * FROM dim_product;

-- Dim Shop (SCD 0)
CREATE OR REPLACE TABLE dim_shop AS
SELECT
    ROW_NUMBER() OVER (ORDER BY shop_name) AS idshop,
    shop_name AS name
FROM (
    SELECT DISTINCT shop_name FROM products_staging
);
-- kontrola
SELECT * FROM dim_shop;

-- Dim Promotion (SCD 0)
CREATE OR REPLACE TABLE dim_promotion AS
SELECT
    ROW_NUMBER() OVER (ORDER BY promotion_label_text) AS idpromotion,
    promotion_label_text AS label_text
FROM (
    SELECT DISTINCT COALESCE(promotion_label_text, 'N/A') AS promotion_label_text FROM products_staging
);
-- kontrola
SELECT * FROM dim_promotion;

-- Dim Offer (SCD 0)
CREATE OR REPLACE TABLE dim_offer AS
SELECT
    ROW_NUMBER() OVER (ORDER BY offer_additional_comment) AS idoffer,
    offer_additional_comment AS additional_comment
FROM (
    SELECT DISTINCT offer_additional_comment FROM products_staging
);
-- kontrola
SELECT * FROM dim_offer;

-- Dim Time (SCD 0)
CREATE OR REPLACE TABLE dim_time AS
SELECT DISTINCT
    TO_CHAR(TIME(lu)::TIME(0), 'HH24MISS') AS idtime,
    TIME(lu)::TIME(0) AS time,
    HOUR(lu) AS hour,
    MINUTE(lu) AS minute,
    SECOND(lu) AS second,
    CASE WHEN HOUR(lu) < 12 THEN 'am' ELSE 'pm' END AS am_pm
FROM (
    SELECT TO_TIMESTAMP_LTZ(latest_update) as lu FROM products_staging
);
-- kontrola
SELECT * FROM dim_time;

-- Dim Date (SCD 0)
CREATE OR REPLACE TABLE dim_date AS
SELECT DISTINCT
    TO_CHAR(DATE(lu), 'YYYYMMDD') AS iddate,
    DATE(lu) AS date,
    YEAR(lu) AS year,
    MONTH(lu) AS month,
    DAY(lu) AS day,
    QUARTER(lu) AS quarter,
    CASE DAYNAME(lu)
        WHEN 'Mon' THEN 'Monday'
        WHEN 'Tue' THEN 'Tuesday'
        WHEN 'Wed' THEN 'Wednesday'
        WHEN 'Thu' THEN 'Thursday'
        WHEN 'Fri' THEN 'Friday'
        WHEN 'Sat' THEN 'Saturday'
        WHEN 'Sun' THEN 'Sunday' END AS weekday
FROM (
    SELECT TO_TIMESTAMP_LTZ(latest_update) as lu FROM products_staging
);
-- kontrola
SELECT * FROM dim_date;

-- Fact Product Pricing
CREATE OR REPLACE TABLE fact_product_pricing AS
SELECT
    ROW_NUMBER() OVER (ORDER BY ean, idshop) AS id_product_pricing,
    *
FROM (
    SELECT DISTINCT
        s.idshop,
        p.ean,
        o.idoffer,
        pr.idpromotion,
        ddate.iddate,
        dtime.idtime,
        ps.price,
        ps.old_price,
        ps.shipping_cost,
        ps.total_cost,
        ps.position,
        ps.shop_review_rating,
        ps.shop_review_count,
        -- ELT - Transform (Window functions)
        AVG(ps.price) OVER (PARTITION BY p.ean) AS avg_product_price,
        COUNT(DISTINCT ps.shop_name) OVER (PARTITION BY p.ean) AS count_shops_selling
    FROM products_staging ps
    JOIN dim_product p ON ps.ean = p.ean
    JOIN dim_shop s ON ps.shop_name = s.name
    JOIN dim_promotion pr ON COALESCE(ps.promotion_label_text, 'N/A') = pr.label_text
    JOIN dim_offer o ON ps.offer_additional_comment = o.additional_comment
    JOIN dim_date ddate ON TO_CHAR(DATE(TO_TIMESTAMP_LTZ(latest_update)), 'YYYYMMDD') = ddate.iddate
    JOIN dim_time dtime ON TO_CHAR(TIME(TO_TIMESTAMP_LTZ(latest_update))::TIME(0), 'HH24MISS') = dtime.idtime
);
-- kontrola
SELECT * FROM fact_product_pricing
ORDER BY id_product_pricing;