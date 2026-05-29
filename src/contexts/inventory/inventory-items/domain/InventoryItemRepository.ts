import { InventoryItem } from "./InventoryItem";

export abstract class InventoryItemRepository {
	abstract save(item: InventoryItem): Promise<void>;
	abstract searchById(id: string): Promise<InventoryItem | null>;
	abstract findById(id: string): Promise<InventoryItem>;
}
