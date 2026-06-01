import { Service } from "diod";

import { InventoryItemRepository } from "../../domain/InventoryItemRepository";
import { type PaginatedInventoryItems } from "../../domain/PaginatedInventoryItems";

@Service()
export class ShoppingItemLister {
	constructor(private readonly repository: InventoryItemRepository) {}

	/**
	 * Lists inventory items requiring purchase with cursor-based pagination
	 * @param limit - Number of items per page (default: 20, range: 1-100)
	 * @param cursor - Opaque cursor token for pagination (null for first page)
	 * @returns Paginated inventory items requiring purchase with metadata
	 */
	async listAll(
		limit: number = 20,
		cursor: string | null = null,
	): Promise<PaginatedInventoryItems> {
		// Input Validation: Parse limit as number, validate range 1-100, default to 20
		const validatedLimit =
			typeof limit === "number" && limit >= 1 && limit <= 100
				? limit
				: 20;

		// Business Logic: Delegate to repository.searchByRequiresPurchase
		// Repository handles cursor decoding and validation
		return await this.repository.searchByRequiresPurchase(
			validatedLimit,
			cursor,
		);
	}
}
