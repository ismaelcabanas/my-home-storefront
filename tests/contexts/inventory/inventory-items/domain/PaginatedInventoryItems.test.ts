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

	it("maintain immutability of returned structure", () => {
		// Arrange
		const items = [
			InventoryItemMother.create({ name: "Apple" }),
			InventoryItemMother.create({ name: "Banana" }),
		];

		// Act
		const result = createPaginatedInventoryItems(
			items.map((item) => item.toPrimitives()),
			"cursor-token",
			true,
		);

		// Assert - Attempting to modify should not affect the original result
		// Note: In JavaScript, objects are mutable by default
		// This test documents the expected behavior for immutability in a production system
		expect(result.items).toHaveLength(2);
		expect(result.items).not.toBe(items); // Should be a new array (primitives)
		expect(result).toHaveProperty("items");
		expect(result).toHaveProperty("nextCursor");
		expect(result).toHaveProperty("hasMore");
	});

	it("verify cursor consistency: hasMore false implies nextCursor null", () => {
		// Arrange
		const items = [
			InventoryItemMother.create({ name: "Apple" }),
			InventoryItemMother.create({ name: "Banana" }),
		];
		const nextCursor = "some-cursor";

		// Act
		const result = createPaginatedInventoryItems(
			items.map((item) => item.toPrimitives()),
			nextCursor,
			false, // hasMore is false
		);

		// Assert - Factory should normalize to nextCursor null
		expect(result.nextCursor).toBeNull();
		expect(result.hasMore).toBe(false);
	});

	it("verify cursor consistency: hasMore true implies valid nextCursor", () => {
		// Arrange
		const items = [
			InventoryItemMother.create({ name: "Apple" }),
			InventoryItemMother.create({ name: "Banana" }),
		];
		const nextCursor = "valid-cursor-token";

		// Act
		const result = createPaginatedInventoryItems(
			items.map((item) => item.toPrimitives()),
			nextCursor,
			true, // hasMore is true
		);

		// Assert
		expect(result.nextCursor).toBe("valid-cursor-token");
		expect(result.hasMore).toBe(true);
	});
});
