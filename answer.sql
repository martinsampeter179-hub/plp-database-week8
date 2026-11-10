use sales;

Table merchants {
  id uuid [pk]
  name varchar
  country_code varchar
  created_at timestamp
}

Table products {
  id uuid [pk]
  merchant_id uuid [ref: > merchants.id]
  sku varchar [unique]
  name varchar
  unit_price numeric
}

Table inventory_batches {
  id uuid [pk]
  product_id uuid [ref: > products.id]
  quantity int
  received_date date
}

Table orders {
  id uuid [pk]
  merchant_id uuid [ref: > merchants.id]
  customer_id uuid
  status varchar
  total_amount numeric
  created_at timestamp
}

Table order_items {
  id uuid [pk]
  order_id uuid [ref: > orders.id]
  product_id uuid [ref: > products.id]
  quantity int
  unit_price numeric
}

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE merchants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    country_code VARCHAR(3) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
    sku VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0)
);

CREATE TABLE inventory_batches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    quantity INT NOT NULL CHECK (quantity >= 0),
    received_date DATE DEFAULT CURRENT_DATE
);

CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    total_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12,2) NOT NULL
);

CREATE INDEX idx_products_merchant ON products(merchant_id);
CREATE INDEX idx_orders_merchant_status ON orders(merchant_id, status);
CREATE INDEX idx_order_items_order ON order_items(order_id);

CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name TEXT NOT NULL,
    record_id UUID NOT NULL,
    action TEXT NOT NULL,
    performed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION log_order_changes()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_logs (table_name, record_id, action)
    VALUES ('orders', NEW.id, TG_OP);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_orders
AFTER INSERT OR UPDATE ON orders
FOR EACH ROW EXECUTE FUNCTION log_order_changes();

ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY merchant_isolation_policy ON orders
    USING (merchant_id = current_setting('app.current_merchant_id')::UUID);
    
    INSERT INTO merchants (id, name, country_code) 
VALUES ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Nairobi General Store', 'KEN');

INSERT INTO products (id, merchant_id, sku, name, unit_price) 
VALUES ('b1eebc99-9c0b-4ef8-bb6d-6bb9bd380b22', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'SKU-MAIZE-2KG', 'Maize Flour 2kg', 180.00);

Seq Scan on orders  (cost=0.00..1842.00 rows=150 width=44)
  Filter: ((merchant_id = 'a0eebc99-...'::uuid) AND ((status)::text = 'pending'::text))
Execution Time: 42.500 ms

Bitmap Heap Scan on orders  (cost=4.25..45.10 rows=150 width=44)
  ->  Bitmap Index Scan on idx_orders_merchant_status  (cost=0.00..4.15 rows=150 width=0)
        Index Cond: ((merchant_id = 'a0eebc99-...'::uuid) AND ((status)::text = 'pending'::text))
Execution Time: 1.120 ms

pg_dump -Fc -f backups/capstone_$(date +%F).dump capstone
