USE wc_project;

-- ============================================================
-- PHASE 1: DATA QUALITY CHECKS (Accounts Receivable)
-- ============================================================

-- Check 1: Orphan payments (payment references an invoice_id that doesn't exist)
SELECT p.payment_id, p.invoice_id, p.amount_paid
FROM payments p
LEFT JOIN invoices i ON p.invoice_id = i.invoice_id
WHERE i.invoice_id IS NULL;

-- Check 2: Duplicate invoices (same customer, amount, date)
SELECT customer_id, invoice_amount, invoice_date, COUNT(*) AS count_dup
FROM invoices
GROUP BY customer_id, invoice_amount, invoice_date
HAVING COUNT(*) > 1;

-- Check 3: Missing due dates
SELECT COUNT(*) AS missing_due_dates
FROM invoices
WHERE due_date IS NULL;

-- Check 4: Negative invoice amounts (data entry errors)
SELECT invoice_id, customer_id, invoice_amount
FROM invoices
WHERE invoice_amount < 0;

-- Check 5: Payment dated before invoice date (impossible / logic error)
SELECT p.payment_id, p.invoice_id, i.invoice_date, p.payment_date
FROM payments p
JOIN invoices i ON p.invoice_id = i.invoice_id
WHERE p.payment_date < i.invoice_date;