-- ============================================================
-- DATA CLEANING AND STANDARDIZATION PROJECT
-- SQL Server | CTEs | Window Functions
-- ============================================================
-- Dataset: Customer Orders Database (200,000+ rows)
-- Author: [Your Name]
-- ============================================================


-- ============================================================
-- STEP 1: EXPLORE THE RAW DATA
-- ============================================================

SELECT TOP 10 * FROM raw_customers;
SELECT TOP 10 * FROM raw_orders;

-- Check total row counts
SELECT COUNT(*) AS total_rows FROM raw_customers;       -- ~200,000+
SELECT COUNT(*) AS total_orders FROM raw_orders;

-- Spot NULL values across key columns
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN customer_name IS NULL THEN 1 ELSE 0 END) AS null_names,
    SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END)         AS null_emails,
    SUM(CASE WHEN phone IS NULL THEN 1 ELSE 0 END)         AS null_phones,
    SUM(CASE WHEN city IS NULL THEN 1 ELSE 0 END)          AS null_cities,
    SUM(CASE WHEN signup_date IS NULL THEN 1 ELSE 0 END)   AS null_dates
FROM raw_customers;


-- ============================================================
-- STEP 2: REMOVE DUPLICATES USING ROW_NUMBER()
-- ============================================================
-- Identify duplicates based on email (natural key for customers)

WITH cte_dedup AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY email
            ORDER BY customer_id ASC   -- Keep the earliest record
        ) AS row_num
    FROM raw_customers
)
SELECT * INTO staging_customers
FROM cte_dedup
WHERE row_num = 1;

-- Verify deduplication
SELECT
    (SELECT COUNT(*) FROM raw_customers)     AS before_dedup,
    (SELECT COUNT(*) FROM staging_customers) AS after_dedup,
    (SELECT COUNT(*) FROM raw_customers) - (SELECT COUNT(*) FROM staging_customers) AS duplicates_removed;


-- ============================================================
-- STEP 3: HANDLE NULL VALUES USING COALESCE
-- ============================================================

SELECT
    customer_id,
    COALESCE(customer_name, 'Unknown Customer')         AS customer_name,
    COALESCE(email, 'no-email@placeholder.com')         AS email,
    COALESCE(phone, '0000000000')                       AS phone,
    COALESCE(city, 'Unknown City')                      AS city,
    COALESCE(country, 'Unknown Country')                AS country,
    COALESCE(signup_date, '1900-01-01')                 AS signup_date,
    COALESCE(status, 'inactive')                        AS status
INTO cleaned_customers
FROM staging_customers;


-- ============================================================
-- STEP 4: FIX MISMATCHED LABELS USING CASE STATEMENTS
-- ============================================================
-- Raw data had inconsistent gender, status, and country labels

UPDATE cleaned_customers
SET
    -- Standardize gender labels
    gender = CASE
        WHEN LOWER(TRIM(gender)) IN ('m', 'male', 'man')         THEN 'Male'
        WHEN LOWER(TRIM(gender)) IN ('f', 'female', 'woman')     THEN 'Female'
        WHEN LOWER(TRIM(gender)) IN ('nb', 'non-binary', 'other') THEN 'Non-Binary'
        ELSE 'Not Specified'
    END,

    -- Standardize account status labels
    status = CASE
        WHEN LOWER(TRIM(status)) IN ('active', 'act', '1', 'yes', 'y') THEN 'Active'
        WHEN LOWER(TRIM(status)) IN ('inactive', 'inact', '0', 'no', 'n') THEN 'Inactive'
        WHEN LOWER(TRIM(status)) IN ('pending', 'pend', 'wait')         THEN 'Pending'
        ELSE 'Unknown'
    END,

    -- Standardize country names
    country = CASE
        WHEN UPPER(TRIM(country)) IN ('IN', 'IND', 'INDIA')     THEN 'India'
        WHEN UPPER(TRIM(country)) IN ('US', 'USA', 'AMERICA')   THEN 'United States'
        WHEN UPPER(TRIM(country)) IN ('UK', 'GB', 'GBR')        THEN 'United Kingdom'
        ELSE TRIM(country)
    END;


-- ============================================================
-- STEP 5: STANDARDIZE DATE FORMATS
-- ============================================================
-- Raw data had mixed formats: DD-MM-YYYY, MM/DD/YYYY, YYYY.MM.DD

