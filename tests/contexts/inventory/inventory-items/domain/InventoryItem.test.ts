import { faker } from "@faker-js/faker";

import { InventoryItem } from "../../../../../src/contexts/inventory/inventory-items/domain/InventoryItem";

import { InventoryItemMother } from "./InventoryItemMother";

describe("InventoryItem should", () => {
	it("create new item with Available state", () => {
		// Arrange
		const uuid = faker.string.uuid();
		const createdAt = new Date();

		// Act
		const item = InventoryItem.create(uuid, "Milk", createdAt);

		// Assert
		expect(item.state.value).toBe("Available");
		expect(item.requiresPurchase).toBe(false);
	});

	it("derive requiresPurchase as false when Available", () => {
		// Arrange
		const item = InventoryItemMother.create({ state: "Available" });

		// Assert
		expect(item.requiresPurchase).toBe(false);
	});

	it("derive requiresPurchase as true when Low", () => {
		// Arrange
		const item = InventoryItemMother.create({
			state: "Low",
			requiresPurchase: true,
		});

		// Assert
		expect(item.requiresPurchase).toBe(true);
	});

	it("derive requiresPurchase as true when Depleted", () => {
		// Arrange
		const item = InventoryItemMother.create({
			state: "Depleted",
			requiresPurchase: true,
		});

		// Assert
		expect(item.requiresPurchase).toBe(true);
	});

	it("convert to primitives", () => {
		// Arrange
		const item = InventoryItemMother.create();

		// Act
		const primitives = item.toPrimitives();

		// Assert
		expect(primitives.id).toBe(item.id.value);
		expect(primitives.name).toBe(item.name.value);
		expect(primitives.state).toBe(item.state.value);
		expect(primitives.requiresPurchase).toBe(item.requiresPurchase);
		expect(primitives.createdAt).toBe(item.createdAt.toISOString());
	});

	it("reconstruct from primitives", () => {
		// Arrange
		const primitives = {
			id: faker.string.uuid(),
			name: "Milk",
			state: "Available",
			requiresPurchase: false,
			createdAt: new Date().toISOString(),
		};

		// Act
		const item = InventoryItem.fromPrimitives(primitives);

		// Assert
		expect(item.id.value).toBe(primitives.id);
		expect(item.name.value).toBe(primitives.name);
		expect(item.state.value).toBe(primitives.state);
		expect(item.requiresPurchase).toBe(primitives.requiresPurchase);
		expect(item.createdAt.toISOString()).toBe(primitives.createdAt);
	});
});
