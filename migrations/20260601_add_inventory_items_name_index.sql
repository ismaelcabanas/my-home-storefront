-- Create composite index on (name, created_at) to optimize ORDER BY name ASC, created_at ASC queries
-- This index is used by the cursor-based pagination in searchAll method
CREATE INDEX IF NOT EXISTS idx_inventory_items_name_created_at
ON inventory.inventory_items(name, created_at);
