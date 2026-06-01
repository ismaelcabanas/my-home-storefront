import { InventoryItemMother } from "./InventoryItemMother";
import {
	createPaginatedInventoryItems,
	emptyPaginatedInventoryItems,
} from "../../../../../src/contexts/inventory/inventory-items/domain/PaginatedInventoryItems";

describe("PaginatedInventoryItems should", () => {
	it("create empty result via factory method", () => {
		// Act
		const result = emptyPaginatedInventoryItems();

		// Assert
		expect(result.items).toEqual([]);
		expect(result.nextCursor).toBeNull();
		expect(result.hasMore).toBe(false);
	});

	it("create result with next page via factory method", () => {
		// Arrange
		const items = [
			InventoryItemMother.create({ name: "Apple" }),
			InventoryItemMother.create({ name: "Banana" }),
			InventoryItemMother.create({ name: "Cherry" }),
		];
		const nextCursor = "encoded-token";

		// Act
		const result = createPaginatedInventoryItems(
			items.map((item) => item.toPrimitives()),
			nextCursor,
			true,
		);

		// Assert
		expect(result.items).toHaveLength(3);
		expect(result.nextCursor).toBe("encoded-token");
		expect(result.hasMore).toBe(true);
	});

	it("create result for last page via factory method", () => {
		// Arrange
		const items = [
			InventoryItemMother.create({ name: "Apple" }),
			InventoryItemMother.create({ name: "Banana" }),
		];

		// Act
		const result = createPaginatedInventoryItems(
			items.map((item) => item.toPrimitives()),
			null,
			false,
		);

		// Assert
		expect(result.items).toHaveLength(2);
		expect(result.nextCursor).toBeNull();
		expect(result.hasMore).toBe(false);
	});

	it("normalize inconsistent state to nextCursor null when hasMore is false", () => {
		// Arrange
		const items = [
			InventoryItemMother.create({ name: "Apple" }),
			InventoryItemMother.create({ name: "Banana" }),
		];
		const invalidNextCursor = "should-be-ignored";

		// Act
		const result = createPaginatedInventoryItems(
			items.map((item) => item.toPrimitives()),
			invalidNextCursor,
			false,
		);

		// Assert
		expect(result.items).toHaveLength(2);
		expect(result.nextCursor).toBeNull();
		expect(result.hasMore).toBe(false);
	});
});
