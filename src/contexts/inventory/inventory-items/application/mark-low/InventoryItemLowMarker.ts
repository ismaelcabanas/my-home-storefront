import { Service } from "diod";

import {
	InventoryItem,
	InventoryItemPrimitives,
} from "../../domain/InventoryItem";
import { InventoryItemRepository } from "../../domain/InventoryItemRepository";

@Service()
export class InventoryItemLowMarker {
	constructor(private readonly repository: InventoryItemRepository) {}

	async markLow(id: string): Promise<InventoryItemPrimitives> {
		const existing = await this.repository.findById(id);
		const existingPrimitives = existing.toPrimitives();

		const updated = InventoryItem.fromPrimitives({
			...existingPrimitives,
			state: "Low",
		});

		await this.repository.save(updated);

		return updated.toPrimitives();
	}
}
