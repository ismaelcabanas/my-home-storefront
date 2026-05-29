import { faker } from "@faker-js/faker";

import {
	InventoryItem,
	InventoryItemPrimitives,
} from "../../../../../src/contexts/inventory/inventory-items/domain/InventoryItem";

export class InventoryItemMother {
	static create(params?: Partial<InventoryItemPrimitives>): InventoryItem {
		const primitives: InventoryItemPrimitives = {
			id: faker.string.uuid(),
			name: faker.commerce.productName(),
			state: "Available",
			requiresPurchase: false,
			createdAt: faker.date.recent().toISOString(),
			...params,
		};

		return InventoryItem.fromPrimitives(primitives);
	}
}
