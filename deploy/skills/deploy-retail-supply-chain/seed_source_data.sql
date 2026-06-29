-- =============================================================================
-- SEED SOURCE DATA: Agentic Retail Supply Chain Inventory
-- Populates all source tables with realistic synthetic data.
-- Idempotent: safe to run multiple times (INSERT OVERWRITE replaces data atomically).
--
-- Prerequisite: project_scaffolding_deploy.sql must have been run first.
-- Execution:  snow sql -f deploy/seed_source_data.sql
-- =============================================================================

USE WAREHOUSE RETAIL_SUPPLY_CHAIN_QS_WH;
USE DATABASE RETAIL_SUPPLY_CHAIN_DB;


-- =============================================================================
-- 2. INVENTORY SCHEMA
-- =============================================================================
USE SCHEMA INVENTORY;

-- 2a. LOCATIONS (5 rows)
CREATE TABLE IF NOT EXISTS LOCATIONS (
    LOCATION_ID     VARCHAR(10)   PRIMARY KEY,
    LOCATION_NAME   VARCHAR(100)  NOT NULL,
    LOCATION_TYPE   VARCHAR(30)   NOT NULL,
    REGION          VARCHAR(20)   NOT NULL,
    ADDRESS         VARCHAR(200),
    CAPACITY_UNITS  INTEGER       NOT NULL
);

INSERT OVERWRITE INTO LOCATIONS (LOCATION_ID, LOCATION_NAME, LOCATION_TYPE, REGION, ADDRESS, CAPACITY_UNITS)
VALUES
    ('LOC-001', 'East Coast Distribution Center', 'WAREHOUSE', 'NORTHEAST', '500 Industrial Blvd, Newark, NJ 07102', 50000),
    ('LOC-002', 'Midwest Mega Warehouse', 'WAREHOUSE', 'MIDWEST', '1200 Logistics Pkwy, Columbus, OH 43215', 75000),
    ('LOC-003', 'Manhattan Flagship Store', 'STORE', 'NORTHEAST', '789 5th Avenue, New York, NY 10022', 5000),
    ('LOC-004', 'LA Retail Center', 'STORE', 'WEST', '350 Rodeo Drive, Los Angeles, CA 90210', 4500),
    ('LOC-005', 'Pacific Online Fulfillment Hub', 'FULFILLMENT_CENTER', 'PACIFIC', '8800 Commerce Way, Portland, OR 97201', 60000);

-- 2b. PRODUCTS (50 rows)
CREATE TABLE IF NOT EXISTS PRODUCTS (
    SKU              VARCHAR(20)    PRIMARY KEY,
    PRODUCT_NAME     VARCHAR(200)   NOT NULL,
    CATEGORY         VARCHAR(50)    NOT NULL,
    SUBCATEGORY      VARCHAR(50)    NOT NULL,
    UNIT_WEIGHT_KG   DECIMAL(6,2)   NOT NULL,
    LEAD_TIME_DAYS   INTEGER        NOT NULL,
    CREATED_AT       TIMESTAMP_NTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP()
);

