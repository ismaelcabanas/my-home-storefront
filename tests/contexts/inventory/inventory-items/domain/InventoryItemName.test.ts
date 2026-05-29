import { InvalidInventoryItemNameError } from "../../../../../src/contexts/inventory/inventory-items/domain/InvalidInventoryItemNameError";
import { InventoryItemName } from "../../../../../src/contexts/inventory/inventory-items/domain/InventoryItemName";

describe("InventoryItemName should", () => {
	it("create valid name", () => {
		// Act
		const name = InventoryItemName.create("Milk");

		// Assert
		expect(name.value).toBe("Milk");
	});

	it("trim whitespace from name", () => {
		// Act
		const name = InventoryItemName.create("  Milk  ");

		// Assert
		expect(name.value).toBe("Milk");
	});

	it("throw InvalidInventoryItemNameError for empty name", () => {
		// Act & Assert
		expect(() => InventoryItemName.create("")).toThrow(
			InvalidInventoryItemNameError,
		);
	});

	it("throw InvalidInventoryItemNameError for whitespace-only name", () => {
		// Act & Assert
		expect(() => InventoryItemName.create("   ")).toThrow(
			InvalidInventoryItemNameError,
		);
	});

	it("throw InvalidInventoryItemNameError for name exceeding 255 characters", () => {
		// Act & Assert
		expect(() => InventoryItemName.create("a".repeat(256))).toThrow(
			InvalidInventoryItemNameError,
		);
	});
});
