USE wc_project;

-- ============================================================
-- RECONCILIATION: invoice vs payment totals (on CLEAN data)
-- Classifies every invoice as UNPAID / PARTIAL / BALANCED / OVERPAID
-- ============================================================
WITH payment_totals AS (
    SELECT invoice_id, ROUND(SUM(amount_paid), 2) AS total_paid
    FROM v_payments_clean
    GROUP BY invoice_id
),
reconciliation AS (
    SELECT
        i.invoice_id,
        i.customer_id,
        i.invoice_date,
        i.due_date,
        i.invoice_amount AS invoiced,
        COALESCE(pt.total_paid, 0) AS paid,
        i.invoice_amount - COALESCE(pt.total_paid, 0) AS balance,
        CASE
            WHEN pt.total_paid IS NULL THEN 'UNPAID'
            WHEN ABS(i.invoice_amount - pt.total_paid) < 0.01 THEN 'BALANCED'
            WHEN pt.total_paid > i.invoice_amount THEN 'OVERPAID'
            ELSE 'PARTIAL'
        END AS status
    FROM v_invoices_clean i
    LEFT JOIN payment_totals pt ON pt.invoice_id = i.invoice_id
)
SELECT status, COUNT(*) AS num_invoices, ROUND(SUM(balance), 2) AS total_balance
FROM reconciliation
GROUP BY status
ORDER BY total_balance DESC;


-- ============================================================
-- CUSTOMER-LEVEL OUTSTANDING: who owes the most
-- ============================================================
SELECT
    c.customer_id,
    c.customer_name,
    c.region,
    ROUND(SUM(i.invoice_amount - COALESCE(pt.total_paid, 0)), 2) AS outstanding
FROM v_invoices_clean i
JOIN customers c ON c.customer_id = i.customer_id
LEFT JOIN payment_totals pt ON pt.invoice_id = i.invoice_id
GROUP BY c.customer_id, c.customer_name, c.region
HAVING outstanding > 0
ORDER BY outstanding DESC
LIMIT 15;
-- ============================================================
-- AGING: how overdue are the unpaid/partial invoices
-- ============================================================
WITH payment_totals AS (
    SELECT invoice_id, SUM(amount_paid) AS total_paid
    FROM v_payments_clean
    GROUP BY invoice_id
)
SELECT
    CASE
        WHEN DATEDIFF(CURDATE(), i.due_date) <= 0 THEN 'Not yet due'
        WHEN DATEDIFF(CURDATE(), i.due_date) BETWEEN 1 AND 30 THEN '1-30 days overdue'
        WHEN DATEDIFF(CURDATE(), i.due_date) BETWEEN 31 AND 60 THEN '31-60 days overdue'
        WHEN DATEDIFF(CURDATE(), i.due_date) BETWEEN 61 AND 90 THEN '61-90 days overdue'
        ELSE '90+ days overdue'
    END AS aging_bucket,
    COUNT(*) AS num_invoices,
    ROUND(SUM(i.invoice_amount - COALESCE(pt.total_paid, 0)), 2) AS total_outstanding
FROM v_invoices_clean i
LEFT JOIN payment_totals pt ON pt.invoice_id = i.invoice_id
WHERE (i.invoice_amount - COALESCE(pt.total_paid, 0)) > 0.01
GROUP BY aging_bucket
ORDER BY FIELD(aging_bucket, 'Not yet due','1-30 days overdue','31-60 days overdue','61-90 days overdue','90+ days overdue');

USE wc_project;

-- ============================================================
-- METRIC: DSO (Days Sales Outstanding)
-- Answers: "On average, how many days does it take us to
-- actually collect cash after we bill a customer?"
-- Lower = faster collections = healthier cash flow.
-- ============================================================

WITH payment_totals AS (
    -- Total amount actually paid, per invoice (from the cleaned payments view)
    SELECT invoice_id, SUM(amount_paid) AS total_paid
    FROM v_payments_clean
    GROUP BY invoice_id
),
period_invoices AS (
    -- Only look at invoices from the last 365 days, so DSO reflects
    -- recent business activity, not the entire dataset's history
    SELECT i.*, COALESCE(pt.total_paid, 0) AS paid
    FROM v_invoices_clean i
    LEFT JOIN payment_totals pt ON pt.invoice_id = i.invoice_id
    WHERE i.invoice_date >= DATE_SUB(CURDATE(), INTERVAL 365 DAY)
)
SELECT
    -- Total ₹ still uncollected in the last year
    ROUND(SUM(invoice_amount - paid), 2) AS total_outstanding,

    -- Total ₹ billed to customers in the last year
    ROUND(SUM(invoice_amount), 2) AS total_invoiced_last_365_days,

    -- DSO formula: (Outstanding / Total Invoiced) x Number of Days in period
    -- This tells us, on average, how many days' worth of sales are
    -- still sitting uncollected right now
    ROUND( (SUM(invoice_amount - paid) / SUM(invoice_amount)) * 365, 1) AS DSO_days
FROM period_invoices;

USE wc_project;

-- ============================================================
-- METRIC: Cash impact of improving DSO
-- Answers the CFO question: "If we collect 10 days faster,
-- how much actual cash does that free up?"
-- ============================================================

WITH payment_totals AS (
    SELECT invoice_id, SUM(amount_paid) AS total_paid
    FROM v_payments_clean
    GROUP BY invoice_id
),
period_invoices AS (
    SELECT i.*, COALESCE(pt.total_paid, 0) AS paid
    FROM v_invoices_clean i
    LEFT JOIN payment_totals pt ON pt.invoice_id = i.invoice_id
    WHERE i.invoice_date >= DATE_SUB(CURDATE(), INTERVAL 365 DAY)
)
SELECT
    -- Average revenue billed per single day (total invoiced / 365)
    ROUND(SUM(invoice_amount) / 365, 2) AS revenue_per_day,

    -- Current DSO, same formula as above
    ROUND( (SUM(invoice_amount - paid) / SUM(invoice_amount)) * 365, 1) AS current_DSO,

    -- If DSO drops by 10 days, that many days' worth of revenue
    -- converts from "outstanding" to "cash in hand"
    ROUND( (SUM(invoice_amount) / 365) * 10, 2) AS cash_freed_if_DSO_improves_by_10_days
FROM period_invoices;