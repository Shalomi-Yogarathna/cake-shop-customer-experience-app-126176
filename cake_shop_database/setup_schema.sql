-- Cake Shop App - PostgreSQL Database Schema & Setup Script
-- This script creates tables and relationships for:
-- User management, Cake catalog, Customization, Ordering, Toppings, Analytics
-- Idempotent (safe to re-run; drops & recreates tables in order)

-- =====================
-- Drop tables IF EXISTS in correct order for safe recreation
-- =====================
DROP TABLE IF EXISTS order_status_history CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS cake_customizations CASCADE;
DROP TABLE IF EXISTS cake_topping CASCADE;
DROP TABLE IF EXISTS cake_flavor CASCADE;
DROP TABLE IF EXISTS cake_images CASCADE;
DROP TABLE IF EXISTS cakes CASCADE;
DROP TABLE IF EXISTS toppings CASCADE;
DROP TABLE IF EXISTS flavors CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- =====================
-- Users Table
-- =====================
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    full_name VARCHAR(255),
    phone VARCHAR(40),
    is_admin BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================
-- Cake Catalog Tables
-- =====================
CREATE TABLE cakes (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price NUMERIC(10, 2) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    category VARCHAR(100),
    base_image_url VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE cake_images (
    id SERIAL PRIMARY KEY,
    cake_id INT NOT NULL REFERENCES cakes(id) ON DELETE CASCADE,
    image_url VARCHAR(255) NOT NULL,
    alt_text VARCHAR(255),
    is_primary BOOLEAN DEFAULT FALSE
);

CREATE TABLE flavors (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT
);

CREATE TABLE cake_flavor (
    id SERIAL PRIMARY KEY,
    cake_id INT NOT NULL REFERENCES cakes(id) ON DELETE CASCADE,
    flavor_id INT NOT NULL REFERENCES flavors(id) ON DELETE CASCADE,
    is_default BOOLEAN DEFAULT FALSE
);

CREATE TABLE toppings (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    price NUMERIC(10, 2) DEFAULT 0.00,
    image_url VARCHAR(255)
);

CREATE TABLE cake_topping (
    id SERIAL PRIMARY KEY,
    cake_id INT NOT NULL REFERENCES cakes(id) ON DELETE CASCADE,
    topping_id INT NOT NULL REFERENCES toppings(id) ON DELETE CASCADE,
    is_default BOOLEAN DEFAULT FALSE
);

-- =====================
-- Customizations Table
-- Represents a user-customized cake attached to an order (or as a preset template)
-- =====================
CREATE TABLE cake_customizations (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id) ON DELETE SET NULL,
    cake_id INT NOT NULL REFERENCES cakes(id) ON DELETE CASCADE,
    flavor_id INT REFERENCES flavors(id),
    size VARCHAR(100), -- e.g., "Small", "Medium", "Large"
    message_on_cake VARCHAR(255),
    custom_image_url VARCHAR(255),
    toppings INT[], -- Array of topping ids
    price NUMERIC(10,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================
-- Orders Tables
-- =====================
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id) ON DELETE SET NULL,
    delivery_address TEXT NOT NULL,
    delivery_time TIMESTAMPTZ,
    contact_phone VARCHAR(40),
    order_status VARCHAR(40) DEFAULT 'pending',
    order_total NUMERIC(10, 2) NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    cake_id INT NOT NULL REFERENCES cakes(id) ON DELETE SET NULL,
    customization_id INT REFERENCES cake_customizations(id) ON DELETE SET NULL,
    quantity INT NOT NULL DEFAULT 1,
    item_price NUMERIC(10,2) NOT NULL,
    item_name VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- For basic order status history/audit
CREATE TABLE order_status_history (
    id SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    status VARCHAR(40) NOT NULL,
    changed_at TIMESTAMPTZ DEFAULT NOW(),
    changed_by INT REFERENCES users(id)
);

-- =====================
-- Analytics Support Views/Materialized Views (examples)
-- =====================

-- View: most ordered cakes
CREATE OR REPLACE VIEW most_ordered_cakes AS
SELECT 
    c.id AS cake_id,
    c.name,
    COUNT(oi.id) AS order_count
FROM cakes c
LEFT JOIN order_items oi ON oi.cake_id = c.id
GROUP BY c.id, c.name
ORDER BY order_count DESC;

-- View: most popular toppings
CREATE OR REPLACE VIEW most_popular_toppings AS
SELECT 
    t.id AS topping_id,
    t.name,
    COUNT(*) AS used_count
FROM toppings t
JOIN cake_customizations cc ON t.id = ANY(cc.toppings)
GROUP BY t.id, t.name
ORDER BY used_count DESC;

-- View: top users by order count
CREATE OR REPLACE VIEW top_customers AS
SELECT
    u.id AS user_id, u.full_name, u.email,
    COUNT(o.id) AS orders_placed,
    SUM(o.order_total) AS total_spent
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY u.id, u.full_name, u.email
ORDER BY total_spent DESC;

-- =====================
-- Indexes
-- =====================
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_cake_customizations_user_id ON cake_customizations(user_id);

-- =====================
-- Example Admin User (for development/test)
-- =====================
-- INSERT INTO users (email, hashed_password, full_name, is_admin)
-- VALUES ('admin@cake.shop', '<hashed-password>', 'Admin User', TRUE);

-- =====================
-- End of Schema Script
-- =====================

-- To apply this schema, run:
--   psql <DB_CONN_PARAMS> -f setup_schema.sql
