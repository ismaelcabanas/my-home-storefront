import { Service } from "diod";

import { Clock } from "../../../../shared/domain/Clock";
import { UuidGenerator } from "../../../../shared/domain/UuidGenerator";
import {
	InventoryItem,
	InventoryItemPrimitives,
} from "../../domain/InventoryItem";
import { InventoryItemRepository } from "../../domain/InventoryItemRepository";

@Service()
export class InventoryItemCreator {
	constructor(
		private readonly repository: InventoryItemRepository,
		private readonly uuidGenerator: UuidGenerator,
		private readonly clock: Clock,
	) {}

	async create(name: string): Promise<InventoryItemPrimitives> {
		const id = await this.uuidGenerator.generate();
		const createdAt = this.clock.now();

		const item = InventoryItem.create(id, name, createdAt);

		await this.repository.save(item);

		return item.toPrimitives();
	}
}
