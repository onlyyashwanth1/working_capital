# Data Quality Report

## Issues Found & Resolution

| Issue | Table | Count | Resolution |
|---|---|---|---|
| Orphan payments (no matching invoice) | payments | 361 | Excluded from reconciliation (v_payments_clean) |
| Duplicate invoices | invoices | 179 groups | Kept first occurrence only (v_invoices_clean) |
| Missing due dates | invoices | 122 | Filled from customer's credit_terms |
| Negative invoice amounts | invoices | 61 | Excluded from reconciliation |
| Payment before invoice date | payments | 105 | Excluded from reconciliation |
| Name collisions (distinct entities sharing a display name) | customers, suppliers | 2 confirmed cases | Disaggregated by ID, not name (see below) |

## Approach
All cleaning done via SQL views (`v_invoices_clean`, `v_payments_clean`) —
raw tables are never modified, so the original data and cleaning logic
are both fully auditable.

## Name Collision Discovery
Found during Power BI dashboard validation, not part of the original
5 injected anomaly types above. Multiple distinct `customer_id` /
`supplier_id` records shared the exact same display name:

- **"Pooja Group"** — 4 distinct `customer_id`s. Any query grouping
  by name alone silently merges them, inflating the true top customer's
  balance. Correct top single entity: customer_id 892, ₹121,860 outstanding.
- **"Divya Materials"** — 4 distinct `supplier_id`s. Same issue.
  Correct top single entity: supplier_id 45, ₹454,128 outstanding.

**Fix:** all customer/supplier-level queries and Power BI visuals now
group and display by ID (or an ID-qualified label, e.g. "Pooja Group
(ID 892)"), not name alone. Two SQL queries were updated after the
original analysis (top customer outstanding, top supplier outstanding)
to add `customer_id` / `supplier_id` to their `GROUP BY` clauses.

This was not an injected anomaly — it's a byproduct of the synthetic
data generator reusing names across different IDs — but it's a
realistic class of data quality bug (same issue occurs with real-world
company name variants, e.g. "Divya Materials Pvt Ltd" vs "Divya
Materials") and was caught only because dashboard totals didn't match
expectations during validation, not because it was anticipated upfront.

## Assumptions
- Data is synthetic, generated for this project (see scripts/generate_data.py)
- "Clean" invoice = single occurrence, positive amount, valid due_date
- "Clean" payment = matches an existing invoice, dated on/after invoice_date