import { Service } from "diod";
import { Row } from "postgres";

import { PostgresRepository } from "../../../shared/infrastructure/postgres/PostgresRepository";
import { InventoryItem } from "../domain/InventoryItem";
import { InventoryItemRepository } from "../domain/InventoryItemRepository";

@Service()
export class PostgresInventoryItemRepository
	extends PostgresRepository<InventoryItem>
	implements InventoryItemRepository
{
	async save(item: InventoryItem): Promise<void> {
		const primitives = item.toPrimitives();

		await this.execute`
			INSERT INTO inventory.inventory_items (id, name, state, requires_purchase, created_at)
			VALUES (
				${primitives.id},
				${primitives.name},
				${primitives.state},
				${primitives.requiresPurchase},
				${primitives.createdAt}
			);
		`;
	}

	protected toAggregate(row: Row): InventoryItem {
		return InventoryItem.fromPrimitives({
			id: row.id as string,
			name: row.name as string,
			state: row.state as string,
			requiresPurchase: row.requires_purchase as boolean,
			createdAt: row.created_at as string,
		});
	}
}
