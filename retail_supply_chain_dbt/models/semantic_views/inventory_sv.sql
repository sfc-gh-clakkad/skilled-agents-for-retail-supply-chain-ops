{{ config(materialized='semantic_view') }}
TABLES(
    sl AS {{ source('inventory', 'STOCK_LEVELS') }} PRIMARY KEY (SKU, LOCATION_ID, SNAPSHOT_DATE)
        COMMENT = 'Snapshot inventory by SKU and location. Metrics sum across locations but not across dates — filter to a single SNAPSHOT_DATE for point-in-time totals.'
    , loc AS {{ source('inventory', 'LOCATIONS') }} PRIMARY KEY (LOCATION_ID)
        COMMENT = 'All fulfillment/storage locations'
    , prod AS {{ source('inventory', 'PRODUCTS') }} PRIMARY KEY (SKU)
        COMMENT = 'Product master with attributes for transfer decisions'
)
RELATIONSHIPS(
    stock_to_locations AS sl (LOCATION_ID) REFERENCES loc (LOCATION_ID)
    , stock_to_products AS sl (SKU) REFERENCES prod (SKU)
)
FACTS(
    sl.quantity_on_hand AS QUANTITY_ON_HAND COMMENT = 'Current units on hand'
    , sl.quantity_reserved AS QUANTITY_RESERVED COMMENT = 'Units reserved for orders'
    , sl.reorder_point AS REORDER_POINT COMMENT = 'Minimum stock before reorder'
    , loc.capacity_units AS CAPACITY_UNITS COMMENT = 'Maximum storage capacity'
    , prod.unit_weight_kg AS UNIT_WEIGHT_KG COMMENT = 'Product weight in kg for shipping cost'
    , prod.lead_time_days AS LEAD_TIME_DAYS COMMENT = 'Supplier replenishment lead time in calendar days'
)
DIMENSIONS(
    sl.sku AS SKU
    , sl.location_id AS LOCATION_ID
    , sl.snapshot_date AS SNAPSHOT_DATE
    , loc.location_name AS LOCATION_NAME WITH SYNONYMS = ('site', 'warehouse')
    , loc.location_type AS LOCATION_TYPE COMMENT = 'Valid values: WAREHOUSE, STORE, FULFILLMENT_CENTER'
    , loc.region AS REGION
        WITH SYNONYMS = ('area', 'geography')
        COMMENT = 'Valid values: NORTHEAST, MIDWEST, WEST, PACIFIC'
    , loc.address AS ADDRESS
    , prod.product_name AS PRODUCT_NAME WITH SYNONYMS = ('item name', 'product')
    , prod.category AS CATEGORY WITH SYNONYMS = ('product category', 'type')
    , prod.subcategory AS SUBCATEGORY
)
METRICS(
    total_on_hand AS SUM(sl.QUANTITY_ON_HAND) COMMENT = 'Total units on hand'
    , total_reserved AS SUM(sl.QUANTITY_RESERVED) COMMENT = 'Total reserved units'
    , total_available AS SUM(sl.QUANTITY_ON_HAND - sl.QUANTITY_RESERVED)
        COMMENT = 'Total available units (on hand minus reserved)'
)
