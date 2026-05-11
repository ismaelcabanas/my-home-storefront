import { ProductName } from "../../../../../src/contexts/pantry/products/domain/ProductName";

describe("ProductName should", () => {
	it("create valid name", () => {
		const name = new ProductName("Pasta");

		expect(name.value).toBe("Pasta");
	});

	it("throw error when name is empty", () => {
		expect(() => new ProductName("")).toThrow(
			"Product name cannot be empty",
		);
		expect(() => new ProductName("   ")).toThrow(
			"Product name cannot be empty",
		);
	});

	it("throw error when name is too long", () => {
		const longName = "a".repeat(256);
		expect(() => new ProductName(longName)).toThrow(
			"Product name too long",
		);
	});

	it("compare names case-insensitively", () => {
		const name1 = new ProductName("Pasta");
		const name2 = new ProductName("pasta");
		const name3 = new ProductName("PASTA");
		const name4 = new ProductName("Rice");

		expect(name1.equals(name2)).toBe(true);
		expect(name1.equals(name3)).toBe(true);
		expect(name1.equals(name4)).toBe(false);
	});
});
