import pandas as pd
from sqlalchemy import create_engine

# Update the password below to match your MySQL root password (or a dedicated user if you made one)
engine = create_engine("mysql+pymysql://root:iamyashwanth@127.0.0.1:3306/wc_project")

load_order = [
    ("customers", "customers.csv"),
    ("products", "products.csv"),
    ("suppliers", "suppliers.csv"),
    ("invoices", "invoices.csv"),
    ("payments", "payments.csv"),
    ("purchase_orders", "purchase_orders.csv"),
    ("po_line_items", "po_line_items.csv"),
    ("supplier_payments", "supplier_payments.csv"),
    ("inventory_movements", "inventory_movements.csv"),
]

for table_name, csv_file in load_order:
    df = pd.read_csv(f"../data/{csv_file}")
    df.to_sql(table_name, engine, if_exists="append", index=False)
    print(f"Loaded {table_name}: {len(df)} rows")

print("\nAll data loaded into MySQL.")