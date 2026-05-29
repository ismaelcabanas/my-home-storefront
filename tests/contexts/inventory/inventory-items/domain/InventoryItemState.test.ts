import { InventoryItemState } from "../../../../../src/contexts/inventory/inventory-items/domain/InventoryItemState";

describe("InventoryItemState should", () => {
	it("create Available state", () => {
		// Act
		const state = InventoryItemState.Available();

		// Assert
		expect(state.value).toBe("Available");
		expect(state.isAvailable()).toBe(true);
		expect(state.derivesRequiresPurchase()).toBe(false);
	});

	it("create Low state", () => {
		// Act
		const state = InventoryItemState.Low();

		// Assert
		expect(state.value).toBe("Low");
		expect(state.isAvailable()).toBe(false);
		expect(state.derivesRequiresPurchase()).toBe(true);
	});

	it("create Depleted state", () => {
		// Act
		const state = InventoryItemState.Depleted();

		// Assert
		expect(state.value).toBe("Depleted");
		expect(state.isAvailable()).toBe(false);
		expect(state.derivesRequiresPurchase()).toBe(true);
	});

	it("create state from valid value", () => {
		// Act
		const state = InventoryItemState.fromValue("Low");

		// Assert
		expect(state.value).toBe("Low");
	});

	it("throw error for invalid state value", () => {
		// Act & Assert
		expect(() => InventoryItemState.fromValue("Invalid")).toThrow(
			"Invalid inventory item state: Invalid",
		);
	});
});
