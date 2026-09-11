USE wc_project;

-- ============================================================
-- METRIC: DPO (Days Payable Outstanding)
-- Answers: "On average, how many days do we take to pay suppliers
-- after placing an order?" Higher = we hold cash longer = good,
-- unless it damages supplier relationships.
-- ============================================================

WITH payment_totals AS (
    SELECT po_id, SUM(amount_paid) AS total_paid
    FROM supplier_payments
    GROUP BY po_id
),
period_pos AS (
    -- last 12 months of purchase orders only
    SELECT po.*, COALESCE(pt.total_paid, 0) AS paid
    FROM purchase_orders po
    LEFT JOIN payment_totals pt ON pt.po_id = po.po_id
    WHERE po.order_date >= DATE_SUB(CURDATE(), INTERVAL 365 DAY)
)
SELECT
    ROUND(SUM(total_amount - paid), 2) AS total_payable_outstanding,
    ROUND(SUM(total_amount), 2) AS total_purchased,
    ROUND((SUM(total_amount - paid) / SUM(total_amount)) * 365, 1) AS DPO_days  -- (outstanding/purchased) x 365
FROM period_pos;


USE wc_project;

-- Weighted avg supplier pay_terms, to compare against actual DPO
SELECT
    ROUND(AVG(s.pay_terms), 1) AS simple_avg_pay_terms,
    ROUND(SUM(po.total_amount * s.pay_terms) / SUM(po.total_amount), 1) AS weighted_avg_pay_terms
FROM purchase_orders po
JOIN suppliers s ON s.supplier_id = po.supplier_id;


USE wc_project;

-- Which suppliers are we most indebted to right now?
SELECT
    s.supplier_id,
    s.supplier_name,
    ROUND(SUM(po.total_amount - COALESCE(pt.total_paid, 0)), 2) AS outstanding_payable
FROM purchase_orders po
JOIN suppliers s ON s.supplier_id = po.supplier_id
LEFT JOIN payment_totals pt ON pt.po_id = po.po_id
GROUP BY s.supplier_id, s.supplier_name
HAVING outstanding_payable > 0
ORDER BY outstanding_payable DESC
LIMIT 15;
USE wc_project;

-- Which POs are overdue for payment, and by how much?
WITH payment_totals AS (
    SELECT po_id, SUM(amount_paid) AS total_paid
    FROM supplier_payments
    GROUP BY po_id
)
SELECT
    CASE
        WHEN DATEDIFF(CURDATE(), po.due_date) <= 0 THEN 'Not yet due'
        WHEN DATEDIFF(CURDATE(), po.due_date) BETWEEN 1 AND 30 THEN '1-30 days overdue'
        WHEN DATEDIFF(CURDATE(), po.due_date) BETWEEN 31 AND 60 THEN '31-60 days overdue'
        ELSE '60+ days overdue'
    END AS aging_bucket,
    COUNT(*) AS num_pos,
    ROUND(SUM(po.total_amount - COALESCE(pt.total_paid, 0)), 2) AS total_outstanding
FROM purchase_orders po
LEFT JOIN payment_totals pt ON pt.po_id = po.po_id
WHERE (po.total_amount - COALESCE(pt.total_paid, 0)) > 0.01
GROUP BY aging_bucket
ORDER BY FIELD(aging_bucket, 'Not yet due','1-30 days overdue','31-60 days overdue','60+ days overdue');

USE wc_project;

-- What % of total purchasing depends on our top 5 suppliers?
WITH supplier_totals AS (
    SELECT s.supplier_name, SUM(po.total_amount) AS total_purchased
    FROM purchase_orders po
    JOIN suppliers s ON s.supplier_id = po.supplier_id
    GROUP BY s.supplier_name
),
ranked AS (
    SELECT *, RANK() OVER (ORDER BY total_purchased DESC) AS rnk
    FROM supplier_totals
)
SELECT
    SUM(CASE WHEN rnk <= 5 THEN total_purchased ELSE 0 END) AS top5_supplier_spend,
    SUM(total_purchased) AS total_spend,
    ROUND(SUM(CASE WHEN rnk <= 5 THEN total_purchased ELSE 0 END) / SUM(total_purchased) * 100, 1) AS top5_pct_of_total
FROM ranked;