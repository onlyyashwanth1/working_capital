USE wc_project;

-- ============================================================
-- CLEAN VIEW: invoices
-- Fixes: duplicates removed, missing due_date filled from
-- customer's credit_terms, negative amounts excluded.
-- ============================================================
CREATE OR REPLACE VIEW v_invoices_clean AS
WITH deduped AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY customer_id, invoice_amount, invoice_date
               ORDER BY invoice_id
           ) AS rn
    FROM invoices
)
SELECT
    d.invoice_id,
    d.customer_id,
    d.invoice_date,
    d.invoice_amount,
    COALESCE(d.due_date, DATE_ADD(d.invoice_date, INTERVAL c.credit_terms DAY)) AS due_date
FROM deduped d
JOIN customers c ON c.customer_id = d.customer_id
WHERE d.rn = 1                -- keep only the first copy of any duplicate
  AND d.invoice_amount > 0;   -- drop negative-amount errors

-- ============================================================
-- CLEAN VIEW: payments
-- Fixes: orphan payments excluded (inner join drops them),
-- payment-before-invoice-date errors excluded.
-- ============================================================
CREATE OR REPLACE VIEW v_payments_clean AS
SELECT p.*
FROM payments p
JOIN invoices i ON p.invoice_id = i.invoice_id
WHERE p.payment_date >= i.invoice_date;

SELECT COUNT(*) AS clean_invoice_count FROM v_invoices_clean;
SELECT COUNT(*) AS clean_payment_count FROM v_payments_clean;