INSERT OVERWRITE INTO PRODUCTS (SKU, PRODUCT_NAME, CATEGORY, SUBCATEGORY, UNIT_WEIGHT_KG, LEAD_TIME_DAYS)
VALUES
    -- Electronics (10)
    ('SKU-E001', 'Pro Wireless Headphones 500',   'Electronics', 'Audio',       0.35,  7),
    ('SKU-E002', '4K Ultra Smart TV 55"',          'Electronics', 'Television',  18.50, 14),
    ('SKU-E003', 'Titanium Laptop Pro 16"',        'Electronics', 'Computers',   2.10,  14),
    ('SKU-E004', 'Wireless Gaming Mouse RGB',       'Electronics', 'Peripherals', 0.12,  7),
    ('SKU-E005', 'Smart Home Security Camera',      'Electronics', 'Smart Home',  0.45,  10),
    ('SKU-E006', 'Portable Bluetooth Speaker',      'Electronics', 'Audio',       0.68,  7),
    ('SKU-E007', 'Tablet Air 11" 256GB',            'Electronics', 'Tablets',     0.48,  14),
    ('SKU-E008', 'Noise-Canceling Earbuds Pro',     'Electronics', 'Audio',       0.08,  7),
    ('SKU-E009', 'Mechanical Keyboard TKL',         'Electronics', 'Peripherals', 0.95,  7),
    ('SKU-E010', 'USB-C Docking Station',           'Electronics', 'Accessories', 0.55,  5),
    -- Apparel (10)
    ('SKU-A001', 'Premium Cotton T-Shirt',          'Apparel', 'Tops',       0.20, 21),
    ('SKU-A002', 'Slim Fit Denim Jeans',            'Apparel', 'Bottoms',    0.75, 21),
    ('SKU-A003', 'Waterproof Winter Jacket',        'Apparel', 'Outerwear',  1.20, 28),
    ('SKU-A004', 'Athletic Running Shoes',          'Apparel', 'Footwear',   0.65, 21),
    ('SKU-A005', 'Cashmere Blend Sweater',          'Apparel', 'Tops',       0.40, 21),
    ('SKU-A006', 'Formal Dress Shirt',              'Apparel', 'Tops',       0.25, 21),
    ('SKU-A007', 'Yoga Leggings High-Rise',         'Apparel', 'Activewear', 0.22, 14),
    ('SKU-A008', 'Leather Belt Classic',            'Apparel', 'Accessories',0.30, 14),
    ('SKU-A009', 'Wool Blend Dress Pants',          'Apparel', 'Bottoms',    0.55, 21),
    ('SKU-A010', 'Summer Linen Shorts',             'Apparel', 'Bottoms',    0.18, 21),
    -- Home & Garden (10)
    ('SKU-H001', 'Memory Foam Pillow Set',          'Home & Garden', 'Bedding',    1.80, 10),
    ('SKU-H002', 'Stainless Steel Cookware 10pc',   'Home & Garden', 'Kitchen',    8.50, 10),
    ('SKU-H003', 'Smart LED Desk Lamp',             'Home & Garden', 'Lighting',   1.20,  7),
    ('SKU-H004', 'Organic Cotton Bath Towels 4pk',  'Home & Garden', 'Bath',       2.40, 10),
    ('SKU-H005', 'Indoor Herb Garden Kit',          'Home & Garden', 'Garden',     3.20, 14),
    ('SKU-H006', 'Robotic Vacuum Cleaner',          'Home & Garden', 'Appliances', 3.80, 14),
    ('SKU-H007', 'Scented Candle Collection',       'Home & Garden', 'Decor',      1.50, 10),
    ('SKU-H008', 'Bamboo Shelf Organizer',          'Home & Garden', 'Storage',    4.20, 10),
    ('SKU-H009', 'Smart Thermostat WiFi',           'Home & Garden', 'Smart Home', 0.35, 10),
    ('SKU-H010', 'Ceramic Plant Pots Set of 3',     'Home & Garden', 'Garden',     5.50, 14),
    -- Sports (10)
    ('SKU-S001', 'Carbon Fiber Tennis Racket',      'Sports', 'Racket Sports', 0.30, 10),
    ('SKU-S002', 'Adjustable Dumbbell Set 50lb',    'Sports', 'Fitness',       23.00, 10),
    ('SKU-S003', 'Yoga Mat Premium 6mm',            'Sports', 'Yoga',          1.80,  7),
    ('SKU-S004', 'GPS Running Watch Pro',           'Sports', 'Wearables',     0.05, 14),
    ('SKU-S005', 'Insulated Water Bottle 32oz',     'Sports', 'Hydration',     0.45,  7),
    ('SKU-S006', 'Resistance Bands Set 5pc',        'Sports', 'Fitness',       0.60, 10),
    ('SKU-S007', 'Mountain Bike Helmet',            'Sports', 'Cycling',       0.35, 14),
    ('SKU-S008', 'Foam Roller Recovery 18"',        'Sports', 'Recovery',      0.80,  7),
    ('SKU-S009', 'Basketball Official Size 7',      'Sports', 'Ball Sports',   0.62, 10),
    ('SKU-S010', 'Camping Backpack 65L',            'Sports', 'Outdoor',       1.90, 14),
    -- Beauty (10)
    ('SKU-B001', 'Vitamin C Brightening Serum',     'Beauty', 'Skincare',   0.08,  7),
    ('SKU-B002', 'Professional Hair Dryer 1875W',   'Beauty', 'Hair Tools', 0.75, 10),
    ('SKU-B003', 'Retinol Night Cream 50ml',        'Beauty', 'Skincare',   0.10,  7),
    ('SKU-B004', 'Organic Shampoo & Conditioner',   'Beauty', 'Hair Care',  0.85,  7),
    ('SKU-B005', 'Eyeshadow Palette 24 Colors',     'Beauty', 'Makeup',     0.15,  7),
    ('SKU-B006', 'Electric Facial Cleansing Brush', 'Beauty', 'Devices',    0.20, 10),
    ('SKU-B007', 'Luxury Perfume Eau de Parfum',    'Beauty', 'Fragrance',  0.35, 14),
    ('SKU-B008', 'Hyaluronic Acid Moisturizer',     'Beauty', 'Skincare',   0.12,  7),
    ('SKU-B009', 'Matte Lipstick Collection 6pc',   'Beauty', 'Makeup',     0.18,  7),
    ('SKU-B010', 'Nail Polish Gel Kit UV',          'Beauty', 'Nails',      0.55,  7);

