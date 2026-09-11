-- ============================================================
-- SCHEMA: Working Capital Analytics Project
-- Creates all 9 tables for AR, Inventory, and AP
-- ============================================================

CREATE DATABASE IF NOT EXISTS wc_project;
USE wc_project;

DROP TABLE IF EXISTS inventory_movements;
DROP TABLE IF EXISTS supplier_payments;
DROP TABLE IF EXISTS po_line_items;
DROP TABLE IF EXISTS purchase_orders;
DROP TABLE IF EXISTS suppliers;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS invoices;
DROP TABLE IF EXISTS customers;

-- Accounts Receivable (AR) tables -----------------------------

CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100),
    region VARCHAR(20),
    credit_terms INT
);

CREATE TABLE invoices (
    invoice_id INT PRIMARY KEY,
    customer_id INT,
    invoice_date DATE,
    invoice_amount DECIMAL(12,2),
    due_date DATE,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- No foreign key on invoice_id: real ERP exports can contain
-- orphan payments (a payment referencing an invoice that doesn't
-- exist), and we need to be able to insert and detect those.
CREATE TABLE payments (
    payment_id INT PRIMARY KEY,
    invoice_id INT,
    payment_date DATE,
    amount_paid DECIMAL(12,2),
    method VARCHAR(20)
);

-- Inventory tables ----------------------------------------------

CREATE TABLE products (
    product_id VARCHAR(10) PRIMARY KEY,
    product_name VARCHAR(100),
    category VARCHAR(50),
    unit_cost DECIMAL(10,2),
    unit_price DECIMAL(10,2)
);

CREATE TABLE inventory_movements (
    movement_id INT PRIMARY KEY,
    product_id VARCHAR(10),
    movement_date DATE,
    movement_type VARCHAR(10),
    quantity INT,
    unit_cost DECIMAL(10,2),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- Accounts Payable (AP) tables -----------------------------------

CREATE TABLE suppliers (
    supplier_id INT PRIMARY KEY,
    supplier_name VARCHAR(100),
    pay_terms INT
);

CREATE TABLE purchase_orders (
    po_id INT PRIMARY KEY,
    supplier_id INT,
    order_date DATE,
    due_date DATE,
    total_amount DECIMAL(12,2),
    FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id)
);

CREATE TABLE po_line_items (
    po_id INT,
    line_id INT PRIMARY KEY,
    product_id VARCHAR(10),
    quantity INT,
    unit_cost DECIMAL(10,2),
    FOREIGN KEY (po_id) REFERENCES purchase_orders(po_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- No foreign key on po_id for the same reason as payments above.
CREATE TABLE supplier_payments (
    supplier_payment_id INT PRIMARY KEY,
    po_id INT,
    payment_date DATE,
    amount_paid DECIMAL(12,2)
);