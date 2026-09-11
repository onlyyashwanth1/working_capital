USE wc_project;

-- Current stock per product = total received - total issued
SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.unit_cost,
    SUM(CASE WHEN m.movement_type = 'RECEIPT' THEN m.quantity ELSE 0 END) AS total_received,
    SUM(CASE WHEN m.movement_type = 'ISSUE' THEN m.quantity ELSE 0 END) AS total_issued,
    SUM(CASE WHEN m.movement_type = 'RECEIPT' THEN m.quantity ELSE -m.quantity END) AS current_stock
FROM inventory_movements m
JOIN products p ON p.product_id = m.product_id
GROUP BY p.product_id, p.product_name, p.category, p.unit_cost
ORDER BY current_stock DESC
LIMIT 15;

-- ============================================================
-- PHASE 2: Inventory Analysis (DIO)
-- ============================================================

-- 05.1: Stock value per product (top 15) — for a "Top Inventory Value" chart
WITH stock AS (
    SELECT p.product_id, p.product_name, p.category, p.unit_cost,
        SUM(CASE WHEN m.movement_type='RECEIPT' THEN m.quantity ELSE -m.quantity END) AS current_stock
    FROM inventory_movements m
    JOIN products p ON p.product_id = m.product_id
    GROUP BY p.product_id, p.product_name, p.category, p.unit_cost
)
SELECT product_id, product_name, category, current_stock, unit_cost,
    ROUND(current_stock * unit_cost, 2) AS stock_value
FROM stock
WHERE current_stock > 0
ORDER BY stock_value DESC
LIMIT 15;

-- 05.2: DIO calculation — the core metric
SELECT
    (SELECT SUM(current_stock * unit_cost) FROM (
        SELECT p.unit_cost,
            SUM(CASE WHEN m.movement_type='RECEIPT' THEN m.quantity ELSE -m.quantity END) AS current_stock
        FROM inventory_movements m JOIN products p ON p.product_id = m.product_id
        GROUP BY p.product_id, p.unit_cost
    ) s WHERE current_stock > 0) AS current_inventory_value,
    (SELECT SUM(m.quantity * p.unit_cost) FROM inventory_movements m JOIN products p ON p.product_id = m.product_id
        WHERE m.movement_type='ISSUE' AND m.movement_date >= DATE_SUB(CURDATE(), INTERVAL 365 DAY)) AS cogs_last_365,
    ROUND(
        (SELECT SUM(current_stock * unit_cost) FROM (
            SELECT p.unit_cost,
                SUM(CASE WHEN m.movement_type='RECEIPT' THEN m.quantity ELSE -m.quantity END) AS current_stock
            FROM inventory_movements m JOIN products p ON p.product_id = m.product_id
            GROUP BY p.product_id, p.unit_cost
        ) s WHERE current_stock > 0)
        /
        (SELECT SUM(m.quantity * p.unit_cost) FROM inventory_movements m JOIN products p ON p.product_id = m.product_id
            WHERE m.movement_type='ISSUE' AND m.movement_date >= DATE_SUB(CURDATE(), INTERVAL 365 DAY))
        * 365, 1
    ) AS DIO_days;

-- 05.3: Inventory value by category (Textiles concentration check)
WITH stock AS (
    SELECT p.product_id, p.category, p.unit_cost,
        SUM(CASE WHEN m.movement_type='RECEIPT' THEN m.quantity ELSE -m.quantity END) AS current_stock
    FROM inventory_movements m
    JOIN products p ON p.product_id = m.product_id
    GROUP BY p.product_id, p.category, p.unit_cost
)
SELECT category,
    ROUND(SUM(current_stock * unit_cost), 2) AS category_stock_value,
    ROUND(SUM(current_stock * unit_cost) * 100.0 / SUM(SUM(current_stock * unit_cost)) OVER (), 1) AS pct_of_total
FROM stock
WHERE current_stock > 0
GROUP BY category
ORDER BY category_stock_value DESC;

-- 05.4: Dead stock — in stock, zero sales in last 90 days
WITH stock AS (
    SELECT p.product_id, p.product_name, p.category, p.unit_cost,
        SUM(CASE WHEN m.movement_type='RECEIPT' THEN m.quantity ELSE -m.quantity END) AS current_stock
    FROM inventory_movements m
    JOIN products p ON p.product_id = m.product_id
    GROUP BY p.product_id, p.product_name, p.category, p.unit_cost
),
recent_sales AS (
    SELECT product_id, SUM(quantity) AS units_sold_last_90d
    FROM inventory_movements
    WHERE movement_type = 'ISSUE' AND movement_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
    GROUP BY product_id
)
SELECT s.product_id, s.product_name, s.category, s.current_stock,
    ROUND(s.current_stock * s.unit_cost, 2) AS stock_value
FROM stock s
LEFT JOIN recent_sales r ON r.product_id = s.product_id
WHERE s.current_stock > 0 AND COALESCE(r.units_sold_last_90d, 0) = 0
ORDER BY stock_value DESC;

-- 05.5: Slow movers — high stock value, low recent sales (reorder-freeze candidates)
WITH stock AS (
    SELECT p.product_id, p.product_name, p.category, p.unit_cost,
        SUM(CASE WHEN m.movement_type='RECEIPT' THEN m.quantity ELSE -m.quantity END) AS current_stock
    FROM inventory_movements m
    JOIN products p ON p.product_id = m.product_id
    GROUP BY p.product_id, p.product_name, p.category, p.unit_cost
),
recent_sales AS (
    SELECT product_id, SUM(quantity) AS units_sold_last_90d
    FROM inventory_movements
    WHERE movement_type = 'ISSUE' AND movement_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
    GROUP BY product_id
)
SELECT s.product_id, s.product_name, s.category, s.current_stock,
    ROUND(s.current_stock * s.unit_cost, 2) AS stock_value,
    COALESCE(r.units_sold_last_90d, 0) AS sold_last_90d
FROM stock s
LEFT JOIN recent_sales r ON r.product_id = s.product_id
WHERE s.current_stock > 0 AND COALESCE(r.units_sold_last_90d, 0) > 0
ORDER BY stock_value DESC, sold_last_90d ASC
LIMIT 10;