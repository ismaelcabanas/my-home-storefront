import { InventoryItemCreator } from "../../../../../../src/contexts/inventory/inventory-items/application/create/InventoryItemCreator";
import { InvalidInventoryItemNameError } from "../../../../../../src/contexts/inventory/inventory-items/domain/InvalidInventoryItemNameError";
import { MockUuidGenerator } from "../../../../shared/domain/MockUuidGenerator";
import { MockClock } from "../../../../shared/infrastructure/MockClock";
import { InventoryItemMother } from "../../domain/InventoryItemMother";
import { MockInventoryItemRepository } from "../../infrastructure/MockInventoryItemRepository";

describe("InventoryItemCreator should", () => {
	const repository = new MockInventoryItemRepository();
	const uuidGenerator = new MockUuidGenerator();
	const clock = new MockClock();
	const creator = new InventoryItemCreator(repository, uuidGenerator, clock);

	it("create inventory item with valid name", async () => {
		// Arrange
		const expectedId = "550e8400-e29b-41d4-a716-446655440000";
		const expectedDate = new Date("2026-05-29T10:00:00.000Z");
		uuidGenerator.shouldGenerate(expectedId);
		clock.shouldGenerate(expectedDate);

		const expectedItem = InventoryItemMother.create({
			id: expectedId,
			name: "Milk",
			state: "Available",
			requiresPurchase: false,
			createdAt: expectedDate.toISOString(),
		});
		repository.shouldSave(expectedItem);

		// Act
		const result = await creator.create("Milk");

		// Assert
		expect(result.id).toBe(expectedId);
		expect(result.name).toBe("Milk");
		expect(result.state).toBe("Available");
		expect(result.requiresPurchase).toBe(false);
		expect(result.createdAt).toBe(expectedDate.toISOString());
		repository.verify();
	});

	it("throw InvalidInventoryItemNameError for empty name", async () => {
		// Act & Assert
		await expect(creator.create("")).rejects.toThrow(
			InvalidInventoryItemNameError,
		);
	});

	it("throw InvalidInventoryItemNameError for whitespace-only name", async () => {
		// Act & Assert
		await expect(creator.create("   ")).rejects.toThrow(
			InvalidInventoryItemNameError,
		);
	});

	it("trim whitespace from name", async () => {
		// Arrange
		const expectedId = "550e8400-e29b-41d4-a716-446655440001";
		const expectedDate = new Date("2026-05-29T11:00:00.000Z");
		uuidGenerator.shouldGenerate(expectedId);
		clock.shouldGenerate(expectedDate);

		const expectedItem = InventoryItemMother.create({
			id: expectedId,
			name: "Milk",
			state: "Available",
			requiresPurchase: false,
			createdAt: expectedDate.toISOString(),
		});
		repository.shouldSave(expectedItem);

		// Act
		const result = await creator.create("  Milk  ");

		// Assert
		expect(result.name).toBe("Milk");
		repository.verify();
	});
});