-- 2c. STOCK_LEVELS (~250 rows: 50 SKUs × 5 locations)
CREATE TABLE IF NOT EXISTS STOCK_LEVELS (
    SKU                 VARCHAR(20)   NOT NULL,
    LOCATION_ID         VARCHAR(10)   NOT NULL,
    SNAPSHOT_DATE       DATE          NOT NULL DEFAULT CURRENT_DATE(),
    QUANTITY_ON_HAND    INTEGER       NOT NULL,
    QUANTITY_RESERVED   INTEGER       NOT NULL DEFAULT 0,
    BATCH_RECEIVED_DATE DATE,
    REORDER_POINT       INTEGER       NOT NULL,
    PRIMARY KEY (SKU, LOCATION_ID, SNAPSHOT_DATE)
);

-- Generate stock levels for all SKU/Location combinations with realistic variance
-- Not all SKUs at all locations (stores carry less variety)
INSERT OVERWRITE INTO STOCK_LEVELS (SKU, LOCATION_ID, SNAPSHOT_DATE, QUANTITY_ON_HAND, QUANTITY_RESERVED, BATCH_RECEIVED_DATE, REORDER_POINT)
SELECT
    p.SKU,
    l.LOCATION_ID,
    CURRENT_DATE(),
    -- Warehouses have more stock; stores have less; minimum 10 units everywhere
    CASE
        WHEN l.LOCATION_TYPE = 'WAREHOUSE' THEN UNIFORM(50, 500, RANDOM())
        WHEN l.LOCATION_TYPE = 'STORE' THEN UNIFORM(10, 80, RANDOM())
        ELSE UNIFORM(30, 400, RANDOM()) -- FULFILLMENT_CENTER
    END AS QUANTITY_ON_HAND,
    -- Reserved is ~50% of on-hand (computed via a correlated expression)
    CASE
        WHEN l.LOCATION_TYPE = 'WAREHOUSE' THEN ROUND(UNIFORM(50, 500, RANDOM()) * UNIFORM(40, 60, RANDOM()) / 100)
        WHEN l.LOCATION_TYPE = 'STORE' THEN ROUND(UNIFORM(10, 80, RANDOM()) * UNIFORM(40, 60, RANDOM()) / 100)
        ELSE ROUND(UNIFORM(30, 400, RANDOM()) * UNIFORM(40, 60, RANDOM()) / 100) -- FULFILLMENT_CENTER
    END AS QUANTITY_RESERVED,
    DATEADD('day', -UNIFORM(1, 60, RANDOM()), CURRENT_DATE()) AS BATCH_RECEIVED_DATE,
    CASE
        WHEN l.LOCATION_TYPE = 'WAREHOUSE' THEN UNIFORM(30, 100, RANDOM())
        WHEN l.LOCATION_TYPE = 'STORE' THEN UNIFORM(10, 30, RANDOM())
        ELSE UNIFORM(20, 80, RANDOM())
    END AS REORDER_POINT
FROM PRODUCTS p
CROSS JOIN LOCATIONS l
-- Stores don't carry all products: exclude ~20% randomly for stores
WHERE NOT (l.LOCATION_TYPE = 'STORE' AND UNIFORM(1, 100, RANDOM()) <= 20);

-- 2d. DATE_DIMENSION (365 rows for current year)
CREATE TABLE IF NOT EXISTS DATE_DIMENSION (
    DATE_KEY     DATE        PRIMARY KEY,
    DAY_OF_WEEK  INTEGER     NOT NULL,
    DAY_NAME     VARCHAR(10) NOT NULL,
    MONTH_NUM    INTEGER     NOT NULL,
    MONTH_NAME   VARCHAR(10) NOT NULL,
    QUARTER      INTEGER     NOT NULL,
    YEAR         INTEGER     NOT NULL,
    IS_WEEKEND   BOOLEAN     NOT NULL,
    IS_HOLIDAY   BOOLEAN     NOT NULL DEFAULT FALSE
);

