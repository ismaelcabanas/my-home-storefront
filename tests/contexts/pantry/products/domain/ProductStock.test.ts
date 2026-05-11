import { InvalidStockLevelError } from "../../../../../src/contexts/pantry/products/domain/InvalidStockLevelError";
import { ProductStock } from "../../../../../src/contexts/pantry/products/domain/ProductStock";

describe("ProductStock should", () => {
	it("create valid stock", () => {
		const stock = new ProductStock(5);

		expect(stock.value).toBe(5);
	});

	it("create stock with zero", () => {
		const stock = new ProductStock(0);

		expect(stock.value).toBe(0);
	});

	it("throw error when stock is negative", () => {
		expect(() => new ProductStock(-1)).toThrow(InvalidStockLevelError);
	});

	it("throw error when stock is not an integer", () => {
		expect(() => new ProductStock(1.5)).toThrow(InvalidStockLevelError);
		expect(() => new ProductStock(NaN)).toThrow(InvalidStockLevelError);
	});
});
