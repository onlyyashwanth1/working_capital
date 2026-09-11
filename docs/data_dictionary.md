# Data Dictionary — Working Capital Analytics Project

## AR (Accounts Receivable) — money customers owe us

**customers**
| Column | Meaning |
|---|---|
| customer_id | Unique ID for one customer |
| customer_name | Business name |
| region | East/West/North/South |
| credit_terms | Days allowed before payment is due |

**invoices**
| Column | Meaning |
|---|---|
| invoice_id | Unique ID for one bill sent to a customer |
| customer_id | Links to customers |
| invoice_date | Date billed |
| invoice_amount | Amount billed (₹) |
| due_date | invoice_date + customer's credit_terms |

**payments**
| Column | Meaning |
|---|---|
| payment_id | Unique ID for one payment received |
| invoice_id | Links to invoices |
| payment_date | Date payment came in |
| amount_paid | Amount received (may be partial) |
| method | NEFT / Cheque / UPI / Card |

## Inventory — what we have in stock

**products**
| Column | Meaning |
|---|---|
| product_id | Unique product code |
| product_name | Name |
| category | Product category |
| unit_cost | Cost to acquire one unit |
| unit_price | Price we sell one unit for |

**inventory_movements**
| Column | Meaning |
|---|---|
| movement_id | Unique ID for one stock event |
| product_id | Links to products |
| movement_date | When it happened |
| movement_type | RECEIPT (in) or ISSUE (out/sold) |
| quantity | Units moved |
| unit_cost | Cost per unit at the time |

*Current stock is not stored directly — it's calculated as SUM(RECEIPT qty) − SUM(ISSUE qty).*

## AP (Accounts Payable) — money we owe suppliers

**suppliers**
| Column | Meaning |
|---|---|
| supplier_id | Unique vendor ID |
| supplier_name | Name |
| pay_terms | Days we're allowed before paying them |

**purchase_orders**
| Column | Meaning |
|---|---|
| po_id | Unique ID for one order placed |
| supplier_id | Links to suppliers |
| order_date | Date order placed |
| due_date | Date payment is due |
| total_amount | Total order value |

**po_line_items**
| Column | Meaning |
|---|---|
| po_id / line_id | Which order, which line |
| product_id | Links to products |
| quantity, unit_cost | Units ordered, cost per unit |

**supplier_payments**
| Column | Meaning |
|---|---|
| supplier_payment_id | Unique ID for one payment made |
| po_id | Links to purchase_orders |
| payment_date, amount_paid | When and how much we paid |