USE wc_project;

-- ============================================================
-- PHASE 3: DATA QUALITY CHECK (Accounts Payable)
-- ============================================================

-- Any supplier payments referencing a PO that doesn't exist?
SELECT sp.supplier_payment_id, sp.po_id, sp.amount_paid
FROM supplier_payments sp
LEFT JOIN purchase_orders po ON sp.po_id = po.po_id
WHERE po.po_id IS NULL;