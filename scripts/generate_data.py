import numpy as np
import pandas as pd
import os

np.random.seed(42)

# Output folder (relative to project root)
OUTPUT_DIR = "../data"

# =================================================================
# PARAMETERS
# =================================================================
N_CUSTOMERS = 1000
N_INVOICES = 12000
N_PRODUCTS = 200
N_SUPPLIERS = 80
N_POS = 1500
DATE_START = "2025-09-01"
DATE_END = "2026-08-31"
invoice_dates = pd.date_range(DATE_START, DATE_END, freq="D")

# =================================================================
# 1. CUSTOMERS
# =================================================================
first_names = ["Rahul","Priya","Amit","Sneha","Vikram","Anita","Karan","Divya",
                "Rohan","Neha","Arjun","Pooja","Sanjay","Meera","Kunal","Ritu",
                "Manish","Swati","Deepak","Kavita"]
company_suffixes = ["Ltd","Corp","Traders","Industries","Enterprises","Group",
                     "Textiles","Exports","Logistics","Retail"]

customers = pd.DataFrame({
    "customer_id": range(1, N_CUSTOMERS + 1),
    "customer_name": [f"{np.random.choice(first_names)} {np.random.choice(company_suffixes)}" for _ in range(N_CUSTOMERS)],
    "region": np.random.choice(["East", "West", "North", "South"], N_CUSTOMERS),
    "credit_terms": np.random.choice([30, 45, 60], N_CUSTOMERS, p=[0.7, 0.2, 0.1])
})

# =================================================================
# 2. INVOICES
# =================================================================
invoices = pd.DataFrame({
    "invoice_id": range(1001, 1001 + N_INVOICES),
    "customer_id": np.random.choice(customers.customer_id, N_INVOICES),
    "invoice_date": np.random.choice(invoice_dates, N_INVOICES),
})
invoices["invoice_amount"] = np.random.lognormal(mean=np.log(5000), sigma=0.8, size=N_INVOICES).round(2)
invoices = invoices.merge(customers[["customer_id", "credit_terms"]], on="customer_id")
invoices["due_date"] = invoices["invoice_date"] + pd.to_timedelta(invoices["credit_terms"], unit="D")

# =================================================================
# 3. PAYMENTS (customer -> invoice payments)
# =================================================================
payments = []
pid = 1
for _, inv in invoices.iterrows():
    if np.random.rand() < 0.85:
        remaining = inv.invoice_amount
        n_installments = np.random.choice([1, 2], p=[0.75, 0.25])
        for k in range(n_installments):
            if remaining <= 0:
                break
            frac = np.random.uniform(0.4, 1.0) if k < n_installments - 1 else 1.0
            pay_amt = round(remaining * frac, 2) if k < n_installments - 1 else round(remaining, 2)
            delay = inv.credit_terms + np.random.normal(0, 15)
            pay_date = inv.invoice_date + pd.to_timedelta(max(delay, 1), unit="D")
            payments.append({"payment_id": pid, "invoice_id": inv.invoice_id, "payment_date": pay_date,
                              "amount_paid": pay_amt, "method": np.random.choice(["NEFT","Cheque","UPI","Card"])})
            pid += 1
            remaining -= pay_amt
            if np.random.rand() < 0.3:
                break
payments = pd.DataFrame(payments)

# =================================================================
# 4. AR ANOMALIES (duplicates, orphans, missing/negative/bad-date)
# =================================================================
dup_idx = invoices.sample(frac=0.015, random_state=1).index
dup_rows = invoices.loc[dup_idx].copy()
dup_rows["invoice_id"] = dup_rows["invoice_id"] + 900000
invoices = pd.concat([invoices, dup_rows], ignore_index=True)

n_orphans = int(len(payments) * 0.03)
orphan_payments = pd.DataFrame({
    "payment_id": range(pid, pid + n_orphans),
    "invoice_id": np.random.choice(range(500000, 500050), n_orphans),
    "payment_date": np.random.choice(invoice_dates, n_orphans),
    "amount_paid": np.random.uniform(500, 5000, n_orphans).round(2),
    "method": np.random.choice(["NEFT","Cheque","UPI","Card"], n_orphans)
})
payments = pd.concat([payments, orphan_payments], ignore_index=True)
pid += n_orphans

missing_idx = invoices.sample(frac=0.01, random_state=2).index
invoices.loc[missing_idx, "due_date"] = pd.NaT
neg_idx = invoices.sample(frac=0.005, random_state=3).index
invoices.loc[neg_idx, "invoice_amount"] = -invoices.loc[neg_idx, "invoice_amount"]
bad_date_idx = payments.sample(frac=0.01, random_state=4).index
payments.loc[bad_date_idx, "payment_date"] = payments.loc[bad_date_idx, "payment_date"] - pd.to_timedelta(60, unit="D")

# Clean up: drop leftover credit_terms column from invoices (belongs on customers, not here)
invoices = invoices.drop(columns=["credit_terms"])

# Normalize all payment dates to remove sub-second timestamp noise
payments["payment_date"] = pd.to_datetime(payments["payment_date"]).dt.normalize()

# =================================================================
# 5. PRODUCTS
# =================================================================
categories = ["Electronics","Textiles","Hardware","Packaging","Chemicals","Furniture"]
unit_cost = np.random.uniform(20, 500, N_PRODUCTS).round(2)
products = pd.DataFrame({
    "product_id": [f"P{1000+i}" for i in range(N_PRODUCTS)],
    "product_name": [f"Product_{i}" for i in range(N_PRODUCTS)],
    "category": np.random.choice(categories, N_PRODUCTS),
    "unit_cost": unit_cost,
    "unit_price": (unit_cost * np.random.uniform(1.2, 1.8, N_PRODUCTS)).round(2)
})

