import { faker } from "@faker-js/faker";

import { InventoryItemLowMarker } from "../../../../../../src/contexts/inventory/inventory-items/application/mark-low/InventoryItemLowMarker";
import { InventoryItemNotFoundError } from "../../../../../../src/contexts/inventory/inventory-items/domain/InventoryItemNotFoundError";
import { InventoryItemMother } from "../../domain/InventoryItemMother";
import { MockInventoryItemRepository } from "../../infrastructure/MockInventoryItemRepository";

describe("InventoryItemLowMarker should", () => {
	const repository = new MockInventoryItemRepository();
	const lowMarker = new InventoryItemLowMarker(repository);

	it("mark available item as low", async () => {
		// Arrange
		const existingItem = InventoryItemMother.create({
			state: "Available",
			requiresPurchase: false,
		});
		const updatedItem = InventoryItemMother.create({
			id: existingItem.id.value,
			name: existingItem.name.value,
			state: "Low",
			requiresPurchase: true,
			createdAt: existingItem.createdAt.toISOString(),
		});
		repository.shouldFindById(existingItem.id.value, existingItem);
		repository.shouldSave(updatedItem);

		// Act
		const result = await lowMarker.markLow(existingItem.id.value);

		// Assert
		expect(result.state).toBe("Low");
		expect(result.requiresPurchase).toBe(true);
		repository.verify();
	});

	it("mark already low item as low idempotently", async () => {
		// Arrange
		const existingItem = InventoryItemMother.create({
			state: "Low",
			requiresPurchase: true,
		});
		const updatedItem = InventoryItemMother.create({
			id: existingItem.id.value,
			name: existingItem.name.value,
			state: "Low",
			requiresPurchase: true,
			createdAt: existingItem.createdAt.toISOString(),
		});
		repository.shouldFindById(existingItem.id.value, existingItem);
		repository.shouldSave(updatedItem);

		// Act
		const result = await lowMarker.markLow(existingItem.id.value);

		// Assert
		expect(result.state).toBe("Low");
		expect(result.requiresPurchase).toBe(true);
		repository.verify();
	});

	it("throw InventoryItemNotFoundError when item not found", async () => {
		// Arrange
		const nonExistentId = faker.string.uuid();
		repository.shouldFindById(nonExistentId, null); // Will throw error

		// Act & Assert
		await expect(lowMarker.markLow(nonExistentId)).rejects.toThrow(
			InventoryItemNotFoundError,
		);
	});
});