INSERT OVERWRITE INTO DATE_DIMENSION (DATE_KEY, DAY_OF_WEEK, DAY_NAME, MONTH_NUM, MONTH_NAME, QUARTER, YEAR, IS_WEEKEND, IS_HOLIDAY)
SELECT
    dt AS DATE_KEY,
    DAYOFWEEK(dt) AS DAY_OF_WEEK,
    DAYNAME(dt) AS DAY_NAME,
    MONTH(dt) AS MONTH_NUM,
    MONTHNAME(dt) AS MONTH_NAME,
    QUARTER(dt) AS QUARTER,
    YEAR(dt) AS YEAR,
    CASE WHEN DAYOFWEEK(dt) IN (0, 6) THEN TRUE ELSE FALSE END AS IS_WEEKEND,
    CASE
        WHEN (MONTH(dt) = 1 AND DAY(dt) = 1) THEN TRUE    -- New Year's Day
        WHEN (MONTH(dt) = 7 AND DAY(dt) = 4) THEN TRUE    -- Independence Day
        WHEN (MONTH(dt) = 12 AND DAY(dt) = 25) THEN TRUE  -- Christmas
        WHEN (MONTH(dt) = 11 AND DAY(dt) BETWEEN 22 AND 28 AND DAYOFWEEK(dt) = 4) THEN TRUE -- Thanksgiving
        WHEN (MONTH(dt) = 5 AND DAY(dt) BETWEEN 25 AND 31 AND DAYOFWEEK(dt) = 1) THEN TRUE  -- Memorial Day
        WHEN (MONTH(dt) = 9 AND DAY(dt) BETWEEN 1 AND 7 AND DAYOFWEEK(dt) = 1) THEN TRUE    -- Labor Day
        ELSE FALSE
    END AS IS_HOLIDAY
FROM (
    SELECT DATEADD('day', SEQ4(), DATE_TRUNC('year', CURRENT_DATE())) AS dt
    FROM TABLE(GENERATOR(ROWCOUNT => 365))
) dates
WHERE YEAR(dt) = YEAR(CURRENT_DATE());

-- =============================================================================
-- 3. ORDERS SCHEMA
-- =============================================================================
USE SCHEMA ORDERS;

-- 3a. ORDER_HEADERS (~200 rows)
CREATE TABLE IF NOT EXISTS ORDER_HEADERS (
    ORDER_ID               VARCHAR(20)    PRIMARY KEY,
    CUSTOMER_ID            VARCHAR(20)    NOT NULL,
    ORDER_DATE             DATE           NOT NULL,
    ORDER_STATUS           VARCHAR(20)    NOT NULL,
    SALES_CHANNEL          VARCHAR(20)    NOT NULL,
    FULFILLMENT_LOCATION_ID VARCHAR(10)   NOT NULL,
    TOTAL_AMOUNT           DECIMAL(12,2)  NOT NULL,
    SHIPPING_METHOD        VARCHAR(20)    NOT NULL
);

INSERT OVERWRITE INTO ORDER_HEADERS (ORDER_ID, CUSTOMER_ID, ORDER_DATE, ORDER_STATUS, SALES_CHANNEL, FULFILLMENT_LOCATION_ID, TOTAL_AMOUNT, SHIPPING_METHOD)
SELECT
    ORDER_ID, CUSTOMER_ID, ORDER_DATE,
    CASE
        WHEN r_status <= 10 THEN 'Pending'
        WHEN r_status <= 25 THEN 'Processing'
        WHEN r_status <= 45 THEN 'Shipped'
        WHEN r_status <= 85 THEN 'Delivered'
        ELSE 'Cancelled'
    END AS ORDER_STATUS,
    CASE
        WHEN r_channel <= 55 THEN 'Online'
        WHEN r_channel <= 80 THEN 'In-Store'
        ELSE 'Wholesale'
    END AS SALES_CHANNEL,
    CASE UNIFORM(1, 5, RANDOM())
        WHEN 1 THEN 'LOC-001'
        WHEN 2 THEN 'LOC-002'
        WHEN 3 THEN 'LOC-003'
        WHEN 4 THEN 'LOC-004'
        ELSE 'LOC-005'
    END AS FULFILLMENT_LOCATION_ID,
    TOTAL_AMOUNT,
    CASE
        WHEN r_ship <= 60 THEN 'Standard'
        WHEN r_ship <= 85 THEN 'Express'
        ELSE 'Overnight'
    END AS SHIPPING_METHOD
FROM (
    SELECT
        'ORD-' || LPAD(SEQ4() + 1, 6, '0') AS ORDER_ID,
        'CUST-' || LPAD(UNIFORM(1, 500, RANDOM()), 5, '0') AS CUSTOMER_ID,
        DATEADD('day', -UNIFORM(0, 180, RANDOM()), CURRENT_DATE()) AS ORDER_DATE,
        UNIFORM(1, 100, RANDOM()) AS r_status,
        UNIFORM(1, 100, RANDOM()) AS r_channel,
        ROUND(UNIFORM(15, 1500, RANDOM()) + UNIFORM(0, 99, RANDOM()) / 100.0, 2) AS TOTAL_AMOUNT,
        UNIFORM(1, 100, RANDOM()) AS r_ship
    FROM TABLE(GENERATOR(ROWCOUNT => 200))
) sub;

