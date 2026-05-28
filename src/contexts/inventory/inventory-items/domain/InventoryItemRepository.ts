import { InventoryItem } from "./InventoryItem";

export abstract class InventoryItemRepository {
	abstract save(item: InventoryItem): Promise<void>;
}
