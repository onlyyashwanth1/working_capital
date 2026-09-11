USE wc_project;

-- ============================================================
-- PHASE 4: Cash Conversion Cycle (CCC = DSO + DIO - DPO)
-- Pulls the three metrics together into one summary
-- ============================================================

WITH ar AS (
    -- DSO calc, same logic as Phase 1
    SELECT (SUM(i.invoice_amount - COALESCE(pt.total_paid,0)) / SUM(i.invoice_amount)) * 365 AS DSO
    FROM v_invoices_clean i
    LEFT JOIN (SELECT invoice_id, SUM(amount_paid) total_paid FROM v_payments_clean GROUP BY invoice_id) pt
        ON pt.invoice_id = i.invoice_id
    WHERE i.invoice_date >= DATE_SUB(CURDATE(), INTERVAL 365 DAY)
),
inv AS (
    -- DIO calc, same logic as Phase 2
    SELECT
        (SELECT SUM(current_stock * unit_cost) FROM (
            SELECT p.unit_cost, SUM(CASE WHEN m.movement_type='RECEIPT' THEN m.quantity ELSE -m.quantity END) AS current_stock
            FROM inventory_movements m JOIN products p ON p.product_id = m.product_id
            GROUP BY p.product_id, p.unit_cost
        ) s WHERE current_stock > 0) / 
        (SELECT SUM(m.quantity * p.unit_cost) FROM inventory_movements m JOIN products p ON p.product_id = m.product_id
            WHERE m.movement_type='ISSUE' AND m.movement_date >= DATE_SUB(CURDATE(), INTERVAL 365 DAY))
        * 365 AS DIO
),
ap AS (
    -- DPO calc, same logic as Phase 3
    SELECT (SUM(po.total_amount - COALESCE(pt.total_paid,0)) / SUM(po.total_amount)) * 365 AS DPO
    FROM purchase_orders po
    LEFT JOIN (SELECT po_id, SUM(amount_paid) total_paid FROM supplier_payments GROUP BY po_id) pt
        ON pt.po_id = po.po_id
    WHERE po.order_date >= DATE_SUB(CURDATE(), INTERVAL 365 DAY)
)
SELECT
    ROUND(ar.DSO, 1) AS DSO_days,
    ROUND(inv.DIO, 1) AS DIO_days,
    ROUND(ap.DPO, 1) AS DPO_days,
    ROUND(ar.DSO + inv.DIO - ap.DPO, 1) AS CCC_days
FROM ar, inv, ap;



-- 08.1: Total cash opportunity across all 3 levers (10-day improvement each)
WITH ar AS (
    SELECT SUM(i.invoice_amount) / 365 AS revenue_per_day
    FROM v_invoices_clean i
    WHERE i.invoice_date >= DATE_SUB(CURDATE(), INTERVAL 365 DAY)
),
inv AS (
    SELECT (SELECT SUM(m.quantity * p.unit_cost) FROM inventory_movements m JOIN products p ON p.product_id = m.product_id
        WHERE m.movement_type='ISSUE' AND m.movement_date >= DATE_SUB(CURDATE(), INTERVAL 365 DAY)) / 365 AS cogs_per_day
),
ap AS (
    SELECT SUM(po.total_amount) / 365 AS spend_per_day
    FROM purchase_orders po
    WHERE po.order_date >= DATE_SUB(CURDATE(), INTERVAL 365 DAY)
)
SELECT
    ROUND(ar.revenue_per_day * 10, 2) AS dso_cash_freed,
    ROUND(inv.cogs_per_day * 10, 2) AS dio_cash_freed,
    ROUND(ap.spend_per_day * 10, 2) AS dpo_cash_retained,
    ROUND(ar.revenue_per_day * 10 + inv.cogs_per_day * 10 + ap.spend_per_day * 10, 2) AS total_opportunity
FROM ar, inv, ap;

-- 08.2: CCC target simulation (10-day improvement on each lever)
SELECT
    67.2 AS DSO_current, 67.2 - 10 AS DSO_target,
    33.6 AS DIO_current, 33.6 - 10 AS DIO_target,
    42.9 AS DPO_current, 42.9 + 10 AS DPO_target,
    ROUND((67.2 + 33.6 - 42.9), 1) AS CCC_current,
    ROUND((67.2-10) + (33.6-10) - (42.9+10), 1) AS CCC_target;