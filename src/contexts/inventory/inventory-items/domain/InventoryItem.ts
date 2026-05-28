import { AggregateRoot } from "../../../shared/domain/AggregateRoot";

import { InventoryItemId } from "./InventoryItemId";
import { InventoryItemName } from "./InventoryItemName";
import { InventoryItemState } from "./InventoryItemState";

export interface InventoryItemPrimitives {
	id: string;
	name: string;
	state: string;
	requiresPurchase: boolean;
	createdAt: string;
}

export class InventoryItem extends AggregateRoot {
	constructor(
		readonly id: InventoryItemId,
		readonly name: InventoryItemName,
		readonly state: InventoryItemState,
		readonly createdAt: Date,
	) {
		super();
	}

	static create(id: string, name: string, createdAt: Date): InventoryItem {
		return new InventoryItem(
			new InventoryItemId(id),
			InventoryItemName.create(name),
			InventoryItemState.Available(),
			createdAt,
		);
	}

	static fromPrimitives(primitives: InventoryItemPrimitives): InventoryItem {
		return new InventoryItem(
			new InventoryItemId(primitives.id),
			InventoryItemName.create(primitives.name),
			InventoryItemState.fromValue(primitives.state),
			new Date(primitives.createdAt),
		);
	}

	get requiresPurchase(): boolean {
		return this.state.derivesRequiresPurchase();
	}

	toPrimitives(): InventoryItemPrimitives {
		return {
			id: this.id.value,
			name: this.name.value,
			state: this.state.value,
			requiresPurchase: this.requiresPurchase,
			createdAt: this.createdAt.toISOString(),
		};
	}
}
