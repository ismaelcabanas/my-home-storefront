import { ProductCreator } from "../../../../../../src/contexts/pantry/products/application/create/ProductCreator";
import { MockUuidGenerator } from "../../../../shared/domain/MockUuidGenerator";
import { ProductMother } from "../../domain/ProductMother";
import { MockProductRepository } from "../../infrastructure/MockProductRepository";

describe("ProductCreator should", () => {
	const repository = new MockProductRepository();
	const uuidGenerator = new MockUuidGenerator();
	const creator = new ProductCreator(repository, uuidGenerator);

	beforeEach(() => {
		jest.clearAllMocks();
	});

	it("create a new product successfully", async () => {
		const expectedProduct = ProductMother.create({
			name: "Pasta",
			currentStock: 5,
		});

		repository.shouldSearchByNameReturn(null);
		uuidGenerator.shouldGenerate(expectedProduct.id.value);
		repository.shouldSave(expectedProduct);

		await creator.create("Pasta", 5);
	});

	it("throw error when product already exists (case-insensitive)", async () => {
		const existingProduct = ProductMother.create({
			name: "Pasta",
		});

		repository.shouldSearchByNameReturn(existingProduct);

		await expect(creator.create("pasta", 3)).rejects.toThrow(
			"PRODUCT_ALREADY_EXISTS",
		);
	});

	it("throw error when stock is negative", async () => {
		repository.shouldSearchByNameReturn(null);
		uuidGenerator.shouldGenerate("any-uuid");

		await expect(creator.create("Rice", -1)).rejects.toThrow(
			"INVALID_STOCK_LEVEL",
		);
	});

	it("throw error when stock is not an integer", async () => {
		repository.shouldSearchByNameReturn(null);
		uuidGenerator.shouldGenerate("any-uuid");

		await expect(creator.create("Rice", 1.5)).rejects.toThrow(
			"INVALID_STOCK_LEVEL",
		);
	});
});
