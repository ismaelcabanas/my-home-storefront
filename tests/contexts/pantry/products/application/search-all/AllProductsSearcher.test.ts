import { AllProductsSearcher } from "../../../../../../src/contexts/pantry/products/application/search-all/AllProductsSearcher";
import { ProductMother } from "../../domain/ProductMother";
import { MockProductRepository } from "../../infrastructure/MockProductRepository";

describe("AllProductsSearcher should", () => {
	const repository = new MockProductRepository();
	const searcher = new AllProductsSearcher(repository);

	beforeEach(() => {
		jest.clearAllMocks();
	});

	it("return empty list when no products exist", async () => {
		repository.shouldSearchAllReturn([]);

		const products = await searcher.searchAll();

		expect(products).toEqual([]);
	});

	it("return all products", async () => {
		const product1 = ProductMother.create({ name: "Pasta" });
		const product2 = ProductMother.create({ name: "Rice" });
		const product3 = ProductMother.create({ name: "Milk" });

		repository.shouldSearchAllReturn([product1, product2, product3]);

		const products = await searcher.searchAll();

		expect(products).toHaveLength(3);
		expect(products[0]).toEqual(product1.toPrimitives());
		expect(products[1]).toEqual(product2.toPrimitives());
		expect(products[2]).toEqual(product3.toPrimitives());
	});
});
