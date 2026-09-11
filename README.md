# Working Capital Analytics Project

## What this project is

A data analyst portfolio project that looks at a company's working capital —
how fast it collects money from customers, how much cash is tied up in
inventory, and how it pays suppliers — and turns that into a Power BI
dashboard a business could actually use to free up cash.

The data is synthetic (generated for this project), but it's built to
behave like real business data: messy in places, with duplicates, missing
values, and errors mixed in on purpose, so the project also demonstrates
data cleaning, not just analysis.

## The business question

Three things determine how much cash a company has tied up at any moment:

1. **How long it takes to collect from customers** (Days Sales Outstanding — DSO)
2. **How long inventory sits before it's sold** (Days Inventory Outstanding — DIO)
3. **How long the company takes to pay its own suppliers** (Days Payable Outstanding — DPO)

Put together, these give the **Cash Conversion Cycle (CCC)**:

```
CCC = DSO + DIO − DPO
```

The lower the CCC, the less cash is stuck in the business and the more is
free to use. This project measures all three, finds out *why* they are
what they are, and estimates how much cash could be freed up by improving
each one.

## Data

Nine tables were generated (customers, products, suppliers, invoices,
payments, purchase orders, PO line items, supplier payments, and inventory
movements), loaded into a MySQL database.

To make the project realistic, a handful of data quality problems were
deliberately mixed in — things like duplicate invoices, payments with no
matching invoice, missing due dates, and payments dated before their
invoice. These are documented and cleaned up in
`docs/data_quality_report.md`, using SQL views (`v_invoices_clean`,
`v_payments_clean`) so the original raw data is never touched or lost —
only the cleaned *views* are used for analysis, and the cleaning logic
is fully visible and checkable.

A second, unplanned data quality issue was found later, while building
the dashboard: some customers and suppliers share the exact same display
name but are actually different accounts (different IDs). This is also
written up in the same report, and every relevant query and chart in the
project was corrected to group by ID rather than by name.

## What was analyzed

**Accounts Receivable (money owed to us by customers)**
- Reconciled every invoice against its payments (paid in full, partly
  paid, or unpaid)
- Measured how overdue the outstanding money is
- Calculated DSO and compared it to the credit terms customers were
  actually given, to see how much of the delay is our own execution gap
  versus the agreed terms

**Inventory**
- Calculated current stock and its value, product by product
- Found which product categories hold the most value
- Identified "dead stock" — products sitting in the warehouse with zero
  sales in the last 90 days
- Calculated DIO

**Accounts Payable (money we owe suppliers)**
- Same reconciliation approach as receivables, but for supplier payments
- Calculated DPO and compared it to suppliers' agreed payment terms
- Checked how concentrated our spending is across suppliers (risk of
  relying too heavily on a small number of them)

**Cash Conversion Cycle**
- Combined DSO, DIO, and DPO into one CCC figure
- Modeled how much cash could be freed if each metric improved by 10 days

## What was found

- **DSO is 67.2 days**, but customers are only given 36 days of credit on
  average — a 31-day gap between what we agreed to and what actually
  happens. Most of the overdue money (68%) is more than 90 days late.
- **DPO is 42.9 days**, against agreed supplier terms of about 38 days —
  a much smaller, healthier gap than the receivables side.
- **DIO is 33.6 days.** One category (Textiles) holds the largest share
  of inventory value, but a *different* category (Furniture) has the
  highest share of *dead stock* relative to its own value. These are two
  separate problems that would be missed if you only looked at total
  value.
- **CCC is 57.9 days.** If all three metrics improved by 10 days each,
  CCC would drop to **27.9 days — a 52% reduction** — and free up
  roughly ₹53–57 lakh in cash, based on the dashboard's live figures.
- Two customer/supplier names in the data ("Pooja Group" and "Divya
  Materials") turned out to represent multiple separate accounts. Early
  analysis that grouped by name only had overstated their totals; this
  was caught and corrected during dashboard validation.

## The dashboard

Built in Power BI (`dashboard/wc_project.pbix`), with four pages:

1. **AR-Overview** — receivables story: how much is outstanding, how
   overdue it is, DSO vs. credit terms, and who owes the most
2. **AP-Overview** — same structure for payables: DPO vs. supplier
   terms, and who we owe the most
3. **Inventory-Overview** — inventory value by category, a stock health
   view (value vs. recent sales), slow movers, dead stock, and the
   Furniture-vs-Textiles risk finding
4. **CCC Summary** — brings DSO, DIO, and DPO together into one CCC
   figure, compares it to the 27.9-day achievable target, and includes
   an interactive slider to see live how much cash is freed as
   collection speed (DSO) improves

## Project structure

```
data/        9 generated CSVs
scripts/     generate_data.py, load_to_mysql.py
sql/schema/  create_tables.sql
sql/queries/ numbered .sql files, one per phase/topic
docs/        data_dictionary.md, data_quality_report.md
dashboard/   wc_project.pbix (Power BI file)
```

## Tools used

MySQL (data storage, cleaning, and metric calculations in SQL), Python
with pandas/numpy (synthetic data generation), and Power BI (dashboard
and DAX measures).
