{{ config(materialized='semantic_view') }}
TABLES(
    pc AS {{ source('finance', 'PRODUCT_COSTS') }} PRIMARY KEY (SKU, CHANNEL)
        COMMENT = 'Product costs, margins, and liquidation values by channel'
    , sc AS {{ source('finance', 'SHIPPING_COSTS') }} PRIMARY KEY (ORIGIN_LOCATION_ID, DESTINATION_LOCATION_ID)
        COMMENT = 'Inter-location shipping costs and transit times. Independent of product_costs — no cross-table joins.'
)
FACTS(
    pc.cogs AS COGS COMMENT = 'Cost of goods sold per unit'
    , pc.selling_price AS SELLING_PRICE COMMENT = 'Selling price per unit in this channel'
    , pc.liquidation_value AS LIQUIDATION_VALUE
        COMMENT = 'Recovery value if item is liquidated'
    , sc.cost_per_unit AS COST_PER_UNIT COMMENT = 'Flat shipping cost per unit'
    , sc.cost_per_kg AS COST_PER_KG COMMENT = 'Weight-based cost per kg'
    , sc.transit_days AS TRANSIT_DAYS COMMENT = 'Days for shipment to arrive'
)
DIMENSIONS(
    pc.sku AS SKU WITH SYNONYMS = ('product', 'item')
    , pc.channel AS CHANNEL
        WITH SYNONYMS = ('sales channel')
        COMMENT = 'Valid values: Online, In-Store, Wholesale'
    , pc.gross_margin AS GROSS_MARGIN
        COMMENT = 'Pre-computed ratio: (selling_price - COGS) / selling_price. Use as a filter or group-by, not for summation.'
    , sc.origin_location_id AS ORIGIN_LOCATION_ID
        WITH SYNONYMS = ('from location', 'source')
    , sc.destination_location_id AS DESTINATION_LOCATION_ID
        WITH SYNONYMS = ('to location', 'target')
    , sc.carrier AS CARRIER WITH SYNONYMS = ('shipping carrier', 'shipper')
)
METRICS(
    avg_cogs AS AVG(pc.COGS) COMMENT = 'Average cost of goods sold'
    , avg_selling_price AS AVG(pc.SELLING_PRICE) COMMENT = 'Average selling price'
    , avg_liquidation_value AS AVG(pc.LIQUIDATION_VALUE) COMMENT = 'Average liquidation recovery value'
    , avg_shipping_cost_per_unit AS AVG(sc.COST_PER_UNIT) COMMENT = 'Average flat shipping cost per unit'
    , avg_transit_days AS AVG(sc.TRANSIT_DAYS) COMMENT = 'Average transit days across routes'
)
