import { ProductStockUpdater } from "../../../../../../src/contexts/pantry/products/application/update-stock/ProductStockUpdater";
import { ProductMother } from "../../domain/ProductMother";
import { MockProductRepository } from "../../infrastructure/MockProductRepository";

describe("ProductStockUpdater should", () => {
	const repository = new MockProductRepository();
	const updater = new ProductStockUpdater(repository);

	beforeEach(() => {
		jest.clearAllMocks();
	});

	it("update stock successfully", async () => {
		const existingProduct = ProductMother.create({
			name: "Milk",
			currentStock: 1,
		});
		const updatedProduct = ProductMother.create({
			id: existingProduct.id.value,
			name: "Milk",
			currentStock: 5,
		});

		repository.shouldSearchByIdReturn(existingProduct);
		repository.shouldSearchByIdReturn(updatedProduct);
		repository.shouldSave(updatedProduct);

		await updater.update(existingProduct.id.value, 5);
	});

	it("throw error when product not found", async () => {
		repository.shouldSearchByIdReturn(null);

		await expect(updater.update("non-existent-id", 5)).rejects.toThrow(
			"PRODUCT_NOT_FOUND",
		);
	});

	it("throw error when stock is negative", async () => {
		const existingProduct = ProductMother.create({
			name: "Tomato Can",
			currentStock: 3,
		});

		repository.shouldSearchByIdReturn(existingProduct);

		await expect(
			updater.update(existingProduct.id.value, -1),
		).rejects.toThrow("INVALID_STOCK_LEVEL");
	});

	it("throw error when stock is not an integer", async () => {
		const existingProduct = ProductMother.create({
			name: "Sugar",
			currentStock: 2,
		});

		repository.shouldSearchByIdReturn(existingProduct);

		await expect(
			updater.update(existingProduct.id.value, 1.5),
		).rejects.toThrow("INVALID_STOCK_LEVEL");
	});
});
