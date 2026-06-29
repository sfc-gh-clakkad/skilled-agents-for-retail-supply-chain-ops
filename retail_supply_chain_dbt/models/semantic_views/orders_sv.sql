{{ config(materialized='semantic_view') }}
TABLES(
    df AS {{ source('orders', 'DEMAND_FORECAST') }} PRIMARY KEY (FORECAST_ID)
        COMMENT = 'Forward-looking demand forecasts by SKU and location. Queried independently; no direct join to order/return tables.'
    , oh AS {{ source('orders', 'ORDER_HEADERS') }} PRIMARY KEY (ORDER_ID)
        COMMENT = 'Order-level data with status and channel'
    , ol AS {{ source('orders', 'ORDER_LINES') }} PRIMARY KEY (ORDER_LINE_ID)
        COMMENT = 'Line-item detail for orders'
    , cr AS {{ source('orders', 'CUSTOMER_RETURNS') }} PRIMARY KEY (RETURN_ID)
        COMMENT = 'Individual return records with condition and eligibility'
    , drr AS {{ ref('daily_return_rates_by_sku_channel') }} PRIMARY KEY (SKU, SALE_CHANNEL, RECEIVING_LOCATION_ID, AGGREGATION_DT)
        COMMENT = 'Daily pre-aggregated return rates by SKU, channel, and location. Use for return inflow volume and rate analysis.'
)
RELATIONSHIPS(
    lines_to_header AS ol (ORDER_ID) REFERENCES oh (ORDER_ID)
    , returns_to_header AS cr (ORDER_ID) REFERENCES oh (ORDER_ID)
)
FACTS(
    df.forecasted_units AS FORECASTED_UNITS COMMENT = 'Predicted demand units'
    , df.confidence_level AS CONFIDENCE_LEVEL COMMENT = 'Forecast confidence (0-1)'
    , oh.total_amount AS TOTAL_AMOUNT COMMENT = 'Order total in USD'
    , ol.quantity AS QUANTITY COMMENT = 'Line item quantity'
    , ol.unit_price AS UNIT_PRICE COMMENT = 'Price per unit'
    , ol.line_total AS LINE_TOTAL COMMENT = 'Line total (qty * price)'
    , cr.quantity_returned AS QUANTITY_RETURNED COMMENT = 'Units returned in this record'
    , drr.DRR_UNITS_SOLD AS drr.units_sold COMMENT = 'Total units sold for the SKU/channel/location on the aggregation date'
    , drr.DRR_UNITS_RETURNED AS drr.units_returned COMMENT = 'Total units returned (inflow) for the SKU/channel/location on the aggregation date'
    , drr.DRR_RETURN_RATE AS drr.return_rate COMMENT = 'Return rate ratio (units_returned / units_sold)'
)
DIMENSIONS(
    df.forecast_id AS FORECAST_ID
    , df.FORECAST_SKU AS df.sku WITH SYNONYMS = ('forecasted product', 'forecast item')
    , df.FORECAST_LOCATION_ID AS df.location_id WITH SYNONYMS = ('forecast location')
    , df.forecast_date AS FORECAST_DATE
    , df.model_version AS MODEL_VERSION
    , oh.order_id AS ORDER_ID
    , oh.customer_id AS CUSTOMER_ID
    , oh.order_date AS ORDER_DATE
    , oh.order_status AS ORDER_STATUS
        COMMENT = 'Valid values: Pending, Processing, Shipped, Delivered, Cancelled'
    , oh.sales_channel AS SALES_CHANNEL
        WITH SYNONYMS = ('channel', 'sale channel')
        COMMENT = 'Valid values: Online, In-Store, Wholesale'
    , oh.fulfillment_location_id AS FULFILLMENT_LOCATION_ID
    , oh.shipping_method AS SHIPPING_METHOD
    , ol.order_line_id AS ORDER_LINE_ID
    , ol.sku AS SKU WITH SYNONYMS = ('product', 'item')
    , ol.line_status AS LINE_STATUS
        COMMENT = 'Valid values: Pending, Fulfilled, Backordered, Cancelled'
    , cr.return_id AS RETURN_ID
    , cr.RETURN_SKU AS cr.sku WITH SYNONYMS = ('returned product', 'returned item')
    , cr.return_reason AS RETURN_REASON
        COMMENT = 'Valid values: DEFECTIVE, WRONG_SIZE, CHANGED_MIND, DAMAGED_IN_TRANSIT'
    , cr.return_channel AS RETURN_CHANNEL
        COMMENT = 'Valid values: ONLINE, IN_STORE, MAIL'
    , cr.original_sale_channel AS ORIGINAL_SALE_CHANNEL
        COMMENT = 'Valid values: ONLINE, IN_STORE'
    , cr.receiving_location_id AS RECEIVING_LOCATION_ID
        WITH SYNONYMS = ('return location', 'receiving site')
    , cr.item_condition AS ITEM_CONDITION
        COMMENT = 'Valid values: NEW, LIKE_NEW, DAMAGED, DEFECTIVE'
    , cr.return_initiated_date AS RETURN_INITIATED_DATE
    , cr.return_received_date AS RETURN_RECEIVED_DATE
    , drr.sku AS SKU
        WITH SYNONYMS = ('return rate product')
    , drr.sale_channel AS SALE_CHANNEL
        COMMENT = 'Channel for aggregated return rate calculation'
    , drr.receiving_location_id AS RECEIVING_LOCATION_ID
        WITH SYNONYMS = ('return inflow location')
    , drr.aggregation_dt AS AGGREGATION_DT
        COMMENT = 'Date of the aggregated return rate snapshot'
)
METRICS(
    total_forecasted_units AS SUM(df.FORECASTED_UNITS)
        COMMENT = 'Total forecasted demand units'
    , weighted_demand AS SUM(df.FORECASTED_UNITS * df.CONFIDENCE_LEVEL)
        COMMENT = 'Confidence-weighted demand forecast'
    , avg_confidence AS AVG(df.CONFIDENCE_LEVEL)
        COMMENT = 'Average forecast confidence level'
    , total_order_amount AS SUM(oh.TOTAL_AMOUNT) COMMENT = 'Sum of order amounts'
    , order_count AS COUNT(DISTINCT oh.ORDER_ID) COMMENT = 'Count of distinct orders'
    , total_line_quantity AS SUM(ol.QUANTITY) COMMENT = 'Total line item quantity'
    , total_line_revenue AS SUM(ol.LINE_TOTAL) COMMENT = 'Total revenue from line items'
    , total_returns AS COUNT(cr.RETURN_ID) COMMENT = 'Total number of return records'
    , total_units_returned AS SUM(cr.QUANTITY_RETURNED) COMMENT = 'Total units returned'
    , avg_processing_days AS AVG(DATEDIFF('day', cr.RETURN_INITIATED_DATE, cr.RETURN_RECEIVED_DATE))
        COMMENT = 'Average days between initiation and receipt'
    , pending_receipt_count AS COUNT_IF(cr.RETURN_RECEIVED_DATE IS NULL)
        COMMENT = 'Returns initiated but not yet received'
    , drr.current_return_inflow AS SUM(drr.UNITS_RETURNED)
        COMMENT = 'Current returned stock inflow volume per SKU from the daily aggregate. Use to identify SKUs with high return volumes.'
    , drr.avg_return_rate AS AVG(drr.RETURN_RATE)
        COMMENT = 'Average return rate across SKU/channel/location aggregations'
)