-- 3b. ORDER_LINES (~500 rows)
CREATE TABLE IF NOT EXISTS ORDER_LINES (
    ORDER_LINE_ID  VARCHAR(20)    PRIMARY KEY,
    ORDER_ID       VARCHAR(20)    NOT NULL,
    SKU            VARCHAR(20)    NOT NULL,
    QUANTITY       INTEGER        NOT NULL,
    UNIT_PRICE     DECIMAL(10,2)  NOT NULL,
    LINE_TOTAL     DECIMAL(10,2)  NOT NULL,
    LINE_STATUS    VARCHAR(20)    NOT NULL
);

INSERT OVERWRITE INTO ORDER_LINES (ORDER_LINE_ID, ORDER_ID, SKU, QUANTITY, UNIT_PRICE, LINE_TOTAL, LINE_STATUS)
WITH order_ids AS (
    SELECT ORDER_ID, ORDER_STATUS, ROW_NUMBER() OVER (ORDER BY ORDER_ID) AS rn
    FROM ORDER_HEADERS
),
sku_list AS (
    SELECT SKU, CATEGORY, ROW_NUMBER() OVER (ORDER BY SKU) AS sku_rn
    FROM RETAIL_SUPPLY_CHAIN_DB.INVENTORY.PRODUCTS
),
line_gen AS (
    SELECT
        SEQ4() + 1 AS line_num,
        -- Each order gets 1-5 lines (avg ~2.5 for ~500 total from 200 orders)
        CEIL((SEQ4() + 1) / 2.5)::INT AS order_idx
    FROM TABLE(GENERATOR(ROWCOUNT => 500))
)
SELECT
    'OL-' || LPAD(lg.line_num, 6, '0') AS ORDER_LINE_ID,
    o.ORDER_ID,
    s.SKU,
    UNIFORM(1, 5, RANDOM()) AS QUANTITY,
    CASE s.CATEGORY
        WHEN 'Electronics' THEN ROUND(UNIFORM(20, 800, RANDOM()) + UNIFORM(0, 99, RANDOM()) / 100.0, 2)
        WHEN 'Apparel' THEN ROUND(UNIFORM(15, 150, RANDOM()) + UNIFORM(0, 99, RANDOM()) / 100.0, 2)
        WHEN 'Home & Garden' THEN ROUND(UNIFORM(10, 200, RANDOM()) + UNIFORM(0, 99, RANDOM()) / 100.0, 2)
        WHEN 'Sports' THEN ROUND(UNIFORM(12, 250, RANDOM()) + UNIFORM(0, 99, RANDOM()) / 100.0, 2)
        ELSE ROUND(UNIFORM(8, 120, RANDOM()) + UNIFORM(0, 99, RANDOM()) / 100.0, 2)
    END AS UNIT_PRICE,
    0 AS LINE_TOTAL, -- placeholder, will update
    CASE
        WHEN o.ORDER_STATUS = 'Delivered' THEN 'Fulfilled'
        WHEN o.ORDER_STATUS = 'Cancelled' THEN 'Cancelled'
        WHEN o.ORDER_STATUS = 'Shipped' THEN 'Fulfilled'
        WHEN UNIFORM(1, 100, RANDOM()) <= 10 THEN 'Backordered'
        ELSE 'Pending'
    END AS LINE_STATUS
FROM line_gen lg
JOIN order_ids o ON o.rn = LEAST(lg.order_idx, 200)
JOIN sku_list s ON s.sku_rn = (MOD(lg.line_num + UNIFORM(0, 49, RANDOM()), 50) + 1);

-- Update LINE_TOTAL = QUANTITY * UNIT_PRICE
UPDATE ORDER_LINES SET LINE_TOTAL = QUANTITY * UNIT_PRICE;

-- 3c. DEMAND_FORECAST (~250 rows)
CREATE TABLE IF NOT EXISTS DEMAND_FORECAST (
    FORECAST_ID      VARCHAR(20)    PRIMARY KEY,
    SKU              VARCHAR(20)    NOT NULL,
    LOCATION_ID      VARCHAR(10)    NOT NULL,
    FORECAST_DATE    DATE           NOT NULL,
    FORECASTED_UNITS INTEGER        NOT NULL,
    CONFIDENCE_LEVEL DECIMAL(3,2)   NOT NULL,
    MODEL_VERSION    VARCHAR(20)    NOT NULL
);

