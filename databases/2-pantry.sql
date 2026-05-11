CREATE SCHEMA IF NOT EXISTS pantry;

CREATE TABLE pantry.products (
    id UUID PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    name_normalized TEXT GENERATED ALWAYS AS (LOWER(TRIM(name))) STORED NOT NULL,
    current_stock INTEGER NOT NULL DEFAULT 0 CHECK (current_stock >= 0),
    last_updated TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX products_name_normalized_idx ON pantry.products(name_normalized);
