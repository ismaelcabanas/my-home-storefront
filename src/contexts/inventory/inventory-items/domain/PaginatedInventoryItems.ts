import { InventoryItemPrimitives } from "./InventoryItem";

export interface PaginatedInventoryItems {
	items: InventoryItemPrimitives[];
	nextCursor: string | null;
	hasMore: boolean;
}

/**
 * Creates an empty paginated result
 * @returns Empty paginated result with no items and no next page
 */
export function emptyPaginatedInventoryItems(): PaginatedInventoryItems {
	return {
		items: [],
		nextCursor: null,
		hasMore: false,
	};
}

/**
 * Creates a paginated result from items and metadata
 * @param items - Array of inventory items for current page
 * @param nextCursor - Opaque token for next page, null if no more results
 * @param hasMore - Indicates whether additional pages exist
 * @returns Paginated result with items and metadata
 */
export function createPaginatedInventoryItems(
	items: InventoryItemPrimitives[],
	nextCursor: string | null,
	hasMore: boolean,
): PaginatedInventoryItems {
	// Ensure consistency: nextCursor must be null when hasMore is false
	const finalNextCursor = hasMore ? nextCursor : null;

	return {
		items,
		nextCursor: finalNextCursor,
		hasMore,
	};
}