INSERT OVERWRITE INTO DEMAND_FORECAST (FORECAST_ID, SKU, LOCATION_ID, FORECAST_DATE, FORECASTED_UNITS, CONFIDENCE_LEVEL, MODEL_VERSION)
SELECT
    'FC-' || LPAD(ROW_NUMBER() OVER (ORDER BY p.SKU, l.LOCATION_ID), 6, '0') AS FORECAST_ID,
    p.SKU,
    l.LOCATION_ID,
    DATEADD('day', 30, CURRENT_DATE()) AS FORECAST_DATE,
    CASE
        WHEN l.LOCATION_TYPE = 'WAREHOUSE' THEN UNIFORM(20, 200, RANDOM())
        WHEN l.LOCATION_TYPE = 'STORE' THEN UNIFORM(5, 50, RANDOM())
        ELSE UNIFORM(15, 150, RANDOM())
    END AS FORECASTED_UNITS,
    ROUND(UNIFORM(55, 95, RANDOM()) / 100.0, 2) AS CONFIDENCE_LEVEL,
    'v2.3.1' AS MODEL_VERSION
FROM RETAIL_SUPPLY_CHAIN_DB.INVENTORY.PRODUCTS p
CROSS JOIN RETAIL_SUPPLY_CHAIN_DB.INVENTORY.LOCATIONS l;

-- =============================================================================
-- 4. CUSTOMER RETURNS (in ORDERS schema)
-- =============================================================================

-- 4a. CUSTOMER_RETURNS (~150 rows)
CREATE TABLE IF NOT EXISTS RETAIL_SUPPLY_CHAIN_DB.ORDERS.CUSTOMER_RETURNS (
    RETURN_ID             VARCHAR(20)    PRIMARY KEY,
    ORDER_ID              VARCHAR(20)    NOT NULL,
    ORDER_LINE_ID         VARCHAR(20)    NOT NULL,
    SKU                   VARCHAR(20)    NOT NULL,
    RETURN_DATE           DATE           NOT NULL,
    RETURN_REASON         VARCHAR(30)    NOT NULL,
    RETURN_CHANNEL        VARCHAR(20)    NOT NULL,
    ORIGINAL_SALE_CHANNEL VARCHAR(20)    NOT NULL,
    ITEM_CONDITION        VARCHAR(20)    NOT NULL,
    QUANTITY_RETURNED     INTEGER        NOT NULL,
    RECEIVING_LOCATION_ID VARCHAR(10)    NOT NULL,
    DISPOSITION_STATUS    VARCHAR(20)    NOT NULL,
    REFUND_AMOUNT         DECIMAL(10,2)  NOT NULL,
    RETURN_INITIATED_DATE DATE           NOT NULL,
    RETURN_RECEIVED_DATE  DATE
);

