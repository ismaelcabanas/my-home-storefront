import { Service } from "diod";

import { ProductPrimitives } from "../../domain/Product";
import { ProductRepository } from "../../domain/ProductRepository";

@Service()
export class AllProductsSearcher {
	constructor(private readonly repository: ProductRepository) {}

	async searchAll(): Promise<ProductPrimitives[]> {
		const products = await this.repository.searchAll();

		return products.map((p) => p.toPrimitives());
	}
}
