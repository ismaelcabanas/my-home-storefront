import { ShoppingItemLister } from "../../../../../../src/contexts/inventory/inventory-items/application/shopping-list/ShoppingItemLister";
import { InvalidCursorError } from "../../../../../../src/contexts/inventory/inventory-items/domain/InvalidCursorError";
import { InventoryItemMother } from "../../domain/InventoryItemMother";
import { MockInventoryItemRepository } from "../../infrastructure/MockInventoryItemRepository";

describe("ShoppingItemLister should", () => {
	it("have constructor injection of InventoryItemRepository", () => {
		// Arrange
		const repository = new MockInventoryItemRepository();

		// Act
		const lister = new ShoppingItemLister(repository);

		// Assert
		expect(lister).toBeDefined();
		expect(lister["repository"]).toBe(repository);
	});

	it("list all with default limit and null cursor", async () => {
		// Arrange
		const repository = new MockInventoryItemRepository();
		const lister = new ShoppingItemLister(repository);

		const items = Array.from({ length: 21 }, () =>
			InventoryItemMother.create({
				state: "Low",
				requiresPurchase: true,
			}),
		);
		items.forEach((item) => repository.items.set(item.id.value, item));

		// Act
		const result = await lister.listAll();

		// Assert
		expect(result.items).toHaveLength(20);
		expect(result.hasMore).toBe(true);
		expect(result.nextCursor).not.toBeNull();
	});

	it("list all with custom limit within valid range", async () => {
		// Arrange
		const repository = new MockInventoryItemRepository();
		const lister = new ShoppingItemLister(repository);

		const items = Array.from({ length: 50 }, () =>
			InventoryItemMother.create({
				state: "Low",
				requiresPurchase: true,
			}),
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
		const lister = new ShoppingItemLister(repository);

		const items = Array.from({ length: 40 }, (_, i) =>
			InventoryItemMother.create({
				name: `Item-${i}`,
				state: "Depleted",
				requiresPurchase: true,
			}),
		);
		items.forEach((item) => repository.items.set(item.id.value, item));

		const firstPage = await lister.listAll(20, null);
		const cursor = firstPage.nextCursor;

		// Act
		const result = await lister.listAll(20, cursor as string);

		// Assert
		expect(result.items).toHaveLength(20);
		expect(result.nextCursor).toBeNull();
		expect(result.hasMore).toBe(false);
	});

	it("delegate to repository.searchByRequiresPurchase exactly once", async () => {
		// Arrange
		const repository = new MockInventoryItemRepository();
		const searchByRequiresPurchaseSpy = jest.spyOn(
			repository,
			"searchByRequiresPurchase",
		);
		const lister = new ShoppingItemLister(repository);

		// Act
		await lister.listAll(20, null);

		// Assert
		expect(searchByRequiresPurchaseSpy).toHaveBeenCalledTimes(1);
		expect(searchByRequiresPurchaseSpy).toHaveBeenCalledWith(20, null);

		searchByRequiresPurchaseSpy.mockRestore();
	});

	it("propagate InvalidCursorError from repository", async () => {
		// Arrange
		const repository = new MockInventoryItemRepository();
		const lister = new ShoppingItemLister(repository);

		// Act & Assert
		await expect(lister.listAll(20, "invalid-cursor")).rejects.toThrow(
			InvalidCursorError,
		);
	});

	it("return PaginatedInventoryItems structure matching repository response", async () => {
		// Arrange
		const repository = new MockInventoryItemRepository();
		const lister = new ShoppingItemLister(repository);

		const items = Array.from({ length: 5 }, () =>
			InventoryItemMother.create({
				state: "Low",
				requiresPurchase: true,
			}),
		);
		items.forEach((item) => repository.items.set(item.id.value, item));

		// Act
		const result = await lister.listAll(10, null);

		// Assert
		expect(result).toHaveProperty("items");
		expect(result).toHaveProperty("nextCursor");
		expect(result).toHaveProperty("hasMore");
		expect(Array.isArray(result.items)).toBe(true);
		expect(typeof result.nextCursor === "string" || result.nextCursor === null).toBe(
			true,
		);
		expect(typeof result.hasMore).toBe("boolean");
	});

	it("use default limit of 20 for limit = 0 (below minimum)", async () => {
		// Arrange
		const repository = new MockInventoryItemRepository();
		const lister = new ShoppingItemLister(repository);

		const items = Array.from({ length: 25 }, () =>
			InventoryItemMother.create({
				state: "Depleted",
				requiresPurchase: true,
			}),
		);
		items.forEach((item) => repository.items.set(item.id.value, item));

		// Act
		const result = await lister.listAll(0, null);

		// Assert - Should default to 20 and return hasMore true
		expect(result.items).toHaveLength(20);
		expect(result.hasMore).toBe(true);
	});

	it("use default limit of 20 for limit = 101 (above maximum)", async () => {
		// Arrange
		const repository = new MockInventoryItemRepository();
		const lister = new ShoppingItemLister(repository);

		const items = Array.from({ length: 25 }, () =>
			InventoryItemMother.create({
				state: "Low",
				requiresPurchase: true,
			}),
		);
		items.forEach((item) => repository.items.set(item.id.value, item));

		// Act
		const result = await lister.listAll(101, null);

		// Assert - Should default to 20
		expect(result.items).toHaveLength(20);
	});

	it("use default limit of 20 for non-numeric limit", async () => {
		// Arrange
		const repository = new MockInventoryItemRepository();
		const lister = new ShoppingItemLister(repository);

		const items = Array.from({ length: 25 }, () =>
			InventoryItemMother.create({
				state: "Depleted",
				requiresPurchase: true,
			}),
		);
		items.forEach((item) => repository.items.set(item.id.value, item));

		// Act
		const result = await lister.listAll(NaN as unknown as number, null);

		// Assert - Should default to 20
		expect(result.items).toHaveLength(20);
	});

	it("handle limit = 1 (minimum boundary)", async () => {
		// Arrange
		const repository = new MockInventoryItemRepository();
		const lister = new ShoppingItemLister(repository);

		const items = Array.from({ length: 5 }, () =>
			InventoryItemMother.create({
				state: "Low",
				requiresPurchase: true,
			}),
		);
		items.forEach((item) => repository.items.set(item.id.value, item));

		// Act
		const result = await lister.listAll(1, null);

		// Assert
		expect(result.items).toHaveLength(1);
		expect(result.hasMore).toBe(true);
	});

	it("handle limit = 100 (maximum boundary)", async () => {
		// Arrange
		const repository = new MockInventoryItemRepository();
		const lister = new ShoppingItemLister(repository);

		const items = Array.from({ length: 150 }, () =>
			InventoryItemMother.create({
				state: "Depleted",
				requiresPurchase: true,
			}),
		);
		items.forEach((item) => repository.items.set(item.id.value, item));

		// Act
		const result = await lister.listAll(100, null);

		// Assert
		expect(result.items).toHaveLength(100);
		expect(result.hasMore).toBe(true);
	});

	it("pass null cursor to repository when cursor is null", async () => {
		// Arrange
		const repository = new MockInventoryItemRepository();
		const searchByRequiresPurchaseSpy = jest.spyOn(
			repository,
			"searchByRequiresPurchase",
		);
		const lister = new ShoppingItemLister(repository);

		// Act
		await lister.listAll(20, null);

		// Assert
		expect(searchByRequiresPurchaseSpy).toHaveBeenCalledWith(20, null);

		searchByRequiresPurchaseSpy.mockRestore();
	});

	it("pass empty string cursor to repository", async () => {
		// Arrange
		const repository = new MockInventoryItemRepository();
		const lister = new ShoppingItemLister(repository);

		const items = Array.from({ length: 5 }, () =>
			InventoryItemMother.create({
				state: "Low",
				requiresPurchase: true,
			}),
		);
		items.forEach((item) => repository.items.set(item.id.value, item));

		// Act - Empty string should be handled by repository
		const result = await lister.listAll(20, "");

		// Assert
		expect(result.items).toBeDefined();
	});

	it("return empty result for empty shopping list", async () => {
		// Arrange
		const repository = new MockInventoryItemRepository();
		const lister = new ShoppingItemLister(repository);

		// No items added - shopping list is empty

		// Act
		const result = await lister.listAll(20, null);

		// Assert
		expect(result.items).toEqual([]);
		expect(result.nextCursor).toBeNull();
		expect(result.hasMore).toBe(false);
	});

	it("return single item when only one item requires purchase", async () => {
		// Arrange
		const repository = new MockInventoryItemRepository();
		const lister = new ShoppingItemLister(repository);

		const item = InventoryItemMother.create({
			state: "Depleted",
			requiresPurchase: true,
		});
		repository.items.set(item.id.value, item);

		// Act
		const result = await lister.listAll(20, null);

		// Assert
		expect(result.items).toHaveLength(1);
		expect(result.hasMore).toBe(false);
		expect(result.nextCursor).toBeNull();
	});

	it("filter only items where requiresPurchase = true", async () => {
		// Arrange
		const repository = new MockInventoryItemRepository();
		const lister = new ShoppingItemLister(repository);

		// Add items with mixed states
		const lowItems = Array.from({ length: 5 }, () =>
			InventoryItemMother.create({
				state: "Low",
				requiresPurchase: true,
			}),
		);
		const depletedItems = Array.from({ length: 3 }, () =>
			InventoryItemMother.create({
				state: "Depleted",
				requiresPurchase: true,
			}),
		);
		const availableItems = Array.from({ length: 10 }, () =>
			InventoryItemMother.create({
				state: "Available",
				requiresPurchase: false,
			}),
		);

		[...lowItems, ...depletedItems, ...availableItems].forEach((item) =>
			repository.items.set(item.id.value, item),
		);

		// Act
		const result = await lister.listAll(20, null);

		// Assert - Only Low and Depleted items should be returned
		expect(result.items).toHaveLength(8);
		result.items.forEach((itemPrimitives) => {
			expect(itemPrimitives.requiresPurchase).toBe(true);
		});
	});
});