INSERT OVERWRITE INTO RETAIL_SUPPLY_CHAIN_DB.ORDERS.CUSTOMER_RETURNS (RETURN_ID, ORDER_ID, ORDER_LINE_ID, SKU, RETURN_DATE, RETURN_REASON, RETURN_CHANNEL, ORIGINAL_SALE_CHANNEL, ITEM_CONDITION, QUANTITY_RETURNED, RECEIVING_LOCATION_ID, DISPOSITION_STATUS, REFUND_AMOUNT, RETURN_INITIATED_DATE, RETURN_RECEIVED_DATE)
WITH delivered_lines AS (
    SELECT
        ol.ORDER_LINE_ID,
        ol.ORDER_ID,
        ol.SKU,
        ol.UNIT_PRICE,
        ol.QUANTITY,
        oh.ORDER_DATE,
        oh.SALES_CHANNEL,
        ROW_NUMBER() OVER (ORDER BY RANDOM()) AS rn
    FROM RETAIL_SUPPLY_CHAIN_DB.ORDERS.ORDER_LINES ol
    JOIN RETAIL_SUPPLY_CHAIN_DB.ORDERS.ORDER_HEADERS oh ON ol.ORDER_ID = oh.ORDER_ID
    WHERE oh.ORDER_STATUS IN ('Delivered', 'Shipped')
      AND ol.LINE_STATUS = 'Fulfilled'
),
returns_raw AS (
    SELECT
        *,
        UNIFORM(1, 100, RANDOM()) AS r_reason,
        UNIFORM(1, 100, RANDOM()) AS r_condition,
        UNIFORM(1, 100, RANDOM()) AS r_disposition,
        UNIFORM(1, 100, RANDOM()) AS r_channel
    FROM delivered_lines
    WHERE rn <= 150
)
SELECT
    'RET-' || LPAD(rn, 6, '0') AS RETURN_ID,
    ORDER_ID,
    ORDER_LINE_ID,
    SKU,
    DATEADD('day', UNIFORM(3, 30, RANDOM()), ORDER_DATE) AS RETURN_DATE,
    CASE
        WHEN r_reason <= 25 THEN 'Defective'
        WHEN r_reason <= 45 THEN 'Wrong Item'
        WHEN r_reason <= 60 THEN 'Not as Described'
        WHEN r_reason <= 85 THEN 'Changed Mind'
        ELSE 'Too Late'
    END AS RETURN_REASON,
    -- RETURN_CHANNEL: how the return was submitted
    CASE
        WHEN r_channel <= 50 THEN 'ONLINE'
        WHEN r_channel <= 80 THEN 'IN_STORE'
        ELSE 'MAIL'
    END AS RETURN_CHANNEL,
    -- ORIGINAL_SALE_CHANNEL: derived from order's sales channel
    SALES_CHANNEL AS ORIGINAL_SALE_CHANNEL,
    CASE
        WHEN r_condition <= 30 THEN 'New'
        WHEN r_condition <= 55 THEN 'Like New'
        WHEN r_condition <= 75 THEN 'Good'
        WHEN r_condition <= 90 THEN 'Fair'
        ELSE 'Poor'
    END AS ITEM_CONDITION,
    LEAST(UNIFORM(1, 3, RANDOM()), QUANTITY) AS QUANTITY_RETURNED,
    CASE UNIFORM(1, 5, RANDOM())
        WHEN 1 THEN 'LOC-001'
        WHEN 2 THEN 'LOC-002'
        WHEN 3 THEN 'LOC-003'
        WHEN 4 THEN 'LOC-004'
        ELSE 'LOC-005'
    END AS RECEIVING_LOCATION_ID,
    CASE
        WHEN r_disposition <= 30 THEN 'Pending'
        WHEN r_disposition <= 55 THEN 'Restocked'
        WHEN r_disposition <= 75 THEN 'Refurbished'
        WHEN r_disposition <= 90 THEN 'Liquidated'
        ELSE 'Disposed'
    END AS DISPOSITION_STATUS,
    ROUND(UNIT_PRICE * LEAST(UNIFORM(1, 3, RANDOM()), QUANTITY) * UNIFORM(80, 100, RANDOM()) / 100.0, 2) AS REFUND_AMOUNT,
    -- RETURN_INITIATED_DATE: same as return date (when customer started the return)
    DATEADD('day', UNIFORM(3, 30, RANDOM()), ORDER_DATE) AS RETURN_INITIATED_DATE,
    -- RETURN_RECEIVED_DATE: 3-10 days after initiation (NULL ~15% of the time for pending)
    CASE
        WHEN r_disposition <= 30 THEN NULL
        ELSE DATEADD('day', UNIFORM(3, 30, RANDOM()) + UNIFORM(3, 10, RANDOM()), ORDER_DATE)
    END AS RETURN_RECEIVED_DATE
FROM returns_raw;

-- =============================================================================
-- 5. FINANCE SCHEMA
-- =============================================================================
USE SCHEMA FINANCE;

-- 5a. PRODUCT_COSTS (~150 rows: 50 SKUs × 3 channels)
CREATE TABLE IF NOT EXISTS PRODUCT_COSTS (
    SKU               VARCHAR(20)    NOT NULL,
    CHANNEL           VARCHAR(20)    NOT NULL,
    COGS              DECIMAL(10,2)  NOT NULL,
    SELLING_PRICE     DECIMAL(10,2)  NOT NULL,
    GROSS_MARGIN      DECIMAL(5,4)   NOT NULL,
    LIQUIDATION_VALUE DECIMAL(10,2)  NOT NULL,
    PRIMARY KEY (SKU, CHANNEL)
);

