CREATE SCHEMA IF NOT EXISTS inventory;

CREATE TABLE inventory.inventory_items (
    id UUID PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    state VARCHAR(20) NOT NULL DEFAULT 'Available',
    requires_purchase BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