-- Preview inconsistent date formats
SELECT DISTINCT signup_date
FROM raw_customers
WHERE signup_date NOT LIKE '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
ORDER BY signup_date;

-- Convert all dates to standard YYYY-MM-DD format
UPDATE cleaned_customers
SET signup_date =
    CASE
        -- Format: DD-MM-YYYY → YYYY-MM-DD
        WHEN signup_date LIKE '[0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9]'
            THEN SUBSTRING(signup_date, 7, 4) + '-' +
                 SUBSTRING(signup_date, 4, 2) + '-' +
                 SUBSTRING(signup_date, 1, 2)

        -- Format: MM/DD/YYYY → YYYY-MM-DD
        WHEN signup_date LIKE '[0-9][0-9]/[0-9][0-9]/[0-9][0-9][0-9][0-9]'
            THEN SUBSTRING(signup_date, 7, 4) + '-' +
                 SUBSTRING(signup_date, 1, 2) + '-' +
                 SUBSTRING(signup_date, 4, 2)

        -- Format: YYYY.MM.DD → YYYY-MM-DD
        WHEN signup_date LIKE '[0-9][0-9][0-9][0-9].[0-9][0-9].[0-9][0-9]'
            THEN REPLACE(signup_date, '.', '-')

        ELSE signup_date
    END;


-- ============================================================
-- STEP 6: STANDARDIZE PHONE NUMBER FORMATS
-- ============================================================
-- Remove spaces, dashes, parentheses, +91 country codes
-- Normalize to 10-digit format for Indian numbers

UPDATE cleaned_customers
SET phone = 
    CASE
        -- Remove +91 country code prefix
        WHEN phone LIKE '+91%'
            THEN RIGHT(REPLACE(REPLACE(REPLACE(REPLACE(phone, '+91', ''), '-', ''), ' ', ''), '(', ''), 10)

        -- Remove 0 trunk prefix
        WHEN phone LIKE '0%' AND LEN(REPLACE(REPLACE(phone, '-', ''), ' ', '')) = 11
            THEN RIGHT(REPLACE(REPLACE(phone, '-', ''), ' ', ''), 10)

        -- Clean formatting characters only
        ELSE REPLACE(REPLACE(REPLACE(REPLACE(phone, '-', ''), ' ', ''), '(', ''), ')', '')
    END;

-- Flag invalid phone numbers (not 10 digits)
SELECT customer_id, phone, LEN(phone) AS phone_length
FROM cleaned_customers
WHERE LEN(phone) <> 10 OR phone NOT LIKE '[0-9]%';


-- ============================================================
-- STEP 7: VALIDATE REFERENTIAL INTEGRITY ACROSS 5 TABLES
-- ============================================================

-- 7a. Orders without matching customers
SELECT o.order_id, o.customer_id
FROM raw_orders o
LEFT JOIN cleaned_customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- 7b. Order items without matching orders
SELECT oi.item_id, oi.order_id
FROM raw_order_items oi
LEFT JOIN raw_orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- 7c. Orders referencing deleted/invalid products
SELECT oi.order_id, oi.product_id
FROM raw_order_items oi
LEFT JOIN raw_products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- 7d. Payments without matching orders
SELECT p.payment_id, p.order_id
FROM raw_payments p
LEFT JOIN raw_orders o ON p.order_id = o.order_id
WHERE o.order_id IS NULL;

-- 7e. Reviews without matching customers or products
SELECT r.review_id, r.customer_id, r.product_id
FROM raw_reviews r
LEFT JOIN cleaned_customers c ON r.customer_id = c.customer_id
LEFT JOIN raw_products p ON r.product_id = p.product_id
WHERE c.customer_id IS NULL OR p.product_id IS NULL;


-- ============================================================
-- STEP 8: FINAL VALIDATION SUMMARY
-- ============================================================

SELECT
    'cleaned_customers'                                          AS table_name,
    COUNT(*)                                                     AS total_rows,
    SUM(CASE WHEN customer_name = 'Unknown Customer' THEN 1 ELSE 0 END) AS filled_nulls,
    SUM(CASE WHEN LEN(phone) = 10 THEN 1 ELSE 0 END)           AS valid_phones,
    SUM(CASE WHEN TRY_CAST(signup_date AS DATE) IS NOT NULL THEN 1 ELSE 0 END) AS valid_dates,
    COUNT(DISTINCT status)                                       AS distinct_statuses,
    COUNT(DISTINCT gender)                                       AS distinct_genders
FROM cleaned_customers;
