import { faker } from "@faker-js/faker";

import { InventoryItemDepleter } from "../../../../../../src/contexts/inventory/inventory-items/application/deplete/InventoryItemDepleter";
import { InventoryItemNotFoundError } from "../../../../../../src/contexts/inventory/inventory-items/domain/InventoryItemNotFoundError";
import { InventoryItemMother } from "../../domain/InventoryItemMother";
import { MockInventoryItemRepository } from "../../infrastructure/MockInventoryItemRepository";

describe("InventoryItemDepleter should", () => {
	const repository = new MockInventoryItemRepository();
	const depleter = new InventoryItemDepleter(repository);

	it("deplete available item", async () => {
		// Arrange
		const existingItem = InventoryItemMother.create({
			state: "Available",
			requiresPurchase: false,
		});
		const updatedItem = InventoryItemMother.create({
			id: existingItem.id.value,
			name: existingItem.name.value,
			state: "Depleted",
			requiresPurchase: true,
			createdAt: existingItem.createdAt.toISOString(),
		});
		repository.shouldFindById(existingItem.id.value, existingItem);
		repository.shouldSave(updatedItem);

		// Act
		const result = await depleter.deplete(existingItem.id.value);

		// Assert
		expect(result.state).toBe("Depleted");
		expect(result.requiresPurchase).toBe(true);
		repository.verify();
	});

	it("deplete low item", async () => {
		// Arrange
		const existingItem = InventoryItemMother.create({
			state: "Low",
			requiresPurchase: true,
		});
		const updatedItem = InventoryItemMother.create({
			id: existingItem.id.value,
			name: existingItem.name.value,
			state: "Depleted",
			requiresPurchase: true,
			createdAt: existingItem.createdAt.toISOString(),
		});
		repository.shouldFindById(existingItem.id.value, existingItem);
		repository.shouldSave(updatedItem);

		// Act
		const result = await depleter.deplete(existingItem.id.value);

		// Assert
		expect(result.state).toBe("Depleted");
		expect(result.requiresPurchase).toBe(true);
		repository.verify();
	});

	it("deplete already depleted item idempotently", async () => {
		// Arrange
		const existingItem = InventoryItemMother.create({
			state: "Depleted",
			requiresPurchase: true,
		});
		const updatedItem = InventoryItemMother.create({
			id: existingItem.id.value,
			name: existingItem.name.value,
			state: "Depleted",
			requiresPurchase: true,
			createdAt: existingItem.createdAt.toISOString(),
		});
		repository.shouldFindById(existingItem.id.value, existingItem);
		repository.shouldSave(updatedItem);

		// Act
		const result = await depleter.deplete(existingItem.id.value);

		// Assert
		expect(result.state).toBe("Depleted");
		expect(result.requiresPurchase).toBe(true);
		repository.verify();
	});

	it("throw InventoryItemNotFoundError when item not found", async () => {
		// Arrange
		const nonExistentId = faker.string.uuid();
		repository.shouldFindById(nonExistentId, null); // Will throw error

		// Act & Assert
		await expect(depleter.deplete(nonExistentId)).rejects.toThrow(
			InventoryItemNotFoundError,
		);
	});
});
