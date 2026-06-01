import { InventoryItem } from "./InventoryItem";
import { type PaginatedInventoryItems } from "./PaginatedInventoryItems";

export abstract class InventoryItemRepository {
	abstract save(item: InventoryItem): Promise<void>;
	abstract searchById(id: string): Promise<InventoryItem | null>;
	abstract findById(id: string): Promise<InventoryItem>;
	abstract searchAll(
		limit: number,
		cursor: string | null,
	): Promise<PaginatedInventoryItems>;

	abstract searchByRequiresPurchase(
		limit: number,
		cursor: string | null,
	): Promise<PaginatedInventoryItems>;
}
