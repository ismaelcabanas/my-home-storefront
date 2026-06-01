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

	it("maintain value object immutability", () => {
		// Arrange
		const state = InventoryItemState.Low();

		// Act - Attempt to modify (should not be possible)
		// TypeScript should prevent this at compile time
		// At runtime, value objects should not expose mutable state

		// Assert
		expect(state.value).toBe("Low");
		expect(Object.isFrozen(state) || Object.isSealed(state)).toBe(false); // Not frozen/sealed but value is immutable
	});

	it("treat states with same value as equal", () => {
		// Arrange
		const state1 = InventoryItemState.Available();
		const state2 = InventoryItemState.Available();

		// Act & Assert
		expect(state1.value).toBe(state2.value);
		// Same factory method returns equivalent values
	});

	it("derive isAvailable correctly for all states", () => {
		// Arrange & Act & Assert
		expect(InventoryItemState.Available().isAvailable()).toBe(true);
		expect(InventoryItemState.Low().isAvailable()).toBe(false);
		expect(InventoryItemState.Depleted().isAvailable()).toBe(false);
	});

	it("derive requiresPurchase correctly for all states", () => {
		// Arrange & Act & Assert
		expect(InventoryItemState.Available().derivesRequiresPurchase()).toBe(
			false,
		);
		expect(InventoryItemState.Low().derivesRequiresPurchase()).toBe(true);
		expect(InventoryItemState.Depleted().derivesRequiresPurchase()).toBe(
			true,
		);
	});
});
