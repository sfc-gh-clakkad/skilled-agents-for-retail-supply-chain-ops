{{ config(materialized='table', description='Daily pre-aggregated return rates by SKU, channel, and location') }}
SELECT
    cr.SKU,
    cr.RETURN_CHANNEL AS SALE_CHANNEL,
    cr.RECEIVING_LOCATION_ID,
    CURRENT_DATE() as AGGREGATION_DT,
    SUM(ol.QUANTITY) AS UNITS_SOLD,
    SUM(cr.QUANTITY_RETURNED) AS UNITS_RETURNED,
    (units_returned/units_sold) as RETURN_RATE
FROM {{ source('orders', 'CUSTOMER_RETURNS') }} cr 
LEFT OUTER JOIN {{ source('orders', 'ORDER_LINES') }} ol 
ON (
    lower(trim(cr.sku)) = lower(trim(ol.sku))
    AND
    cr.order_id = ol.order_id
)
GROUP BY cr.SKU, SALE_CHANNEL, RECEIVING_LOCATION_ID, AGGREGATION_DT