# =================================================================
# 6. SUPPLIERS
# =================================================================
suppliers = pd.DataFrame({
    "supplier_id": range(1, N_SUPPLIERS + 1),
    "supplier_name": [f"{np.random.choice(first_names)} {np.random.choice(['Suppliers','Vendors','Materials','Sourcing'])}" for _ in range(N_SUPPLIERS)],
    "pay_terms": np.random.choice([30, 45, 60], N_SUPPLIERS, p=[0.6, 0.25, 0.15])
})

# =================================================================
# 7. PURCHASE ORDERS + PO LINE ITEMS
# =================================================================
po_supplier_ids = np.random.choice(suppliers.supplier_id, N_POS)
po_order_dates = np.random.choice(invoice_dates, N_POS)
purchase_orders = pd.DataFrame({
    "po_id": range(1, N_POS + 1),
    "supplier_id": po_supplier_ids,
    "order_date": po_order_dates
}).merge(suppliers[["supplier_id","pay_terms"]], on="supplier_id")
purchase_orders["due_date"] = purchase_orders["order_date"] + pd.to_timedelta(purchase_orders["pay_terms"], unit="D")

po_line_items = []
line_id = 1
for _, po in purchase_orders.iterrows():
    n_lines = np.random.randint(1, 4)
    for _ in range(n_lines):
        prod = products.sample(1).iloc[0]
        qty = np.random.randint(10, 200)
        po_line_items.append({"po_id": po.po_id, "line_id": line_id, "product_id": prod.product_id,
                               "quantity": qty, "unit_cost": prod.unit_cost})
        line_id += 1
po_line_items = pd.DataFrame(po_line_items)

po_totals = po_line_items.assign(amount=po_line_items.quantity * po_line_items.unit_cost) \
                          .groupby("po_id")["amount"].sum().round(2)
purchase_orders["total_amount"] = purchase_orders["po_id"].map(po_totals).fillna(0)

# Clean up: drop leftover pay_terms column from purchase_orders
purchase_orders = purchase_orders.drop(columns=["pay_terms"])

# =================================================================
# 8. SUPPLIER PAYMENTS
# =================================================================
supplier_payments = []
spid = 1
for _, po in purchase_orders.merge(suppliers[["supplier_id","pay_terms"]], on="supplier_id").iterrows():
    if np.random.rand() < 0.88:
        remaining = po.total_amount
        n_installments = np.random.choice([1, 2], p=[0.8, 0.2])
        for k in range(n_installments):
            if remaining <= 0:
                break
            frac = np.random.uniform(0.5, 1.0) if k < n_installments - 1 else 1.0
            pay_amt = round(remaining * frac, 2) if k < n_installments - 1 else round(remaining, 2)
            delay = po.pay_terms + np.random.normal(0, 10)
            pay_date = po.order_date + pd.to_timedelta(max(delay, 1), unit="D")
            supplier_payments.append({"supplier_payment_id": spid, "po_id": po.po_id,
                                       "payment_date": pay_date, "amount_paid": pay_amt})
            spid += 1
            remaining -= pay_amt
supplier_payments = pd.DataFrame(supplier_payments)
supplier_payments["payment_date"] = pd.to_datetime(supplier_payments["payment_date"]).dt.normalize()

# =================================================================
# 9. INVENTORY MOVEMENTS
# =================================================================
N_MOVEMENTS = N_PRODUCTS * 25
movements = []
for i in range(N_MOVEMENTS):
    prod = products.sample(1).iloc[0]
    mtype = np.random.choice(["RECEIPT","ISSUE"], p=[0.45, 0.55])
    qty = np.random.randint(5, 150)
    movements.append({"movement_id": i+1, "product_id": prod.product_id,
                       "movement_date": np.random.choice(invoice_dates),
                       "movement_type": mtype, "quantity": qty, "unit_cost": prod.unit_cost})
inventory_movements = pd.DataFrame(movements)

# =================================================================
# SAVE EVERYTHING
# =================================================================
os.makedirs(OUTPUT_DIR, exist_ok=True)

customers.to_csv(f"{OUTPUT_DIR}/customers.csv", index=False)
invoices.to_csv(f"{OUTPUT_DIR}/invoices.csv", index=False)
payments.to_csv(f"{OUTPUT_DIR}/payments.csv", index=False)
products.to_csv(f"{OUTPUT_DIR}/products.csv", index=False)
suppliers.to_csv(f"{OUTPUT_DIR}/suppliers.csv", index=False)
purchase_orders.to_csv(f"{OUTPUT_DIR}/purchase_orders.csv", index=False)
po_line_items.to_csv(f"{OUTPUT_DIR}/po_line_items.csv", index=False)
supplier_payments.to_csv(f"{OUTPUT_DIR}/supplier_payments.csv", index=False)
inventory_movements.to_csv(f"{OUTPUT_DIR}/inventory_movements.csv", index=False)

print("=== FULL DATASET GENERATED into data/ ===")
print(f"customers           : {len(customers)}")
print(f"invoices            : {len(invoices)}")
print(f"payments            : {len(payments)}")
print(f"products             : {len(products)}")
print(f"suppliers            : {len(suppliers)}")
print(f"purchase_orders      : {len(purchase_orders)}")
print(f"po_line_items        : {len(po_line_items)}")
print(f"supplier_payments    : {len(supplier_payments)}")
print(f"inventory_movements  : {len(inventory_movements)}")