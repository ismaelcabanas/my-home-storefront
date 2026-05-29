import { faker } from "@faker-js/faker";

import { InventoryItemReplenisher } from "../../../../../../src/contexts/inventory/inventory-items/application/replenish/InventoryItemReplenisher";
import { InventoryItemNotFoundError } from "../../../../../../src/contexts/inventory/inventory-items/domain/InventoryItemNotFoundError";
import { InventoryItemMother } from "../../domain/InventoryItemMother";
import { MockInventoryItemRepository } from "../../infrastructure/MockInventoryItemRepository";

describe("InventoryItemReplenisher should", () => {
	const repository = new MockInventoryItemRepository();
	const replenisher = new InventoryItemReplenisher(repository);

	it("replenish depleted item to available state", async () => {
		// Arrange
		const existingItem = InventoryItemMother.create({
			state: "Depleted",
			requiresPurchase: true,
		});
		const updatedItem = InventoryItemMother.create({
			id: existingItem.id.value,
			name: existingItem.name.value,
			state: "Available",
			requiresPurchase: false,
			createdAt: existingItem.createdAt.toISOString(),
		});
		repository.shouldFindById(existingItem.id.value, existingItem);
		repository.shouldSave(updatedItem);

		// Act
		const result = await replenisher.replenish(existingItem.id.value);

		// Assert
		expect(result.state).toBe("Available");
		expect(result.requiresPurchase).toBe(false);
		repository.verify();
	});

	it("replenish low item to available state", async () => {
		// Arrange
		const existingItem = InventoryItemMother.create({
			state: "Low",
			requiresPurchase: true,
		});
		const updatedItem = InventoryItemMother.create({
			id: existingItem.id.value,
			name: existingItem.name.value,
			state: "Available",
			requiresPurchase: false,
			createdAt: existingItem.createdAt.toISOString(),
		});
		repository.shouldFindById(existingItem.id.value, existingItem);
		repository.shouldSave(updatedItem);

		// Act
		const result = await replenisher.replenish(existingItem.id.value);

		// Assert
		expect(result.state).toBe("Available");
		expect(result.requiresPurchase).toBe(false);
		repository.verify();
	});

	it("replenish already available item idempotently", async () => {
		// Arrange
		const existingItem = InventoryItemMother.create({
			state: "Available",
			requiresPurchase: false,
		});
		const updatedItem = InventoryItemMother.create({
			id: existingItem.id.value,
			name: existingItem.name.value,
			state: "Available",
			requiresPurchase: false,
			createdAt: existingItem.createdAt.toISOString(),
		});
		repository.shouldFindById(existingItem.id.value, existingItem);
		repository.shouldSave(updatedItem);

		// Act
		const result = await replenisher.replenish(existingItem.id.value);

		// Assert
		expect(result.state).toBe("Available");
		expect(result.requiresPurchase).toBe(false);
		repository.verify();
	});

	it("throw InventoryItemNotFoundError when item not found", async () => {
		// Arrange
		const nonExistentId = faker.string.uuid();
		repository.shouldFindById(nonExistentId, null); // Will throw error

		// Act & Assert
		await expect(replenisher.replenish(nonExistentId)).rejects.toThrow(
			InventoryItemNotFoundError,
		);
	});
});
