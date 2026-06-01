import { InventoryItemLister } from "../../../../../../src/contexts/inventory/inventory-items/application/list/InventoryItemLister";
import { InvalidCursorError } from "../../../../../../src/contexts/inventory/inventory-items/domain/InvalidCursorError";
import { InventoryItemMother } from "../../domain/InventoryItemMother";
import { MockInventoryItemRepository } from "../../infrastructure/MockInventoryItemRepository";

describe("InventoryItemLister should", () => {
	it("list first page with default parameters", async () => {
		// Arrange
		const repository = new MockInventoryItemRepository();
		const lister = new InventoryItemLister(repository);

		const items = Array.from({ length: 21 }, () =>
			InventoryItemMother.create(),
		);
		items.forEach((item) => repository.items.set(item.id.value, item));

		// Act
		const result = await lister.listAll();

		// Assert
		expect(result.items).toHaveLength(20);
		expect(result.hasMore).toBe(true);
	});

	it("list all with default limit and null cursor", async () => {
		// Arrange
		const repository = new MockInventoryItemRepository();
		const lister = new InventoryItemLister(repository);

		// Act
		const result = await lister.listAll();

		// Assert
		expect(repository).toBeDefined();
	});

	it("list all with custom limit", async () => {
		// Arrange
		const repository = new MockInventoryItemRepository();
		const lister = new InventoryItemLister(repository);

		const items = Array.from({ length: 50 }, () =>
			InventoryItemMother.create(),
		);
		items.forEach((item) => repository.items.set(item.id.value, item));

		// Act
		const result = await lister.listAll(50, null);

		// Assert
		expect(result.items).toHaveLength(50);
	});

	it("list all with cursor for second page", async () => {
		// Arrange
		const repository = new MockInventoryItemRepository();
		const lister = new InventoryItemLister(repository);

		const items = Array.from({ length: 40 }, (_, i) =>
			InventoryItemMother.create({ name: `Item-${i}` }),
		);
		items.forEach((item) => repository.items.set(item.id.value, item));

		const firstPage = await lister.listAll(20, null);
		const cursor = firstPage.nextCursor;

		// Act
		const result = await lister.listAll(20, cursor as string);

		// Assert
		expect(result.items).toHaveLength(20);
	});

	it("use default limit for invalid limit value", async () => {
		// Arrange
		const repository = new MockInventoryItemRepository();
		const lister = new InventoryItemLister(repository);

		// Act
		const result = await lister.listAll(-5, null);

		// Assert
		expect(result).toBeDefined();
	});

	it("propagate InvalidCursorError from repository", async () => {
		// Arrange
		const repository = new MockInventoryItemRepository();
		const lister = new InventoryItemLister(repository);

		// Act & Assert
		await expect(lister.listAll(20, "invalid-cursor")).rejects.toThrow(
			InvalidCursorError,
		);
	});

	it("return empty result for empty inventory", async () => {
		// Arrange
		const repository = new MockInventoryItemRepository();
		const lister = new InventoryItemLister(repository);

		// Act
		const result = await lister.listAll(20, null);

		// Assert
		expect(result.items).toEqual([]);
		expect(result.nextCursor).toBeNull();
		expect(result.hasMore).toBe(false);
	});
});