INSERT OVERWRITE INTO PRODUCT_COSTS (SKU, CHANNEL, COGS, SELLING_PRICE, GROSS_MARGIN, LIQUIDATION_VALUE)
WITH base_costs AS (
    SELECT
        SKU,
        CATEGORY,
        CASE CATEGORY
            WHEN 'Electronics' THEN UNIFORM(30, 600, RANDOM())
            WHEN 'Apparel' THEN UNIFORM(10, 60, RANDOM())
            WHEN 'Home & Garden' THEN UNIFORM(8, 80, RANDOM())
            WHEN 'Sports' THEN UNIFORM(10, 150, RANDOM())
            WHEN 'Beauty' THEN UNIFORM(5, 45, RANDOM())
        END AS base_cogs
    FROM RETAIL_SUPPLY_CHAIN_DB.INVENTORY.PRODUCTS
)
SELECT
    b.SKU,
    ch.CHANNEL,
    ROUND(b.base_cogs, 2) AS COGS,
    ROUND(
        CASE ch.CHANNEL
            WHEN 'Online' THEN b.base_cogs * UNIFORM(180, 280, RANDOM()) / 100.0
            WHEN 'In-Store' THEN b.base_cogs * UNIFORM(200, 320, RANDOM()) / 100.0
            WHEN 'Wholesale' THEN b.base_cogs * UNIFORM(130, 160, RANDOM()) / 100.0
        END, 2
    ) AS SELLING_PRICE,
    0 AS GROSS_MARGIN, -- placeholder
    ROUND(b.base_cogs * UNIFORM(20, 40, RANDOM()) / 100.0, 2) AS LIQUIDATION_VALUE
FROM base_costs b
CROSS JOIN (SELECT 'Online' AS CHANNEL UNION ALL SELECT 'In-Store' UNION ALL SELECT 'Wholesale') ch;

-- Update GROSS_MARGIN = (SELLING_PRICE - COGS) / SELLING_PRICE
UPDATE PRODUCT_COSTS SET GROSS_MARGIN = ROUND((SELLING_PRICE - COGS) / SELLING_PRICE, 4);

-- 5b. SHIPPING_COSTS (20 rows: inter-location, self-excluded)
CREATE TABLE IF NOT EXISTS SHIPPING_COSTS (
    ORIGIN_LOCATION_ID      VARCHAR(10)   NOT NULL,
    DESTINATION_LOCATION_ID VARCHAR(10)   NOT NULL,
    COST_PER_UNIT           DECIMAL(10,2) NOT NULL,
    COST_PER_KG             DECIMAL(10,2) NOT NULL,
    TRANSIT_DAYS            INTEGER       NOT NULL,
    CARRIER                 VARCHAR(20)   NOT NULL,
    PRIMARY KEY (ORIGIN_LOCATION_ID, DESTINATION_LOCATION_ID)
);

INSERT OVERWRITE INTO SHIPPING_COSTS (ORIGIN_LOCATION_ID, DESTINATION_LOCATION_ID, COST_PER_UNIT, COST_PER_KG, TRANSIT_DAYS, CARRIER)
VALUES
    -- From LOC-001 (Newark, NJ - NORTHEAST)
    ('LOC-001', 'LOC-002', 2.50, 0.85, 2, 'FedEx'),
    ('LOC-001', 'LOC-003', 1.20, 0.45, 1, 'UPS'),
    ('LOC-001', 'LOC-004', 4.80, 1.50, 4, 'FedEx'),
    ('LOC-001', 'LOC-005', 4.20, 1.35, 4, 'UPS'),
    -- From LOC-002 (Columbus, OH - MIDWEST)
    ('LOC-002', 'LOC-001', 2.50, 0.85, 2, 'UPS'),
    ('LOC-002', 'LOC-003', 3.00, 1.00, 2, 'FedEx'),
    ('LOC-002', 'LOC-004', 4.50, 1.40, 3, 'USPS'),
    ('LOC-002', 'LOC-005', 3.80, 1.20, 3, 'DHL'),
    -- From LOC-003 (New York, NY - NORTHEAST)
    ('LOC-003', 'LOC-001', 1.20, 0.45, 1, 'UPS'),
    ('LOC-003', 'LOC-002', 3.00, 1.00, 2, 'FedEx'),
    ('LOC-003', 'LOC-004', 5.00, 1.60, 4, 'DHL'),
    ('LOC-003', 'LOC-005', 4.50, 1.45, 4, 'FedEx'),
    -- From LOC-004 (Los Angeles, CA - WEST)
    ('LOC-004', 'LOC-001', 4.80, 1.50, 4, 'UPS'),
    ('LOC-004', 'LOC-002', 4.50, 1.40, 3, 'FedEx'),
    ('LOC-004', 'LOC-003', 5.00, 1.60, 4, 'DHL'),
    ('LOC-004', 'LOC-005', 1.80, 0.60, 1, 'USPS'),
    -- From LOC-005 (Portland, OR - PACIFIC)
    ('LOC-005', 'LOC-001', 4.20, 1.35, 4, 'FedEx'),
    ('LOC-005', 'LOC-002', 3.80, 1.20, 3, 'UPS'),
    ('LOC-005', 'LOC-003', 4.50, 1.45, 4, 'DHL'),
    ('LOC-005', 'LOC-004', 1.80, 0.60, 1, 'USPS');


-- =============================================================================
-- END OF SEED DATA
-- =============================================================================
