import { Service } from "diod";

import {
	InventoryItem,
	InventoryItemPrimitives,
} from "../../domain/InventoryItem";
import { InventoryItemRepository } from "../../domain/InventoryItemRepository";

@Service()
export class InventoryItemDepleter {
	constructor(private readonly repository: InventoryItemRepository) {}

	async deplete(id: string): Promise<InventoryItemPrimitives> {
		const existing = await this.repository.findById(id);
		const existingPrimitives = existing.toPrimitives();

		const updated = InventoryItem.fromPrimitives({
			...existingPrimitives,
			state: "Depleted",
		});

		await this.repository.save(updated);

		return updated.toPrimitives();
	}
}
